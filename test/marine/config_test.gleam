import gleeunit
import gleeunit/should
import marine/config

pub fn main() {
  gleeunit.main()
}

pub fn new_default_conf_test() {
  let default = config.new()

  default.host |> should.equal("localhost")
  default.port |> should.equal(3306)
  default.database |> should.equal("")
  default.username |> should.equal("")
  default.password |> should.equal("")
  default.connect_timeout |> should.equal(5000)
  default.ssl_opts |> should.equal([])
}

pub fn set_field_test() {
  let host = "127.0.0.1"
  let port = 33_066
  let database = "marine_dev"
  let username = "maria"
  let password = "supersecurepassword"
  let timeout = 4000
  let ssl_opts = [#("opt", "val")]

  let conf =
    config.new()
    |> config.set_host(host)
    |> config.set_port(port)
    |> config.set_database(database)
    |> config.set_username(username)
    |> config.set_password(password)
    |> config.set_timeout(timeout)
    |> config.set_ssl_opts(ssl_opts)

  conf.host |> should.equal(host)
  conf.port |> should.equal(port)
  conf.database |> should.equal(database)
  conf.username |> should.equal(username)
  conf.password |> should.equal(password)
  conf.connect_timeout |> should.equal(timeout)
  conf.ssl_opts |> should.equal(ssl_opts)
}
