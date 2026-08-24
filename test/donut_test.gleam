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

  let handle = donut.test_handle(0)

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
