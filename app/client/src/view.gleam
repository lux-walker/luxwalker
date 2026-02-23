import gleam/int
import gleam/list
import lustre/attribute.{class, href, placeholder, type_, value}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, form, h1, h2, input, label, nav, p, span, strong,
}
import lustre/event.{on_input, on_submit}
import shared/types.{
  type AppointmentRequest, type SearchStatusDisplay, type SearchSummary,
  Completed, NoResult, Processing,
}

import ui_types.{
  type FormField, type Model, type Msg, type Route, ActiveSearches, CreateSearch,
  DoctorFirstName, DoctorLastName, Form, Login, NotificationEmail, Password,
  Service, Submit, UpdateField,
}

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
      view_tabs(model.route),
      case model.route {
        CreateSearch -> view_form(model.form)
        ActiveSearches -> view_searches(model.searches)
      },
    ]),
  ])
}

fn view_tabs(current_route: Route) -> Element(Msg) {
  nav([class("flex border-b border-slate-200 mb-8")], [
    view_tab("Active Searches", "/", current_route == ActiveSearches),
    view_tab("Create Search", "/create", current_route == CreateSearch),
  ])
}

fn view_tab(lbl: String, path: String, is_active: Bool) -> Element(Msg) {
  let base =
    "px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors"
  let classes = case is_active {
    True -> base <> " border-blue-600 text-blue-600"
    False ->
      base
      <> " border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
  }
  a([href(path), class(classes)], [text(lbl)])
}

fn view_form(search_form: AppointmentRequest) -> Element(Msg) {
  form(
    [
      class("bg-white rounded-xl shadow-sm border border-slate-200 p-6 mb-8"),
      on_submit(fn(_) { Form(Submit) }),
    ],
    [
      h2([class("text-lg font-semibold text-slate-800 mb-4")], [
        text("New Search"),
      ]),
      divc("space-y-4", [
        view_input("Login", "text", search_form.login, Login),
        view_input("Password", "password", search_form.password, Password),
        view_input("Service", "text", search_form.service, Service),
        divc("grid grid-cols-1 sm:grid-cols-2 gap-4", [
          view_input(
            "Doctor First Name",
            "text",
            search_form.doctor.first_name,
            DoctorFirstName,
          ),
          view_input(
            "Doctor Last Name",
            "text",
            search_form.doctor.last_name,
            DoctorLastName,
          ),
        ]),
        view_input(
          "Notification Email",
          "email",
          search_form.notification_email,
          NotificationEmail,
        ),
      ]),
      button(
        [
          type_("submit"),
          class(
            "mt-6 w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2.5 px-4 rounded-lg transition-colors cursor-pointer",
          ),
        ],
        [text("Start Search")],
      ),
    ],
  )
}

fn view_input(
  lbl: String,
  input_type: String,
  val: String,
  field: FormField,
) -> Element(Msg) {
  div([], [
    label([class("block text-sm font-medium text-slate-700 mb-1")], [
      text(lbl),
    ]),
    input([
      type_(input_type),
      value(val),
      placeholder(lbl),
      class(
        "w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 placeholder:text-slate-400",
      ),
      on_input(fn(v) { Form(UpdateField(field, v)) }),
    ]),
  ])
}

fn view_searches(searches: List(SearchSummary)) -> Element(Msg) {
  divc("bg-white rounded-xl shadow-sm border border-slate-200 p-6", [
    h2([class("text-lg font-semibold text-slate-800 mb-4")], [
      text("Active Searches"),
    ]),
    case searches {
      [] -> p([class("text-slate-400 text-sm")], [text("No active searches")])
      _ -> divc("space-y-3", searches |> list.map(view_search_card))
    },
  ])
}

fn view_search_card(summary: SearchSummary) -> Element(Msg) {
  divc(
    "border border-slate-200 rounded-lg p-4 hover:border-slate-300 transition-colors",
    [
      divc("flex items-center justify-between mb-2", [
        strong([class("text-sm font-semibold text-slate-800")], [
          text(summary.service),
        ]),
        span([class("text-xs text-slate-400 font-mono")], [
          text(summary.id),
        ]),
      ]),
      divc("flex items-center justify-between mb-3 text-sm text-slate-500", [
        span([], [
          text(
            "Dr. "
            <> summary.doctor_first_name
            <> " "
            <> summary.doctor_last_name,
          ),
        ]),
        span([class("text-xs")], [text(summary.timestamp)]),
      ]),
      view_status_badge(summary.status),
    ],
  )
}

fn view_status_badge(status: SearchStatusDisplay) -> Element(Msg) {
  case status {
    NoResult ->
      span(
        [
          class(
            "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-amber-100 text-amber-800",
          ),
        ],
        [text("Waiting")],
      )
    Processing(attempts, last_message) ->
      div([], [
        span(
          [
            class(
              "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-blue-100 text-blue-800",
            ),
          ],
          [text("Processing (attempt " <> int.to_string(attempts) <> ")")],
        ),
        span(
          [
            class(
              "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-amber-100 text-amber-800 ml-1",
            ),
          ],
          [text(last_message)],
        ),
      ])
    Completed(result) ->
      span(
        [
          class(
            "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800",
          ),
        ],
        [text("Completed: " <> result)],
      )
  }
}
