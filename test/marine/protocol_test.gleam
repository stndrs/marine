import gleeunit
import gleeunit/should
import marine/protocol

pub fn main() {
  gleeunit.main()
}

pub fn connect_test() {
  let conf =
    protocol.Config(
      host: "localhost",
      port: 3306,
      connect_timeout: 5000,
      receive_timeout: 5000,
    )

  protocol.connect(conf)
  |> should.be_ok
}
