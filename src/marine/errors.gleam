pub type MarineError {
  ProtocolError(code: Int, name: String, message: BitArray)
  ClientError(message: String)
  GenericError
}
