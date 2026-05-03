import lustre
import state
import view/app

pub fn main() {
  let application = lustre.application(state.init, state.update, app.view)
  let assert Ok(_) = lustre.start(application, "#app", [])
  Nil
}
