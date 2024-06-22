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
