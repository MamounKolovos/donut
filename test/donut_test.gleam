import donut
import donut_dev/echo_client
import gleeunit
import lustre/dev/simulate

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn roundtrip_test() {
  let simulation =
    simulate.application(echo_client.init, echo_client.update, echo_client.view)
    |> simulate.start(Nil)

  let handle = donut.test_handle(for: simulation, using: 0)

  let simulation =
    simulation
    |> simulate.message(echo_client.ReceivedEvent(donut.Opened(handle:)))
    |> simulate.message(echo_client.UserRequestedSend(donut.Text("hello")))
    |> simulate.message(
      echo_client.ReceivedEvent(donut.ReceivedMessage(
        handle:,
        message: donut.Text("hello"),
      )),
    )

  let assert echo_client.Model(
    history: [echo_client.Received("hello"), echo_client.Sent("hello")],
    ..,
  ) = simulate.model(simulation)
}

pub fn init_failed_test() {
  let simulation =
    simulate.application(echo_client.init, echo_client.update, echo_client.view)
    |> simulate.start(Nil)
    |> simulate.message(echo_client.ReceivedEvent(donut.FailedToInitialize))

  let assert echo_client.Model(connection: echo_client.Faulted, ..) =
    simulate.model(simulation)
}

pub fn stale_handle_test() {
  let simulation =
    simulate.application(echo_client.init, echo_client.update, echo_client.view)
    |> simulate.start(Nil)

  let old_handle = donut.test_handle(for: simulation, using: 0)

  let simulation =
    simulation
    |> simulate.message(echo_client.ReceivedEvent(donut.Opened(old_handle)))
    |> simulate.message(echo_client.UserRequestedSend(donut.Text("old hello")))
    |> simulate.message(echo_client.UserRequestedDisconnect)
    |> simulate.message(
      echo_client.ReceivedEvent(donut.Closed(old_handle, code: donut.Normal)),
    )

  let new_handle = donut.test_handle(for: simulation, using: 1)

  let simulation =
    simulation
    |> simulate.message(echo_client.UserRequestedConnect)
    |> simulate.message(echo_client.ReceivedEvent(donut.Opened(new_handle)))
    |> simulate.message(echo_client.UserRequestedSend(donut.Text("new hello")))
    |> simulate.message(
      echo_client.ReceivedEvent(donut.ReceivedMessage(
        handle: old_handle,
        message: donut.Text("old hello"),
      )),
    )
    |> simulate.message(
      echo_client.ReceivedEvent(donut.ReceivedMessage(
        handle: new_handle,
        message: donut.Text("new hello"),
      )),
    )
    |> simulate.message(
      echo_client.ReceivedEvent(donut.Closed(new_handle, code: donut.Normal)),
    )

  let assert echo_client.Model(
    connection: echo_client.Disconnected,
    history: [
      echo_client.Received("new hello"),
      echo_client.Sent("new hello"),
      echo_client.Sent("old hello"),
    ],
    ..,
  ) = simulate.model(simulation)
}
