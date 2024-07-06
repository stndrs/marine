import gleam/bit_array
import gleam/bytes_builder
import gleam/int
import gleam/io
import gleam/list
import gleeunit
import gleeunit/should
import marine/config
import marine/errors
import marine/protocol

// import marine/flags

pub fn main() {
  gleeunit.main()
}

// Basic packets tests

pub type PacketTest {
  PacketTest(
    payload: BitArray,
    seq_id: Int,
    max_packet_size: Int,
    expected_packets: List(BitArray),
    expected_seq_id: Int,
  )
}

pub fn encode_packet_test() {
  let header_1 = <<14:little-int-size(24), 0:little-int>>
  let payload_1 = <<"useful_payload":utf8>>
  let expected_packets_1 = bit_array.append(header_1, payload_1)

  let payload_2a =
    fn() { int.random(99) }
    |> list.repeat(times: 16)
    |> list.fold(bytes_builder.new(), fn(acc, num) {
      acc |> bytes_builder.append(<<num():int>>)
    })
    |> bytes_builder.to_bit_array

  let payload_2b =
    fn() { int.random(99) }
    |> list.repeat(times: 2)
    |> list.fold(bytes_builder.new(), fn(acc, num) {
      acc |> bytes_builder.append(<<num():int>>)
    })
    |> bytes_builder.to_bit_array

  let header_2a = <<16:little-int-size(24), 0:little-int>>
  let header_2b = <<2:little-int-size(24), 1:little-int>>
  let expected_packets_2 = [
    bit_array.append(header_2a, payload_2a),
    bit_array.append(header_2b, payload_2b),
  ]

  [
    PacketTest(
      payload: payload_1,
      seq_id: 0,
      max_packet_size: 14,
      expected_packets: [expected_packets_1],
      expected_seq_id: 1,
    ),
    PacketTest(
      payload: <<payload_2a:bits, payload_2b:bits>>,
      seq_id: 0,
      max_packet_size: 16,
      expected_packets: expected_packets_2,
      expected_seq_id: 2,
    ),
  ]
  |> list.each(fn(packet_test) {
    let PacketTest(payload, seq_id, max_packet_size, expected, expected_seq_id) =
      packet_test

    let #(bits, actual_seq_id) =
      protocol.encode_packet(payload, seq_id, max_packet_size)

    actual_seq_id |> should.equal(expected_seq_id)

    list.zip(bits, expected)
    |> list.each(fn(zipped) {
      let #(actual, expected) = zipped

      actual
      |> bytes_builder.to_bit_array
      |> bit_array.inspect
      |> should.equal(expected |> bit_array.inspect)
    })
  })
}

// pub fn initial_handshake_test() {
//   mock_packet()
//   |> protocol.initial_handshake
//   |> should.be_ok
// }
// 
// pub fn compile_capability_flags_test() {
//   let config = config.new()
// 
//   let handshake =
//     mock_packet()
//     |> protocol.initial_handshake
//     |> should.be_ok
// 
//   handshake.capability_flags
//   |> flags.has_capability_flag("client_protocol_41")
//   |> should.be_true
// 
//   handshake.capability_flags
//   |> flags.has_capability_flag("client_protocol_41")
//   |> should.be_true
// 
//   flags.list_capability_flags(handshake.capability_flags)
// 
//   let client_capability_flags =
//     handshake
//     |> protocol.compile_capability_flags(config)
//     |> should.be_ok
// 
//   client_capability_flags
//   |> flags.list_capability_flags()
// 
//   client_capability_flags
//   |> flags.has_capability_flag("client_protocol_41")
//   |> should.be_true
// }

pub fn handle_full_auth_response_test() {
  let conf = config.new()

  protocol.handle_auth_response(conf, protocol.FullAuth)
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn handle_auth_response_test() {
  let conf = config.new()

  // use valid resp body
  protocol.handle_auth_response(conf, protocol.AuthResponse(<<>>))
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn handle_auth_more_data_test() {
  let conf = config.new()

  // use valid resp body
  protocol.handle_auth_response(conf, protocol.AuthMoreData(<<>>))
  |> should.be_ok
  |> should.equal(<<>>)
}

pub fn handle_auth_error_test() {
  let conf = config.new()

  // use valid resp body
  protocol.handle_auth_response(conf, protocol.AuthError(<<>>))
  |> should.be_error
  |> should.equal(errors.ProtocolError(-1, "auth_error", <<>>))
}
// pub fn handle_auth_switch_request_test() {
//   let conf =
//     config.new()
//     |> config.set_port(33_066)
// 
//   // use valid resp body
//   protocol.handle_auth_response(
//     conf,
//     protocol.AuthSwitchRequest(protocol.MySQLNativePassword, "data"),
//   )
//   |> should.be_ok
//   |> should.equal(<<>>)
// }

// fn mock_packet() -> BitArray {
//   <<
//     90, 0, 0, 0, 10, 49, 49, 46, 52, 46, 50, 45, 77, 97, 114, 105, 97, 68, 66,
//     45, 117, 98, 117, 50, 52, 48, 52, 0, 3, 0, 0, 0, 117, 71, 65, 81, 83, 46, 43,
//     45, 0, 254, 255, 45, 2, 0, 255, 129, 21, 0, 0, 0, 0, 0, 0, 29, 0, 0, 0, 64,
//     57, 59, 94, 72, 44, 65, 67, 106, 111, 112, 97, 0, 109, 121, 115, 113, 108,
//     95, 110, 97, 116, 105, 118, 101, 95, 112, 97, 115, 115, 119, 111, 114, 100,
//     0,
//   >>
// }
