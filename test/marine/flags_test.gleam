import gleam/int
import gleam/list
import gleeunit
import gleeunit/should

import marine/flags

pub fn main() {
  gleeunit.main()
}

pub fn has_capability_flag_test() {
  let capability_flags = all_capability_flags()

  flags.all_capability_flags
  |> list.each(fn(key_val) {
    let name = key_val.0

    flags.has_capability_flag(capability_flags, name)
    |> should.be_true
  })
}

pub fn has_some_capability_flags_test() {
  let flag_names = ["client_ssl", "client_protocol_41"]

  let capability_flags = int.bitwise_or(0x00000800, 0x00000200)

  flag_names
  |> list.each(fn(name) {
    flags.has_capability_flag(capability_flags, name) |> should.be_true
  })

  flags.has_capability_flag(capability_flags, "excluded_flag")
  |> should.be_false
}

pub fn remove_capability_flag_test() {
  let capability_flags = all_capability_flags()
  let flag_name = "client_ssl"

  flags.has_capability_flag(capability_flags, flag_name) |> should.be_true

  flags.remove_capability_flag(capability_flags, flag_name)
  |> flags.has_capability_flag(flag_name)
  |> should.be_false
}

pub fn put_capability_flag_test() {
  let capability_flags = all_capability_flags()
  let flag_name = "client_ssl"

  flags.has_capability_flag(capability_flags, flag_name) |> should.be_true

  let flags_without_client_ssl =
    flags.remove_capability_flag(capability_flags, flag_name)

  flags_without_client_ssl
  |> flags.has_capability_flag(flag_name)
  |> should.be_false

  flags_without_client_ssl
  |> flags.put_capability_flag([flag_name])
  |> flags.has_capability_flag(flag_name)
  |> should.be_true
}

fn all_capability_flags() -> Int {
  let assert Ok(capability_flags) =
    flags.all_capability_flags
    |> list.map(fn(key_val) { key_val.1 })
    |> list.reduce(fn(acc, value) { int.bitwise_or(acc, value) })

  capability_flags
}
