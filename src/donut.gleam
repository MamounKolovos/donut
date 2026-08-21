import lustre/effect.{type Effect}

pub type Event {
  FailedToInitialize
  Opened(handle: Handle)
  ReceivedMessage(handle: Handle, message: WebsocketMessage)
  Errored(handle: Handle)
  Closed(handle: Handle, code: CloseCode)
}

pub opaque type Handle {
  Handle(id: Int)
}

pub type WebsocketMessage {
  Text(data: String)
  Binary(data: BitArray)
}

pub type CloseCode {
  Normal
  GoingAway
  ProtocolError
  UnexpectedTypeOfData
  NoCodeFromServer
  AbnormalClose
  IncomprehensibleFrame
  PolicyViolated
  MessageTooBig
  FailedExtensionNegotiation
  UnexpectedFailure
  FailedTLSHandshake
  OtherCloseReason
}

fn to_code(code: Int) -> CloseCode {
  case code {
    1000 -> Normal
    1001 -> GoingAway
    1002 -> ProtocolError
    1003 -> UnexpectedTypeOfData
    1005 -> NoCodeFromServer
    1006 -> AbnormalClose
    1007 -> IncomprehensibleFrame
    1008 -> PolicyViolated
    1009 -> MessageTooBig
    1010 -> FailedExtensionNegotiation
    1011 -> UnexpectedFailure
    1015 -> FailedTLSHandshake
    _ -> OtherCloseReason
  }
}

pub fn init(url url: String, to_msg to_msg: fn(Event) -> msg) -> Effect(msg) {
  use dispatch <- effect.from

  let result =
    do_init(
      url:,
      on_open: fn(id) {
        let event = Opened(handle: Handle(id:))
        to_msg(event) |> dispatch
      },
      on_text: fn(id, data) {
        let event = ReceivedMessage(handle: Handle(id:), message: Text(data:))
        to_msg(event) |> dispatch
      },
      on_binary: fn(id, data) {
        let event = ReceivedMessage(handle: Handle(id:), message: Binary(data:))
        to_msg(event) |> dispatch
      },
      on_error: fn(id) {
        let event = Errored(handle: Handle(id:))
        to_msg(event) |> dispatch
      },
      on_close: fn(id, code) {
        let event = Closed(handle: Handle(id:), code: to_code(code))
        to_msg(event) |> dispatch
      },
    )

  case result {
    Ok(Nil) -> Nil
    Error(Nil) -> to_msg(FailedToInitialize) |> dispatch
  }
}

@external(javascript, "./donut_ffi.mjs", "init")
fn do_init(
  url url: String,
  on_open handle_open: fn(Int) -> Nil,
  on_text handle_text: fn(Int, String) -> Nil,
  on_binary handle_binary: fn(Int, BitArray) -> Nil,
  on_error handle_error: fn(Int) -> Nil,
  on_close handle_close: fn(Int, Int) -> Nil,
) -> Result(Nil, Nil)

pub fn send(handle: Handle, message: WebsocketMessage) -> Effect(msg) {
  use _ <- effect.from

  case message {
    Text(data:) -> do_send_text(handle.id, data)
    Binary(data:) -> do_send_binary(handle.id, data)
  }
}

@external(javascript, "./donut_ffi.mjs", "send_text")
fn do_send_text(id: Int, text: String) -> Nil

@external(javascript, "./donut_ffi.mjs", "send_binary")
fn do_send_binary(id: Int, bit_array: BitArray) -> Nil

pub fn close(handle: Handle) -> Effect(msg) {
  use _ <- effect.from

  do_close(handle.id)
}

@external(javascript, "./donut_ffi.mjs", "close")
fn do_close(id: Int) -> Nil
