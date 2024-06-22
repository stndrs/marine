import gleam/io
import gleam/result
import marine/config.{type Config, type SSLRequest, Config, SSLRequest}
import marine/errors.{type MarineError}
import marine/protocol.{type Handshake, Handshake}
import mug.{type Socket}

// utf8mb4
const default_charset_code = 45

const default_max_packet_size = 16_777_215

pub type Client {
  Client(socket: Socket, sequence_id: Int)
}

// pub fn new() {
//   todo
// }

pub fn connect(config: Config) -> Result(Client, MarineError) {
  let Config(host, port, _database, _username, _password, connect_timeout, _) =
    config

  mug.new(host, port: port)
  |> mug.timeout(connect_timeout)
  |> mug.connect
  |> result.map(Client(_, 0))
  |> result.replace_error(errors.ClientError("Failed to connect"))
  |> result.then(handshake(_, config))
}

// pub fn com() {
//   todo
// }
// 
// pub fn disconnect() {
//   todo
// }

// Connect

fn handshake(client: Client, config: Config) -> Result(Client, MarineError) {
  let initial_handshake_result =
    recv_packet(client, config)
    |> result.replace_error(errors.ClientError("Failed to receive"))
    |> result.then(protocol.initial_handshake)

  use handshake <- result.try(initial_handshake_result)

  protocol.compile_capability_flags(handshake, config)
  |> result.then(maybe_upgrade_to_ssl(client, config, _))
  |> result.then(build_handshake_response(_, config, handshake))
}

fn build_handshake_response(
  client: Client,
  config: Config,
  handshake: Handshake,
) -> Result(Client, MarineError) {
  let auth_resp =
    protocol.build_handshake_response(handshake, config)
    |> result.then(send_packet(client, _, default_max_packet_size))
    |> result.then(recv_packet(_, config))
    |> result.then(protocol.handle_auth)
    |> result.then(protocol.handle_auth_response(config, _))

  use auth_resp <- result.try(auth_resp)

  client
  |> increment_sequence_id
  |> increment_sequence_id
  |> send_packet(auth_resp, default_max_packet_size)
  |> result.then(recv_packet(_, config))
  |> result.then(protocol.handle_auth)
  |> io.debug
  // protocol.auth_switch_request if needed
  // senc_packet
  // recv_packet
  // perform_full_auth if `full_auth`
  // perform_public_key_auth else
  // auth_switch_req
  // send_recv_packet
  // more_auth
  //
  // handle ok_packet
  // handle error_packet
  |> result.replace(client)
}

fn recv_packet(client: Client, config: Config) -> Result(BitArray, MarineError) {
  mug.receive(client.socket, config.connect_timeout)
  |> result.replace_error(errors.ClientError("Failed to receive"))
}

fn maybe_upgrade_to_ssl(
  client: Client,
  config: Config,
  capability_flags: Int,
) -> Result(Client, MarineError) {
  let client = increment_sequence_id(client)

  case config.ssl_opts {
    [] -> Ok(client)
    ssl_opts -> {
      let ssl_request =
        SSLRequest(
          capability_flags: capability_flags,
          charset: default_charset_code,
          max_packet_size: default_max_packet_size,
        )

      protocol.encode_ssl_request(ssl_request)
      |> send_packet(client, _, ssl_request.max_packet_size)
      |> result.then(ssl_connect(_, ssl_opts, config.connect_timeout))
      |> result.map(increment_sequence_id)
    }
  }
}

fn increment_sequence_id(client: Client) -> Client {
  Client(..client, sequence_id: client.sequence_id + 1)
}

fn send_packet(
  client: Client,
  payload: BitArray,
  max_packet_size: Int,
) -> Result(Client, MarineError) {
  protocol.encode_packet(payload, client.sequence_id, max_packet_size)
  |> mug.send(client.socket, _)
  |> result.map_error(fn(_err) { errors.ClientError("Send error") })
  |> result.replace(client)
}

fn ssl_connect(
  client: Client,
  ssl_opts: List(#(String, String)),
  timeout: Int,
) -> Result(Client, MarineError) {
  erlang_ssl_connect(client.socket, ssl_opts, timeout)
  |> result.map(fn(socket) { Client(..client, socket: socket) })
  |> result.replace_error(errors.ClientError("SSL connect failed"))
}

@external(erlang, "ssl", "connect")
fn erlang_ssl_connect(
  socket: Socket,
  ssl_opts: List(#(String, String)),
  timeout: Int,
) -> Result(Socket, Nil)
