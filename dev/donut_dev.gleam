import donut_dev/echo_client
import lustre

pub fn main() -> Nil {
  let app =
    lustre.application(echo_client.init, echo_client.update, echo_client.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
