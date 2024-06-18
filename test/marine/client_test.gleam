import gleam/option.{None}
import gleeunit
import gleeunit/should
import marine/client
import marine/protocol

pub fn main() {
  gleeunit.main()
}

pub fn connect_test() {
  let proto_conf = protocol.Config(database: "", ssl_opts: None)
  let conf =
    client.Config(
      host: "localhost",
      port: 3306,
      connect_timeout: 5000,
      protocol_config: proto_conf,
    )

  client.connect(conf)
  |> should.be_ok
}
