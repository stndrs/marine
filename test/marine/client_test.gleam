import gleam/io
import gleeunit
import gleeunit/should
import marine/client
import marine/config

pub fn main() {
  gleeunit.main()
}

pub fn connect_test() {
  config.new()
  |> config.set_host("127.0.0.1")
  |> config.set_username("root")
  |> config.set_password("maria_root_pw")
  |> client.connect
  |> should.be_ok
}
// pub fn connect_ssl_test() {
//   Config(
//     host: "localhost",
//     port: 3306,
//     database: "",
//     connect_timeout: 5000,
//     ssl_opts: [],
//   )
//   |> client.connect
//   |> should.be_ok
// }
