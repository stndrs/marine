pub type Config {
  Config(
    host: String,
    port: Int,
    database: String,
    username: String,
    password: String,
    connect_timeout: Int,
    ssl_opts: List(#(String, String)),
  )
}

pub type SSLRequest {
  SSLRequest(capability_flags: Int, charset: Int, max_packet_size: Int)
}

pub fn new() -> Config {
  Config("localhost", 3306, "", "", "", 5000, [])
}

pub fn set_host(config: Config, host: String) -> Config {
  Config(..config, host: host)
}

pub fn set_port(config: Config, port: Int) -> Config {
  Config(..config, port: port)
}

pub fn set_database(config: Config, database: String) -> Config {
  Config(..config, database: database)
}

pub fn set_username(config: Config, username: String) -> Config {
  Config(..config, username: username)
}

pub fn set_password(config: Config, password: String) -> Config {
  Config(..config, password: password)
}

pub fn set_timeout(config: Config, connect_timeout: Int) -> Config {
  Config(..config, connect_timeout: connect_timeout)
}

pub fn set_ssl_opts(config: Config, opts: List(#(String, String))) -> Config {
  Config(..config, ssl_opts: opts)
}
