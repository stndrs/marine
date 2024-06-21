import gleeunit
import gleeunit/should
import marine/client
import marine/config.{type Config, Config}

pub fn main() {
  gleeunit.main()
}

pub fn connect_test() {
  Config(
    host: "localhost",
    port: 3306,
    database: "",
    connect_timeout: 5000,
    ssl_opts: [],
  )
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
