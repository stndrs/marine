import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/result
import gleam/string
import marine/errors.{type MarineError}
import marine/flags
import marine/server_errors

pub type Handshake {
  Handshake(
    server_info: ServerInfo,
    conn_id: Int,
    capability_flags: Int,
    charset: Int,
    status_flags: Int,
    auth_plugin_data: String,
    auth_plugin_name: String,
  )
}

pub type ServerInfo {
  ServerInfo(vendor: Vendor, version: List(Int))
}

pub type Vendor {
  MySQL
  MariaDB
}

pub type SslOpts {
  SslOpts
}

pub type Config {
  Config(database: String, ssl_opts: Option(SslOpts))
}

pub type Payload {
  Payload(length: Int, sequence_id: Int, body: BitArray)
}

// Connection Phase
// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase.html

/// Parse the packet from the initial handshake received from the database server
pub fn initial_handshake(packet: BitArray) -> Result(Handshake, MarineError) {
  packet
  |> to_payload
  |> result.then(decode_initial_handshake)
}

/// Compiles the client's capability flags
pub fn compile_capability_flags(
  config: Config,
  initial_handshake: Handshake,
) -> Result(Int, MarineError) {
  let server_capability_flags = initial_handshake.capability_flags

  let client_capability_flags =
    server_capability_flags
    |> flags.put_capability_flag(flags.client_capability_names)
    |> maybe_add_capability_flags("client_connect_with_db", fn() {
      string.is_empty(config.database)
    })
    |> maybe_add_capability_flags("client_ssl", fn() {
      option.is_some(config.ssl_opts)
    })

  let ssl_support_error = case config.ssl_opts {
    Some(_opts) ->
      flags.has_capability_flag(server_capability_flags, "client_ssl")
    None -> False
  }

  case ssl_support_error {
    True ->
      errors.ProtocolError(
        code: -1,
        name: "server_ssl_unsupported",
        message: <<>>,
      )
      |> Error
    False ->
      filter_capabilities(server_capability_flags, client_capability_flags)
      |> Ok
  }
}

fn filter_capabilities(allowed_flags: Int, requested_flags: Int) -> Int {
  // get the flags requested

  flags.list_capability_flags(requested_flags)
  |> list.fold(requested_flags, fn(acc, name) {
    case flags.has_capability_flag(allowed_flags, name) {
      True -> acc
      False -> flags.remove_capability_flag(acc, name)
    }
  })
}

fn maybe_add_capability_flags(
  flags: Int,
  name: String,
  predicate: fn() -> Bool,
) -> Int {
  case predicate() {
    True -> flags.put_capability_flag(flags, [name])
    False -> flags
  }
}

// pub fn encode_handshake_response_41() -> Result(Nil, MarineError) {
//   todo
// }
// 
// pub fn encode_ssl_request() -> Result(Nil, MarineError) {
//   todo
// }
// 
// pub fn decode_auth_response() -> Result(Nil, MarineError) {
//   todo
// }

// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html
//
// Construct a Payload from the packet received. The first 3 bytes (24 bits) indicate
// the length of the payload. One byte (8 bits) following the first 3 bytes carries
// the sequence ID. The remaining bits contain the packet payload/body
fn to_payload(packet: BitArray) -> Result(Payload, MarineError) {
  case packet {
    <<length:little-size(24), seq_id:little-size(8), rest:bits>> -> {
      Payload(length: length, sequence_id: seq_id, body: rest) |> Ok
    }
    _ -> Error(errors.GenericError)
  }
}

// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake_v10.html
fn decode_initial_handshake(payload: Payload) -> Result(Handshake, MarineError) {
  case payload.body {
    <<10, rest:bits>> -> decode_handshake_v10(rest)
    <<0xFF, rest:bits>> -> decode_connect_err_packet_body(rest)
    _ -> Error(errors.GenericError)
  }
}

fn decode_connect_err_packet_body(
  body: BitArray,
) -> Result(Handshake, MarineError) {
  case body {
    <<code:unsigned-little-size(16), message:bits>> -> {
      let name = server_errors.to_name(code)
      errors.ProtocolError(code, name, message) |> Error
    }
    _ -> Error(errors.GenericError)
  }
}

fn decode_handshake_v10(body: BitArray) -> Result(Handshake, MarineError) {
  use #(server_version, rest) <- result.try(null_terminated_string(body))

  case rest {
    <<
      conn_id:unsigned-little-size(32),
      auth_plugin_data1:bits-size(64),
      _filler:unsigned-little-int,
      capability_flags1:bits-size(16),
      character_set:unsigned-little-size(8),
      status_flags:unsigned-little-size(16),
      capability_flags2:bits-size(16),
      rest:bits,
    >> -> {
      let required_capabilities = [
        "client_protocol_41", "client_plugin_auth", "client_secure_connection",
      ]

      Handshake(
        server_info: to_server_info(server_version),
        conn_id: conn_id,
        capability_flags: 0,
        charset: character_set,
        status_flags: status_flags,
        auth_plugin_data: "",
        auth_plugin_name: "",
      )
      |> build_capability_flags(capability_flags1, capability_flags2)
      |> result.then(ensure_capabilities(_, required_capabilities))
      |> result.then(apply_auth_plugin_info(_, auth_plugin_data1, rest))
    }
    _ -> Error(errors.GenericError)
  }
}

