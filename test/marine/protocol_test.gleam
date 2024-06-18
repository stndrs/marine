import gleeunit
import gleeunit/should
import marine/protocol

pub fn main() {
  gleeunit.main()
}

pub fn initial_handshake_test() {
  let packet = <<
    90, 0, 0, 0, 10, 49, 49, 46, 52, 46, 50, 45, 77, 97, 114, 105, 97, 68, 66,
    45, 117, 98, 117, 50, 52, 48, 52, 0, 3, 0, 0, 0, 117, 71, 65, 81, 83, 46, 43,
    45, 0, 254, 255, 45, 2, 0, 255, 129, 21, 0, 0, 0, 0, 0, 0, 29, 0, 0, 0, 64,
    57, 59, 94, 72, 44, 65, 67, 106, 111, 112, 97, 0, 109, 121, 115, 113, 108,
    95, 110, 97, 116, 105, 118, 101, 95, 112, 97, 115, 115, 119, 111, 114, 100,
    0,
  >>

  protocol.initial_handshake(packet)
  |> should.be_ok
}
