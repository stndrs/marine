import gleam/option.{type Option}

pub type Config {
  Config(
    host: String,
    port: Int,
    database: String,
    connect_timeout: Int,
    ssl_opts: List(#(String, String)),
  )
}

pub type SSLOpts {
  SSLOpts(String)
}

pub type SSLRequest {
  SSLRequest(capability_flags: Int, charset: Int, max_packet_size: Int)
}
