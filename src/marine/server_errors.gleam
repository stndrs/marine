import gleam/list

// https://github.com/elixir-ecto/myxql/blob/7825afc5ca734e00a0db4746bf34a60de009a542/lib/myxql/protocol/server_error_codes.ex#L12
// A list of commonly used 
pub const common_codes = [
  #(1005, "ER_CANT_CREATE_TABLE"), #(1006, "ER_CANT_CREATE_DB"),
  #(1007, "ER_DB_CREATE_EXISTS"), #(1008, "ER_DB_DROP_EXISTS"),
  #(1045, "ER_ACCESS_DENIED_ERROR"), #(1046, "ER_NO_DB_ERROR"),
  #(1049, "ER_BAD_DB_ERROR"), #(1050, "ER_TABLE_EXISTS_ERROR"),
  #(1051, "ER_BAD_TABLE_ERROR"), #(1062, "ER_DUP_ENTRY"),
  #(1146, "ER_NO_SUCH_TABLE"), #(1207, "ER_READ_ONLY_TRANSACTION"),
  #(1295, "ER_UNSUPPORTED_PS"), #(1421, "ER_STMT_HAS_NO_OPEN_CURSOR"),
  #(1451, "ER_ROW_IS_REFERENCED_2"), #(1452, "ER_NO_REFERENCED_ROW_2"),
  #(1461, "ER_MAX_PREPARED_STMT_COUNT_REACHED"),
  #(1792, "ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION"),
  #(1836, "ER_READ_ONLY_MODE"),
]

// TODO: load extra errors from ENV

pub fn to_name(code: Int) -> String {
  let name =
    common_codes
    |> list.key_find(code)

  case name {
    Ok(name) -> name
    _ -> ""
  }
}
