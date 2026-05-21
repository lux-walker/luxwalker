import gleam/bool
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class, href, type_}
import lustre/element.{type Element, text}
import lustre/element/html.{a, button, div, h2, h3, li, p, span, ul}
import lustre/event.{on_click}
import shared/charon.{
  type AppSettings, type BookingInfo, type ReservationCandidate,
  type SearchSummary, type TermResult, AwaitingConfirmation, Booked, Completed,
}
import ui_types.{type Model, type Msg, ReserveCandidate}

pub fn view(id: String, model: Model) -> Element(Msg) {
  let search = list.find(model.searches, fn(s) { s.id == id })
  case search {
    Error(_) -> view_not_found()
    Ok(summary) -> view_detail(summary, model.user_email, model.app_settings)
  }
}

fn view_not_found() -> Element(Msg) {
  div([class("text-subtle text-sm")], [text("Search not found.")])
}

fn view_detail(
  summary: SearchSummary,
  user_email: String,
  app_settings: option.Option(AppSettings),
) -> Element(Msg) {
  div([], [
    a(
      [
        href("/" <> user_email <> "/searches"),
        class(
          "inline-flex items-center text-sm text-subtle hover:text-pine mb-6",
        ),
      ],
      [text("← Back to searches")],
    ),
    div(
      [class("bg-surface rounded-xl shadow-sm border border-hl-med p-6 mb-4")],
      [
        h2([class("text-lg font-semibold text-text mb-1")], [
          text(summary.service),
        ]),
        p([class("text-sm text-subtle mb-6")], [
          text(
            "Dr. "
            <> summary.doctor_first_name
            <> " "
            <> summary.doctor_last_name,
          ),
        ]),
        case summary.status {
          Booked(terms, booking) ->
            div([], [
              view_booking_card(booking),
              case terms {
                [] -> div([], [])
                _ -> view_terms(terms)
              },
            ])
          AwaitingConfirmation(terms, candidate) ->
            div([], [
              view_candidate_card(summary.id, candidate),
              case terms {
                [] -> div([], [])
                _ -> view_terms(terms)
              },
            ])
          Completed(terms) ->
            case terms {
              [] ->
                p([class("text-muted text-sm")], [
                  text("No terms available."),
                ])
              _ -> view_terms(terms)
            }
          _ ->
            p([class("text-muted text-sm")], [
              text("No results yet for this search."),
            ])
        },
      ],
    ),
    view_settings(app_settings),
  ])
}

fn view_settings(app_settings: option.Option(AppSettings)) -> Element(Msg) {
  div([class("bg-surface rounded-xl shadow-sm border border-hl-med p-6")], [
    h3([class("text-sm font-semibold text-subtle mb-3")], [text("Settings")]),
    case app_settings {
      None ->
        p([class("text-muted text-sm")], [text("Loading...")])
      Some(settings) ->
        div([class("space-y-2")], [
          view_setting_row("Environment", settings.environment),
          view_setting_row(
            "Skip Notifications",
            bool.to_string(settings.skip_notifications),
          ),
        ])
    },
  ])
}

fn view_setting_row(label: String, value: String) -> Element(Msg) {
  div([class("flex items-center justify-between text-sm")], [
    span([class("text-subtle")], [text(label)]),
    span([class("font-medium text-text")], [text(value)]),
  ])
}

fn view_candidate_card(
  search_id: String,
  candidate: ReservationCandidate,
) -> Element(Msg) {
  let doctor_name = case candidate.doctor_academic_title {
    "" -> candidate.doctor_first_name <> " " <> candidate.doctor_last_name
    title ->
      title
      <> " "
      <> candidate.doctor_first_name
      <> " "
      <> candidate.doctor_last_name
  }
  div(
    [
      class(
        "border border-gold rounded-lg p-4 bg-gold/10 mb-4 space-y-3",
      ),
    ],
    [
      div([class("text-sm font-semibold text-gold")], [
        text("Slot found — within 48 hours, requires manual confirmation"),
      ]),
      div([class("space-y-1")], [
        div([class("flex gap-2 text-sm text-text")], [
          span([class("text-subtle font-medium min-w-20")], [text("Doctor:")]),
          span([], [text(doctor_name)]),
        ]),
        div([class("flex gap-2 text-sm text-text")], [
          span([class("text-subtle font-medium min-w-20")], [text("Service:")]),
          span([], [text(candidate.service_variant_name)]),
        ]),
        div([class("flex gap-2 text-sm text-text")], [
          span([class("text-subtle font-medium min-w-20")], [text("Clinic:")]),
          span([], [text(candidate.facility_name)]),
        ]),
        div([class("flex gap-2 text-sm text-text")], [
          span([class("text-subtle font-medium min-w-20")], [text("When:")]),
          span([], [
            text(candidate.date_time_from <> " — " <> candidate.date_time_to),
          ]),
        ]),
      ]),
      button(
        [
          type_("button"),
          class(
            "w-full bg-pine hover:bg-foam text-surface font-medium py-2 px-4 rounded-lg transition-colors cursor-pointer",
          ),
          on_click(ReserveCandidate(search_id)),
        ],
        [text("Reserve this slot")],
      ),
    ],
  )
}

fn view_booking_card(booking: BookingInfo) -> Element(Msg) {
  div(
    [
      class(
        "border border-pine rounded-lg p-4 bg-pine/10 mb-4 space-y-1",
      ),
    ],
    [
      div([class("text-sm font-semibold text-pine mb-2")], [
        text("Appointment booked"),
      ]),
      div([class("flex gap-2 text-sm text-text")], [
        span([class("text-subtle font-medium min-w-20")], [text("Doctor:")]),
        span([], [text(booking.doctor)]),
      ]),
      div([class("flex gap-2 text-sm text-text")], [
        span([class("text-subtle font-medium min-w-20")], [text("Clinic:")]),
        span([], [text(booking.clinic)]),
      ]),
      div([class("flex gap-2 text-sm text-text")], [
        span([class("text-subtle font-medium min-w-20")], [text("When:")]),
        span([], [text(booking.date_time)]),
      ]),
    ],
  )
}

fn view_terms(terms: List(TermResult)) -> Element(Msg) {
  ul([class("space-y-3")], list.map(terms, view_term))
}

fn view_term(term: TermResult) -> Element(Msg) {
  li([class("border border-hl-med rounded-lg p-3 bg-base")], [
    div([class("flex items-center justify-between mb-1")], [
      span([class("text-sm font-medium text-text")], [
        text(term.date_time_from),
      ]),
      span([class("text-xs text-subtle")], [text(term.date_time_to)]),
    ]),
    div([class("text-xs text-subtle mt-0.5")], [text(term.clinic)]),
    div([class("text-xs text-muted mt-0.5")], [
      text("Dr. " <> term.doctor_first_name <> " " <> term.doctor_last_name),
    ]),
  ])
}
