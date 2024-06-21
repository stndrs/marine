import gleam/io
import gleam/option.{None, Some}
import gleam/result
import marine/config.{
  type Config, type SSLOpts, type SSLRequest, Config, SSLRequest,
}
import marine/errors.{type MarineError}
import marine/protocol.{type Handshake}
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
  let Config(host, port, _database, connect_timeout, _) = config

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
  client.socket
  |> mug.receive(config.connect_timeout)
  |> result.replace_error(errors.ClientError("Failed to receive"))
  |> result.then(do_handshake(client, config, _))
}

fn do_handshake(
  client: Client,
  config: Config,
  packet: BitArray,
) -> Result(Client, MarineError) {
  packet
  |> protocol.initial_handshake
  |> result.then(do_handshake_response(client, config, _))
}

fn do_handshake_response(
  client: Client,
  config: Config,
  handshake: Handshake,
) -> Result(Client, MarineError) {
  let _int =
    protocol.compile_capability_flags(config, handshake)
    |> result.then(maybe_upgrade_to_ssl(client, config, _))
    |> io.debug
  // handle_handshake_response
  // handle ok_packet
  // handle error_packet
  Ok(client)
}

fn maybe_upgrade_to_ssl(
  client: Client,
  config: Config,
  capability_flags: Int,
) -> Result(Client, MarineError) {
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
