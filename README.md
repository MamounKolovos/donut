# donut

[![Package Version](https://img.shields.io/hexpm/v/donut)](https://hex.pm/packages/donut)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/donut/)

```sh
gleam add donut@1
```

Donut helps you talk to websockets from your Lustre application. Connection events become messages you already know how to respond to. It's designed to integrate seamlessly with Lustre's simulate module, so you can test that logic without a real connection.

# Usage
```gleam
// src/ping_client.gleam

import donut
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const server_url = "wss://echo.websocket.org"

pub type Model {
  Model(connection: ConnectionState, ping: PingState)
}

pub type ConnectionState {
  Connecting
  Connected(handle: donut.Handle)
  Disconnected
}

pub type PingState {
  Idle
  Pending
  Acknowledged
}

pub type Message {
  ReceivedEvent(event: donut.Event)
  UserClickedPing
}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

pub fn init(_args: Nil) -> #(Model, Effect(Message)) {
  let model = Model(connection: Connecting, ping: Idle)
  let effect = donut.init(server_url, ReceivedEvent)
  #(model, effect)
}

pub fn update(model: Model, message: Message) -> #(Model, Effect(Message)) {
  case model, message {
    model, ReceivedEvent(event: donut.Opened(handle:)) -> #(
      Model(..model, connection: Connected(handle:)),
      effect.none(),
    )

    _, ReceivedEvent(event: donut.Closed(..))
    | _, ReceivedEvent(event: donut.Errored(..))
    | _, ReceivedEvent(event: donut.FailedToInitialize)
    -> #(Model(connection: Disconnected, ping: Idle), effect.none())

    Model(connection: Connected(..), ping: Pending),
      ReceivedEvent(event: donut.ReceivedMessage(..))
    -> #(Model(..model, ping: Acknowledged), effect.none())

    Model(connection: Connected(handle:), ..), UserClickedPing -> #(
      Model(..model, ping: Pending),
      donut.send(handle, donut.Text("ping")),
    )

    model, _ -> #(model, effect.none())
  }
}

pub fn view(model: Model) -> Element(Message) {
  html.div([], [
    html.button(
      [
        event.on_click(UserClickedPing),
        attribute.disabled(case model.connection, model.ping {
          Connected(..), Idle | Connected(..), Acknowledged -> False
          _, _ -> True
        }),
      ],
      [html.text("Send ping")],
    ),
    html.p([], [
      html.text(case model.ping {
        Idle -> ""
        Pending -> "Waiting..."
        Acknowledged -> "Pong!"
      }),
    ]),
  ])
}
```

# Testing
```gleam
// test/ping_client_test.gleam

import donut
import ping_client
import gleeunit
import lustre/dev/simulate

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn successful_roundtrip_test() {
  let simulation =
    simulate.application(ping_client.init, ping_client.update, ping_client.view)
    |> simulate.start(Nil)
  let handle = donut.test_handle(for: simulation, using: 0)

  let simulation =
    simulation
    |> simulate.message(ping_client.ReceivedEvent(donut.Opened(handle: handle)))
    |> simulate.message(ping_client.UserClickedPing)
    |> simulate.message(
      ping_client.ReceivedEvent(donut.ReceivedMessage(
        handle: handle,
        message: donut.Text("ping"),
      )),
    )

  let assert ping_client.Model(
    connection: ping_client.Connected(..),
    ping: ping_client.Acknowledged,
  ) = simulate.model(simulation)
}
```

## Development

```sh
gleam run -m lustre/dev start donut_dev # Serve the echo client
gleam test  # Run the tests against the echo client
```

Further documentation can be found at <https://hexdocs.pm/donut>.