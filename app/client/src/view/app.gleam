import lustre/attribute.{class}
import lustre/element.{type Element, text}
import lustre/element/html.{div, h1, p}
import routing.{EmailRoute, TabRoute}
import ui_types.{type Model, type Msg}
import view/email_entry
import view/tab/appointment

fn divc(classes: String, children: List(Element(Msg))) -> Element(Msg) {
  div([class(classes)], children)
}

pub fn view(model: Model) -> Element(Msg) {
  divc("min-h-screen bg-gradient-to-br from-slate-50 to-slate-100", [
    divc("max-w-2xl mx-auto px-4 py-10", [
      h1([class("text-3xl font-bold text-slate-900")], [text("Luxwalker")]),
      p([class("text-slate-500 mt-1 mb-8")], [
        text("Medical appointment search"),
      ]),
      case model.route {
        EmailRoute -> email_entry.view(model)
        TabRoute(active_tab) -> appointment.view(active_tab, model)
      },
    ]),
  ])
}
