import lustre
import state
import view

pub fn main() {
  let application = lustre.application(state.init, state.update, view.view)
  let assert Ok(_) = lustre.start(application, "#app", [])
  Nil
}
