import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/regex
import gleam/result
import marine/server_errors
import mug.{type Socket}

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

const all_capability_flags = [
  #("client_long_password", 0x00000001), #("client_found_rows", 0x00000002),
  #("client_long_flag", 0x00000004), #("client_connect_with_db", 0x00000008),
  #("client_no_schema", 0x00000010), #("client_compress", 0x00000020),
  #("client_odbc", 0x00000040), #("client_local_files", 0x00000080),
  #("client_ignore_space", 0x00000100), #("client_protocol_41", 0x00000200),
  #("client_interactive", 0x00000400), #("client_ssl", 0x00000800),
  #("client_ignore_sigpipe", 0x00001000), #("client_transactions", 0x00002000),
  #("client_reserved", 0x00004000), #("client_secure_connection", 0x00008000),
  #("client_multi_statements", 0x00010000),
  #("client_multi_results", 0x00020000),
  #("client_ps_multi_results", 0x00040000), #("client_plugin_auth", 0x00080000),
  #("client_connect_attrs", 0x00100000),
  #("client_plugin_auth_lenenc_client_data", 0x00200000),
  #("client_can_handle_expired_passwords", 0x00400000),
  #("client_session_track", 0x00800000), #("client_deprecate_eof", 0x01000000),
]

pub type ServerInfo {
  ServerInfo(vendor: Vendor, version: List(Int))
}

pub type Vendor {
  MySQL
  MariaDB
}

pub type Config {
  Config(host: String, port: Int, connect_timeout: Int, receive_timeout: Int)
}

pub type Payload {
  Payload(length: Int, sequence_id: Int, body: BitArray)
}

pub type MarineError {
  MarineError(code: Int, name: String, message: BitArray)
}

/// Establish a TCP connection to the database server as specified by the
/// `Config`. If a connection is established and the initial handshake packet
/// is parsed successfully, the Socket and Handshake are returned.
pub fn connect(config: Config) -> Result(#(Socket, Handshake), MarineError) {
  let Config(host, port, connect_timeout, receive_timeout) = config

  let connect =
    mug.new(host, port: port)
    |> mug.timeout(connect_timeout)
    |> mug.connect
    |> result.replace_error(generic_error())

  use socket <- result.try(connect)

  socket
  |> mug.receive(receive_timeout)
  |> result.replace_error(generic_error())
  |> result.then(handle_handshake(_))
  |> result.map(fn(handshake) { #(socket, handshake) })
}

fn handle_handshake(packet: BitArray) -> Result(Handshake, MarineError) {
  packet
  |> to_payload
  |> result.then(decode_initial_handshake)
}

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
    _ -> Error(generic_error())
  }
}

// https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake_v10.html
fn decode_initial_handshake(payload: Payload) -> Result(Handshake, MarineError) {
  case payload.body {
    <<10, rest:bits>> -> decode_handshake_v10(rest)
    <<0xFF, rest:bits>> -> decode_connect_err_packet_body(rest)
    _ -> Error(generic_error())
  }
}

fn decode_connect_err_packet_body(
  body: BitArray,
) -> Result(Handshake, MarineError) {
  case body {
    <<code:unsigned-little-size(16), message:bits>> -> {
      let name = server_errors.to_name(code)
      MarineError(code, name, message) |> Error
    }
    _ -> Error(generic_error())
  }
}

fn generic_error() -> MarineError {
  MarineError(-1, "generic_error", <<>>)
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
    _ -> Error(generic_error())
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
    _ -> Error(generic_error())
  }
}

// Returns the handshake with a valid capabilities flag integer value if the check passes
fn ensure_capabilities(
  handshake: Handshake,
  required_capabilities: List(String),
) -> Result(Handshake, MarineError) {
  required_capabilities
  |> list.try_each(has_capability_flag(handshake, _))
  |> result.map(fn(_) { handshake })
}

fn has_capability_flag(
  handshake: Handshake,
  name: String,
) -> Result(Handshake, MarineError) {
  all_capability_flags
  |> list.key_find(name)
  |> result.then(fn(value) {
    case int.bitwise_and(handshake.capability_flags, value) == value {
      True -> Ok(handshake)
      False -> Error(Nil)
    }
  })
  |> result.replace_error(generic_error())
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
    _ -> Error(generic_error())
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
      result.replace_error(info, generic_error())
    }
    _ -> Error(generic_error())
  }
}

fn null_terminated_string(
  data: BitArray,
) -> Result(#(BitArray, BitArray), MarineError) {
  case erl_binary_split(data, <<0>>) {
    [string, rest] -> Ok(#(string, rest))
    _ -> Error(generic_error())
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
