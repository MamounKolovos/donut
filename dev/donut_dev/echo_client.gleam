import donut
import gleam/bit_array
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const scroll_sentinel_id = "scroll-sentinel"

const server_url = "wss://echo.websocket.org"

pub type Model {
  Model(connection: ConnectionState, history: List(HistoryEntry), draft: String)
}

pub type HistoryEntry {
  Sent(content: String)
  Received(content: String)
}

pub type ConnectionState {
  Disconnected
  Connecting
  Connected(handle: donut.Handle)
  Disconnecting
  Faulted
}

pub type Message {
  ReceivedEvent(event: donut.Event)
  UserRequestedSend(message: donut.WebsocketMessage)
  UserRequestedConnect
  UserRequestedDisconnect
  UserUpdatedMessageBox(content: String)
}

pub fn init(_args: Nil) -> #(Model, Effect(Message)) {
  let model = Model(connection: Connecting, history: [], draft: "")
  let effect = donut.init(server_url, ReceivedEvent)
  #(model, effect)
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  echo message
  case model, message {
    model, ReceivedEvent(event:) ->
      case event {
        donut.FailedToInitialize -> {
          #(Model(..model, connection: Faulted), effect.none())
        }
        donut.Opened(handle:) -> {
          #(Model(..model, connection: Connected(handle:)), effect.none())
        }
        donut.ReceivedMessage(handle: _, message:) -> {
          let entry = Received(websocket_message_to_string(message))
          let history = [entry, ..model.history]
          #(Model(..model, history:), scroll_to_bottom_of_history())
        }
        donut.Errored(handle: _) -> {
          #(Model(..model, connection: Faulted), effect.none())
        }
        donut.Closed(handle: _, code:) ->
          case code {
            donut.Normal -> {
              #(Model(..model, connection: Disconnected), effect.none())
            }
            _ -> {
              let model = Model(..model, connection: Connecting)
              let effect = donut.init(server_url, ReceivedEvent)
              #(model, effect)
            }
          }
      }
    Model(connection: Connected(handle:), ..), UserRequestedSend(message:) -> {
      let content = websocket_message_to_string(message)
      case content {
        "" -> #(model, effect.none())
        content -> {
          let entry = Sent(content:)
          let history = [entry, ..model.history]
          let effects = [
            donut.send(handle, message),
            scroll_to_bottom_of_history(),
          ]
          #(Model(..model, history:), effect.batch(effects))
        }
      }
    }
    Model(connection: Disconnected, ..), UserRequestedConnect -> {
      #(model, donut.init(server_url, ReceivedEvent))
    }
    Model(connection: Connected(handle:), ..), UserRequestedDisconnect -> {
      #(Model(..model, connection: Disconnecting), donut.close(handle))
    }
    model, UserUpdatedMessageBox(content:) -> {
      #(Model(..model, draft: content), effect.none())
    }
    model, _ -> #(model, effect.none())
  }
}

fn scroll_to_bottom_of_history() -> Effect(Message) {
  use _, _ <- effect.after_paint
  do_scroll_into_view(scroll_sentinel_id)
}

@external(javascript, "./echo_client_ffi.mjs", "scroll_into_view")
fn do_scroll_into_view(id: String) -> Nil

fn websocket_message_to_string(message: donut.WebsocketMessage) -> String {
  case message {
    donut.Text(data:) -> data
    donut.Binary(data:) ->
      case bit_array.to_string(data) {
        Ok(data) -> data
        Error(Nil) -> "[]"
      }
  }
}

const button_classes = "rounded-lg bg-blue-500 px-4 py-2 text-sm font-medium text-white hover:bg-blue-600 disabled:bg-gray-300 disabled:cursor-not-allowed"

pub fn view(model: Model) -> Element(Message) {
  html.div(
    [
      attribute.class("h-screen flex flex-col items-center gap-4 bg-gray-50"),
    ],
    [
      html.div([attribute.class("w-full max-w-md")], [
        connection_buttons_view(model.connection),
      ]),
      html.div(
        [
          attribute.class(
            "history-thing w-full max-w-md flex-1 overflow-y-auto pt-10",
          ),
        ],
        [
          history_view(model.history),
          html.div([attribute.id(scroll_sentinel_id)], []),
        ],
      ),
      html.div([attribute.class("w-full max-w-md pb-6 px-4")], [
        message_box_view(model.draft, model.connection),
      ]),
    ],
  )
}

fn history_view(history: List(HistoryEntry)) -> Element(Message) {
  let rows =
    history
    |> list.reverse
    |> list.map(fn(entry) {
      case entry {
        Sent(content:) ->
          html.div([attribute.class("flex justify-end")], [
            html.div(
              [
                attribute.class(
                  "max-w-[70%] rounded-xl px-3 py-2 bg-blue-500 text-white",
                ),
              ],
              [
                html.text(content),
              ],
            ),
          ])
        Received(content:) ->
          html.div([attribute.class("flex justify-start")], [
            html.div(
              [
                attribute.class(
                  "max-w-[70%] rounded-xl px-3 py-2 bg-gray-200 text-black",
                ),
              ],
              [
                html.text(content),
              ],
            ),
          ])
      }
    })

  html.div(
    [
      attribute.class("w-full max-w-md bg-white rounded-2xl shadow-md p-4"),
    ],
    [element.fragment(rows)],
  )
}

fn message_box_view(
  draft: String,
  connection: ConnectionState,
) -> Element(Message) {
  let submit_disabled =
    draft == ""
    || case connection {
      Connected(_) -> False
      _ -> True
    }

  let form =
    html.form(
      [
        attribute.class("flex gap-2"),
        event.on_submit(fn(fields) {
          let assert [#(_, message), ..] = fields
          UserRequestedSend(message: donut.Text(message))
        }),
      ],
      [
        html.input([
          attribute.type_("text"),
          attribute.name("message-box"),
          attribute.value(draft),
          event.on_input(UserUpdatedMessageBox),
          attribute.placeholder("Type a message..."),
          attribute.class(
            "flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500",
          ),
        ]),
        html.button(
          [
            attribute.type_("submit"),
            attribute.disabled(submit_disabled),
            attribute.class(button_classes),
          ],
          [html.text("Send")],
        ),
      ],
    )

  html.div([attribute.class("bg-white rounded-2xl shadow-md p-6")], [form])
}

fn connection_buttons_view(connection: ConnectionState) -> Element(Message) {
  html.div(
    [
      attribute.class(
        "flex justify-center w-full gap-3 rounded-2xl shadow-md p-6",
      ),
    ],
    [
      html.button(
        [
          event.on_click(UserRequestedConnect),
          attribute.disabled(case connection {
            Disconnected | Faulted -> False
            _ -> True
          }),
          attribute.class(button_classes <> " w-1/2"),
        ],
        [html.text("Connect")],
      ),
      html.button(
        [
          event.on_click(UserRequestedDisconnect),
          attribute.disabled(case connection {
            Connected(_) -> False
            _ -> True
          }),
          attribute.class(button_classes <> " w-1/2"),
        ],
        [html.text("Disconnect")],
      ),
    ],
  )
}
