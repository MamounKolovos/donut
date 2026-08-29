//// <script>
//// // Credit to vshakitskiy for the script
//// const docs = [
////   {
////     header: "Connection",
////     functions: [
////       "close",
////       "init",
////       "send",
////     ]
////   },
////   {
////     header: "Testing",
////     functions: ["test_handle",]
////   },
//// ]
////
//// const callback = () => {
////   const list = document.querySelector(".sidebar > ul:last-of-type")
////   const sortedLists = document.createDocumentFragment()
////   const sortedMembers = document.createDocumentFragment()
////
////   for (const section of docs) {
////     sortedLists.append((() => {
////       const node = document.createElement("h3")
////       node.append(section.header)
////       return node
////     })())
////     sortedMembers.append((() => {
////       const node = document.createElement("h2")
////       node.append(section.header)
////       return node
////     })())
////
////     const sortedList = document.createElement("ul")
////     sortedLists.append(sortedList)
////
////     const sortedFunctions = [...section.functions].sort()
////
////     for (const funcName of sortedFunctions) {
////       const href = `#${funcName}`
////       const member = document.querySelector(
////         `.member:has(h2 > a[href="${href}"])`
////       )
////       const sidebar = list.querySelector(`li:has(a[href="${href}"])`)
////       sortedList.append(sidebar)
////       sortedMembers.append(member)
////     }
////   }
////
////   document.querySelector(".sidebar").insertBefore(sortedLists, list)
////   document
////     .querySelector(".module-members:has(#module-values)")
////     .insertBefore(
////       sortedMembers,
////       document.querySelector("#module-values").nextSibling
////     )
//// }
////
//// document.readyState !== "loading"
////   ? callback()
////   : document.addEventListener(
////     "DOMContentLoaded",
////     callback,
////     { once: true }
////   )
//// </script>
//// 
//// Donut helps you talk to websockets from your Lustre application. Connection events become messages you already know how to respond to.
//// It's designed to integrate seamlessly with Lustre's simulate module, so you can test that logic without a real connection.

import lustre/dev/simulate.{type Simulation}
import lustre/effect.{type Effect}

/// The lifecycle events a websocket connection can produce.
pub type Event {
  /// The connection failed to open. Malformed url, browser-blocked port, etc.
  FailedToInitialize
  /// The connection was successfully opened.
  Opened(handle: Handle)
  /// The connection received a message from the server.
  ReceivedMessage(handle: Handle, message: WebsocketMessage)
  /// The connection errored out.
  Errored(handle: Handle)
  /// The connection was closed.
  Closed(handle: Handle, code: CloseCode)
}

/// An opaque handle that maps to a websocket connection.
/// 
/// Storing a handle on your model instead of the connection directly keeps your model pure and testable.
pub opaque type Handle {
  Handle(id: Int)
}

/// The message type that can be sent or received on a websocket connection.
pub type WebsocketMessage {
  /// A UTF-8 text message.
  Text(data: String)
  /// A binary message.
  Binary(data: BitArray)
}

/// Emitted with the `Closed` event indicating the reason the connection was closed.
pub type CloseCode {
  /// Code 1000: The purpose of the connection was fulfilled.
  Normal
  /// Code 1001: The endpoint is going away because the server is shutting down.
  GoingAway
  /// Code 1002: The server received a message that violates its protocol. Invalid frame, bad data format, etc.
  ProtocolError
  /// Code 1003: The server received a type of data it cannot accept.
  UnexpectedTypeOfData
  /// Code 1005: Synthesized by the browser when no close code was sent.
  NoCodeFromServer
  /// Code 1006: Synthesized by the browser when the connection was abruptly severed without the server sending a close frame.
  AbnormalClose
  /// Code 1007: Received data within a message that was not consistent with the type of the message
  /// (e.g. non-UTF8 data within a text message).
  IncomprehensibleFrame
  /// Code 1008: The server received a message that violates its policy.
  PolicyViolated
  /// Code 1009: The server received a message that is too big for it to process.
  MessageTooBig
  /// Code 1011: The server encountered an unexpected condition that prevented it from fulfilling the request.
  UnexpectedFailure
  /// Code 1012: The server is restarting and clients may reconnect shortly.
  ServiceRestart
  /// Code 1013: The server is overloaded and clients should retry later.
  TryAgainLater
  /// Code 1014: The server acting as a gateway received an invalid response from the upstream server.
  BadGateway
  /// Code 1015: Synthesized by the browser when the connection was closed due to a failure to perform a TLS handshake.
  FailedTLSHandshake
  /// Code 3000-4999: Application specific code.
  ApplicationCode(code: Int)
  /// Any close code not recognized by this package. Could be invalid, new code added by the spec, etc.
  UnrecognizedCode(code: Int)
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
    1011 -> UnexpectedFailure
    1012 -> ServiceRestart
    1013 -> TryAgainLater
    1014 -> BadGateway
    1015 -> FailedTLSHandshake
    code if code >= 3000 && code < 5000 -> ApplicationCode(code:)
    code -> UnrecognizedCode(code:)
  }
}

/// Initialize a websocket connection.
pub fn init(
  url url: String,
  to_message to_message: fn(Event) -> msg,
) -> Effect(msg) {
  use dispatch <- effect.from

  let result =
    do_init(
      url:,
      on_open: fn(id) {
        let event = Opened(handle: Handle(id:))
        to_message(event) |> dispatch
      },
      on_text: fn(id, data) {
        let event = ReceivedMessage(handle: Handle(id:), message: Text(data:))
        to_message(event) |> dispatch
      },
      on_binary: fn(id, data) {
        let event = ReceivedMessage(handle: Handle(id:), message: Binary(data:))
        to_message(event) |> dispatch
      },
      on_error: fn(id) {
        let event = Errored(handle: Handle(id:))
        to_message(event) |> dispatch
      },
      on_close: fn(id, code) {
        let event = Closed(handle: Handle(id:), code: to_code(code))
        to_message(event) |> dispatch
      },
    )

  case result {
    Ok(Nil) -> Nil
    Error(Nil) -> to_message(FailedToInitialize) |> dispatch
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

/// Send a message over the websocket connection identified by `handle`.
/// 
/// Does nothing if the connection doesn't exist or the connection's ready state isn't `OPEN`.
pub fn send(
  using handle: Handle,
  send message: WebsocketMessage,
) -> Effect(msg) {
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

/// Close the websocket connection identified by `handle`.
/// 
/// Does nothing if the connection doesn't exist.
pub fn close(handle: Handle) -> Effect(msg) {
  use _ <- effect.from

  do_close(handle.id)
}

@external(javascript, "./donut_ffi.mjs", "close")
fn do_close(id: Int) -> Nil

// Testing

/// Constructs a `Handle` for use in a simulation, letting tests simulate
/// events from the server.
/// 
/// Takes a `Simulation` so this can't accidentally be called outside a test
/// context. Takes an `id` because there's no id allocator in tests, it's
/// the caller's responsibility to keep ids unique.
pub fn test_handle(
  for _simulation: Simulation(model, message),
  using id: Int,
) -> Handle {
  Handle(id:)
}