fn build_capability_flags(
  handshake: Handshake,
  flags1: BitArray,
  flags2: BitArray,
) -> Result(Handshake, MarineError) {
  let capability_flags = bit_array.concat([flags1, flags2])

  case capability_flags {
    <<capability_flags:unsigned-little-size(32)>> -> {
      Handshake(..handshake, capability_flags: capability_flags) |> Ok
    }
    _ -> Error(errors.GenericError)
  }
}

// Returns the handshake with a valid capabilities flag integer value if the check passes
fn ensure_capabilities(
  handshake: Handshake,
  required_capabilities: List(String),
) -> Result(Handshake, MarineError) {
  let has_capabilities =
    required_capabilities
    |> list.all(flags.has_capability_flag(handshake.capability_flags, _))

  case has_capabilities {
    True -> Ok(handshake)
    False -> Error(errors.GenericError)
  }
}

fn apply_auth_plugin_info(
  handshake: Handshake,
  auth_plugin_data1: BitArray,
  data: BitArray,
) -> Result(Handshake, MarineError) {
  case data {
    <<
      auth_plugin_data_length:unsigned-little-int,
      _filler:unsigned-little-size(80),
      rest:bits,
    >> -> {
      let len = int.max(13, auth_plugin_data_length - 8) * 8

      parse_auth_plugin_info(rest, auth_plugin_data1, len)
      |> result.map(fn(auth_plugin_info) {
        let #(data, name) = auth_plugin_info

        Handshake(..handshake, auth_plugin_data: data, auth_plugin_name: name)
      })
    }
    _ -> Error(errors.GenericError)
  }
}

fn parse_auth_plugin_info(
  data: BitArray,
  auth_plugin_data1: BitArray,
  len: Int,
) -> Result(#(String, String), MarineError) {
  case data {
    <<auth_plugin_data2:bits-size(len), auth_plugin_name:bits>> -> {
      let auth_plugin_data = <<auth_plugin_data1:bits, auth_plugin_data2:bits>>
      let info = {
        use plugin_data <- result.try(bit_array.to_string(auth_plugin_data))
        use plugin_name <- result.try(bit_array.to_string(auth_plugin_name))

        Ok(#(plugin_data, plugin_name))
      }
      result.replace_error(info, errors.GenericError)
    }
    _ -> Error(errors.GenericError)
  }
}

fn null_terminated_string(
  data: BitArray,
) -> Result(#(BitArray, BitArray), MarineError) {
  case erl_binary_split(data, <<0>>) {
    [string, rest] -> Ok(#(string, rest))
    _ -> Error(errors.GenericError)
  }
}

@external(erlang, "binary", "split")
fn erl_binary_split(input: BitArray, pattern: BitArray) -> List(BitArray)

// Ported from https://github.com/mysql-otp/mysql-otp/blob/b97ef3dc1313b2e94ed489f41d735b8e4f769459/src/mysql_protocol.erl#L379
fn to_server_info(server_version: BitArray) -> ServerInfo {
  case server_version {
    <<"5.5.5-":utf8, rest:bits>> -> {
      ServerInfo(vendor: MariaDB, version: server_version_to_list(rest))
    }
    _ -> {
      let version = server_version_to_list(server_version)
      let vendor = case version {
        [5, 1, ..] -> MySQL
        [5, 2, ..] -> MariaDB
        [5, 3, ..] -> MariaDB
        [5, 4, ..] -> MySQL
        _ -> MySQL
      }
      ServerInfo(vendor, version)
    }
  }
}

fn server_version_to_list(version: BitArray) -> List(Int) {
  let version_list = {
    use version <- result.try(bit_array.to_string(version))

    regex.from_string("^(\\d+)\\.(\\d+)\\.(\\d+)")
    |> result.nil_error
    |> result.map(fn(regex) {
      regex.scan(with: regex, content: version)
      |> list.flat_map(fn(match) { match.submatches })
      |> list.filter_map(fn(submatch) {
        case submatch {
          Some(submatch) -> int.parse(submatch)
          None -> Error(Nil)
        }
      })
    })
  }

  case version_list {
    Ok(version_list) -> version_list
    _ -> []
  }
}

// Text and Binary Protocol
//
// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_command_phase_text.html
// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_command_phase_ps.html

pub type Cursor {
  Cursor
}

pub type Command {
  ComQuit
  ComPing
  ComQuery(query: BitArray)
  ComStmtPrepare(query: BitArray)
  ComStmtClose(statement_id: Int)
  ComStmtReset(statement_id: Int)
  ComStmtExecute(statement_id: Int, params: List(BitArray), cursor_type: Cursor)
  ComStmtFetch(statement_id: Int, num_rows: Int)
}

pub fn encode_command(_command: Command) -> BitArray {
  <<0x01>>
}
// pub fn decode_response(payload: BitArray) -> Result(Nil, MarineError) {
//   todo
// }
// 
// pub fn encode_params(params: List(BitArray)) -> BitArray {
//   <<>>
// }
// 
// pub fn decode_column_def(payload: BitArray) -> Result(Nil, MarineError) {
//   todo
// }
// 
// pub fn decode_more_results(payload: BitArray) -> Result(Nil, MarineError) {
//   todo
// }
