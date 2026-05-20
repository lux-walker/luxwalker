import gleam/int
import gleam/list
import lustre/attribute.{class, href, placeholder, type_, value}
import lustre/element.{type Element, text}
import lustre/element/html.{
  a, button, div, form, h2, input, label, nav, p, span, strong,
}
import lustre/event.{on_click, on_input, on_submit}
import routing.{ActiveSearches, CreateSearch}
import shared/charon.{
  type CreateAppointmentRequest, type SearchStatusDisplay, type SearchSummary,
  Completed, NoResult, Processing,
}
import ui_types.{
  type FormField, type Model, type Msg, AppointmentForm, DoctorFirstName,
  DoctorLastName, NotificationEmail, Password, RerunSearch, Service, Submit,
  UpdateField,
}

pub fn view(active_tab: routing.ActiveTab, model: Model) -> Element(Msg) {
  let content = case active_tab {
    CreateSearch -> view_form(model.form)
    ActiveSearches -> view_searches(model.searches, model.user_email)
  }
  div([], [view_tabs(active_tab, model.user_email), content])
}

fn view_tabs(active_tab: routing.ActiveTab, user_email: String) -> Element(Msg) {
  nav([class("flex border-b border-hl-med mb-8")], [
    view_tab(
      "Active Searches",
      "/" <> user_email <> "/searches",
      active_tab == ActiveSearches,
    ),
    view_tab(
      "Create Search",
      "/" <> user_email <> "/create",
      active_tab == CreateSearch,
    ),
  ])
}

fn view_tab(lbl: String, path: String, is_active: Bool) -> Element(Msg) {
  let base =
    "px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors"
  let classes = case is_active {
    True -> base <> " border-pine text-pine"
    False ->
      base
      <> " border-transparent text-subtle hover:text-text hover:border-hl-high"
  }
  a([href(path), class(classes)], [text(lbl)])
}

fn view_form(search_form: CreateAppointmentRequest) -> Element(Msg) {
  form(
    [
      class("bg-surface rounded-xl shadow-sm border border-hl-med p-6 mb-8"),
      on_submit(fn(_) { AppointmentForm(Submit) }),
    ],
    [
      h2([class("text-lg font-semibold text-text mb-4")], [
        text("New Search"),
      ]),
      divc("space-y-4", [
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
            "mt-6 w-full bg-pine hover:bg-foam text-surface font-medium py-2.5 px-4 rounded-lg transition-colors cursor-pointer",
          ),
        ],
        [text("Start Search")],
      ),
    ],
  )
}

fn view_searches(
  searches: List(SearchSummary),
  user_email: String,
) -> Element(Msg) {
  divc("bg-surface rounded-xl shadow-sm border border-hl-med p-6", [
    h2([class("text-lg font-semibold text-text mb-4")], [
      text("Active Searches"),
    ]),
    case searches {
      [] -> p([class("text-muted text-sm")], [text("No active searches")])
      _ ->
        divc("space-y-3", searches |> list.map(view_search_card(_, user_email)))
    },
  ])
}

fn view_search_card(summary: SearchSummary, user_email: String) -> Element(Msg) {
  let detail_url = "/" <> user_email <> "/request/details/" <> summary.id
  divc(
    "border border-hl-med rounded-lg hover:border-foam transition-colors",
    [
      a([href(detail_url), class("block p-4 hover:bg-hl-low")], [
        divc("flex items-center justify-between mb-2", [
          strong([class("text-sm font-semibold text-text")], [
            text(summary.service),
          ]),
          span([class("text-xs text-muted font-mono")], [text(summary.id)]),
        ]),
        divc("flex items-center justify-between mb-3 text-sm text-subtle", [
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
      ]),
      case summary.status {
        Processing(_, _) ->
          divc("border-t border-hl-low px-4 py-2", [
            button(
              [
                type_("button"),
                class(
                  "text-xs font-medium text-pine hover:text-foam cursor-pointer",
                ),
                on_click(RerunSearch(summary.id)),
              ],
              [text("Run again")],
            ),
          ])
        _ -> div([], [])
      },
    ],
  )
}

fn view_status_badge(status: SearchStatusDisplay) -> Element(Msg) {
  case status {
    NoResult ->
      span(
        [
          class(
            "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-overlay text-gold",
          ),
        ],
        [text("Waiting")],
      )
    Processing(attempts, last_message) ->
      div([], [
        span(
          [
            class(
              "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-overlay text-foam",
            ),
          ],
          [text("Processing (attempt " <> int.to_string(attempts) <> ")")],
        ),
        span(
          [
            class(
              "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-overlay text-iris ml-1",
            ),
          ],
          [text(last_message)],
        ),
      ])
    Completed(terms) ->
      span(
        [
          class(
            "inline-flex items-center text-xs font-medium px-2.5 py-0.5 rounded-full bg-overlay text-pine",
          ),
        ],
        [text("Found " <> int.to_string(list.length(terms)) <> " terms")],
      )
  }
}

fn view_input(
  lbl: String,
  input_type: String,
  val: String,
  field: FormField,
) -> Element(Msg) {
  div([], [
    label([class("block text-sm font-medium text-subtle mb-1")], [
      text(lbl),
    ]),
    input([
      type_(input_type),
      value(val),
      placeholder(lbl),
      class(
        "w-full px-3 py-2 bg-base border border-hl-high rounded-lg text-sm text-text focus:outline-none focus:ring-2 focus:ring-pine focus:border-pine placeholder:text-muted",
      ),
      on_input(fn(v) { AppointmentForm(UpdateField(field, v)) }),
    ]),
  ])
}

fn divc(classes: String, children: List(Element(Msg))) -> Element(Msg) {
  div([class(classes)], children)
}
