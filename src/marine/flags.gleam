import gleam/int
import gleam/list
import gleam/result

pub const all_capability_flags = [
  #("client_long_password", 0x00000001), #("client_found_rows", 0x00000002),
  #("client_long_flag", 0x00000004), #("client_connect_with_db", 0x00000008),
  #("client_no_schema", 0x00000010), #("client_compress", 0x00000020),
  #("client_odbc", 0x00000040), #("client_local_files", 0x00000080),
  #("client_ignore_space", 0x00000100), #("client_protocol_41", 0x00000200),
  #("client_interactive", 0x00000400), #("client_ssl", 0x00000800),
  #("client_ignore_sigpipe", 0x00001000), #("client_transactions", 0x00002000),
  #("client_reserved", 0x00004000), #("client_secure_connection", 0x00008000),
  #("client_multi_statements", 0x00010000),
  #("client_multi_results", 0x00020000),
  #("client_ps_multi_results", 0x00040000), #("client_plugin_auth", 0x00080000),
  #("client_connect_attrs", 0x00100000),
  #("client_plugin_auth_lenenc_client_data", 0x00200000),
  #("client_can_handle_expired_passwords", 0x00400000),
  #("client_session_track", 0x00800000), #("client_deprecate_eof", 0x01000000),
]

pub const client_capability_names = [
  "client_protocol_41", "client_plugin_auth", "client_secure_connection",
  "client_found_rows", "client_multi_results", "client_multi_statements",
  "client_transactions",
]

pub fn has_capability_flag(flags: Int, name: String) -> Bool {
  has_flag(all_capability_flags, flags, name)
}

pub fn remove_capability_flag(flags: Int, name: String) -> Int {
  remove_flag(all_capability_flags, flags, name)
}

pub fn put_capability_flag(flags: Int, names: List(String)) -> Int {
  put_flags(all_capability_flags, flags, names)
}

pub fn list_capability_flags(flags: Int) -> List(String) {
  list_flags(all_capability_flags, flags)
}

fn has_flag(all_flags: List(#(String, Int)), flags: Int, name: String) -> Bool {
  case list.key_find(all_flags, name) {
    Ok(value) -> int.bitwise_and(flags, value) == value
    Error(_) -> False
  }
}

fn remove_flag(all_flags: List(#(String, Int)), flags: Int, name: String) -> Int {
  case list.key_find(all_flags, name) {
    Ok(value) -> int.bitwise_not(value) |> int.bitwise_and(flags)
    Error(_) -> flags
  }
}

fn put_flags(
  all_flags: List(#(String, Int)),
  flags: Int,
  names: List(String),
) -> Int {
  names
  |> list.try_map(fn(name) { list.key_find(all_flags, name) })
  |> result.unwrap([])
  |> list.fold(flags, fn(acc, value) { int.bitwise_or(acc, value) })
}

fn list_flags(all_flags: List(#(String, Int)), flags: Int) -> List(String) {
  all_flags
  |> list.map(fn(key_val) { key_val.0 })
  |> list.filter(has_flag(all_flags, flags, _))
}
