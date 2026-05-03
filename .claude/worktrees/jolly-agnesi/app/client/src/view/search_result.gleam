import gleam/bool
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute.{class, href}
import lustre/element.{type Element, text}
import lustre/element/html.{a, div, h2, h3, li, p, span, ul}
import shared/types.{type AppSettings, type SearchSummary, type TermResult, Completed}
import ui_types.{type Model, type Msg}

pub fn view(id: String, model: Model) -> Element(Msg) {
  let search = list.find(model.searches, fn(s) { s.id == id })
  case search {
    Error(_) -> view_not_found()
    Ok(summary) -> view_detail(summary, model.user_email, model.app_settings)
  }
}

fn view_not_found() -> Element(Msg) {
  div([class("text-slate-500 text-sm")], [text("Search not found.")])
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
          "inline-flex items-center text-sm text-slate-500 hover:text-slate-700 mb-6",
        ),
      ],
      [text("← Back to searches")],
    ),
    div(
      [class("bg-white rounded-xl shadow-sm border border-slate-200 p-6 mb-4")],
      [
        h2([class("text-lg font-semibold text-slate-800 mb-1")], [
          text(summary.service),
        ]),
        p([class("text-sm text-slate-500 mb-6")], [
          text(
            "Dr. "
            <> summary.doctor_first_name
            <> " "
            <> summary.doctor_last_name,
          ),
        ]),
        case summary.status {
          Completed(terms) ->
            case terms {
              [] ->
                p([class("text-slate-400 text-sm")], [
                  text("No terms available."),
                ])
              _ -> view_terms(terms)
            }
          _ ->
            p([class("text-slate-400 text-sm")], [
              text("No results yet for this search."),
            ])
        },
      ],
    ),
    view_settings(app_settings),
  ])
}

fn view_settings(app_settings: option.Option(AppSettings)) -> Element(Msg) {
  div([class("bg-white rounded-xl shadow-sm border border-slate-200 p-6")], [
    h3([class("text-sm font-semibold text-slate-700 mb-3")], [text("Settings")]),
    case app_settings {
      None ->
        p([class("text-slate-400 text-sm")], [text("Loading...")])
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
    span([class("text-slate-500")], [text(label)]),
    span([class("font-medium text-slate-800")], [text(value)]),
  ])
}

fn view_terms(terms: List(TermResult)) -> Element(Msg) {
  ul([class("space-y-3")], list.map(terms, view_term))
}

fn view_term(term: TermResult) -> Element(Msg) {
  li([class("border border-slate-200 rounded-lg p-3")], [
    div([class("flex items-center justify-between mb-1")], [
      span([class("text-sm font-medium text-slate-800")], [
        text(term.date_time_from),
      ]),
      span([class("text-xs text-slate-500")], [text(term.date_time_to)]),
    ]),
    div([class("text-xs text-slate-500 mt-0.5")], [text(term.clinic)]),
    div([class("text-xs text-slate-400 mt-0.5")], [
      text("Dr. " <> term.doctor_first_name <> " " <> term.doctor_last_name),
    ]),
  ])
}
