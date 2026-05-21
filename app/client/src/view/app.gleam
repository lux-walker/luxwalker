import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class, type_}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, h2, p}
import lustre/event.{on_click}
import routing.{EmailRoute, RequestDetailsRoute, TabRoute}
import ui_types.{
  type Model, type Msg, BookingCreatedPopup, DismissPopup, ErrorPopup,
  LoadingPopup,
}
import view/email_entry
import view/search_result
import view/tab/appointment

fn divc(classes: String, children: List(Element(Msg))) -> Element(Msg) {
  div([class(classes)], children)
}

pub fn view(model: Model) -> Element(Msg) {
  divc("min-h-screen bg-gradient-to-br from-base to-overlay", [
    divc("max-w-2xl mx-auto px-4 py-10", [
      h1([class("text-3xl font-bold text-text")], [text("Luxwalker")]),
      p([class("text-subtle mt-1 mb-8")], [
        text("Medical appointment search"),
      ]),
      case model.route {
        EmailRoute -> email_entry.view(model)
        TabRoute(active_tab) -> appointment.view(active_tab, model)
        RequestDetailsRoute(id) -> search_result.view(id, model)
      },
    ]),
    case model.popup {
      None -> div([], [])
      Some(popup) -> view_popup(popup)
    },
  ])
}

fn view_popup(popup: ui_types.Popup) -> Element(Msg) {
  case popup {
    BookingCreatedPopup(clinic, date_time, doctor) ->
      popup_shell("Appointment booked", "text-pine", "bg-pine", [
        p([class("text-sm text-subtle mb-4")], [
          text("Luxwalker reserved a slot for you."),
        ]),
        divc("space-y-2 text-sm text-text mb-6", [
          divc("flex gap-2", [span_label("Doctor:"), span_value(doctor)]),
          divc("flex gap-2", [span_label("Clinic:"), span_value(clinic)]),
          divc("flex gap-2", [span_label("When:"), span_value(date_time)]),
        ]),
      ])
    ErrorPopup(message) ->
      popup_shell("Search failed", "text-love", "bg-love", [
        p([class("text-sm text-text mb-6")], [text(message)]),
      ])
    LoadingPopup ->
      modal_wrapper([
        divc("flex flex-col items-center gap-4 py-4", [
          divc(
            "h-10 w-10 border-4 border-pine border-t-transparent rounded-full animate-spin",
            [],
          ),
          h2([class("text-lg font-semibold text-text")], [
            text("Searching for appointments…"),
          ]),
          p([class("text-sm text-subtle text-center")], [
            text(
              "Logging in to LuxMed, looking for available slots, and trying to book one. This may take up to half a minute.",
            ),
          ]),
        ]),
      ])
  }
}

fn modal_wrapper(children: List(Element(Msg))) -> Element(Msg) {
  divc(
    "fixed inset-0 z-50 flex items-center justify-center bg-base/70 backdrop-blur-sm",
    [
      divc(
        "bg-surface rounded-xl shadow-xl border border-hl-med p-6 max-w-md w-full mx-4",
        children,
      ),
    ],
  )
}

fn popup_shell(
  title: String,
  title_color: String,
  button_bg: String,
  body: List(Element(Msg)),
) -> Element(Msg) {
  let close = button(
    [
      type_("button"),
      class(
        "w-full text-surface font-medium py-2.5 px-4 rounded-lg transition-colors cursor-pointer hover:bg-foam "
        <> button_bg,
      ),
      on_click(DismissPopup),
    ],
    [text("Close")],
  )
  let header =
    h2([class("text-xl font-semibold mb-2 " <> title_color)], [text(title)])
  let children = list.flatten([[header], body, [close]])
  divc(
    "fixed inset-0 z-50 flex items-center justify-center bg-base/70 backdrop-blur-sm",
    [
      divc(
        "bg-surface rounded-xl shadow-xl border border-hl-med p-6 max-w-md w-full mx-4",
        children,
      ),
    ],
  )
}

fn span_label(t: String) -> Element(Msg) {
  html.span([class("text-subtle font-medium min-w-20")], [text(t)])
}

fn span_value(t: String) -> Element(Msg) {
  html.span([class("text-text")], [text(t)])
}
