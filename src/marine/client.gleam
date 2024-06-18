import gleam/result
import marine/protocol.{type Handshake}
import mug.{type Socket}

pub type Config {
  Config(
    host: String,
    port: Int,
    connect_timeout: Int,
    protocol_config: protocol.Config,
  )
}

pub type ClientError {
  ClientError(message: String)
}

// pub fn new() {
//   todo
// }

pub fn connect(config: Config) -> Result(Socket, ClientError) {
  let Config(host, port, connect_timeout, _) = config

  mug.new(host, port: port)
  |> mug.timeout(connect_timeout)
  |> mug.connect
  |> result.replace_error(ClientError("Failed to connect"))
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

fn handshake(socket: Socket, config: Config) -> Result(Socket, ClientError) {
  socket
  |> mug.receive(config.connect_timeout)
  |> result.replace_error(ClientError("Failed to receive"))
  |> result.then(do_handshake(socket, config, _))
}

fn do_handshake(
  socket: Socket,
  config: Config,
  packet: BitArray,
) -> Result(Socket, ClientError) {
  packet
  |> protocol.initial_handshake
  |> result.map_error(fn(err) { ClientError(err.name) })
  |> result.then(do_handshake_response(socket, config, _))
  |> result.map(fn(_) { socket })
}

fn do_handshake_response(
  socket: Socket,
  config: Config,
  handshake: Handshake,
) -> Result(Socket, ClientError) {
  let _int =
    protocol.compile_capability_flags(config.protocol_config, handshake)
  // protocol.maybe_upgrade_to_ssl
  // handle_handshake_response
  // handle ok_packet
  // handle error_packet
  Ok(socket)
}
