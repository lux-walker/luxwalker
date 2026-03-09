import gleam/option.{None}
import lustre/effect.{type Effect}
import modem
import requests
import routing.{ActiveSearches, CreateSearch, EmailRoute, TabRoute}
import ui_types.{
  type Model, type Msg, AppointmentForm as AppointmentForm,
  EmailForm as EmailForm, EmailInput, EmailSubmit, Model, OnHttpRequest,
  OnRouteChange, Submit, UpdateField,
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  let routing.RouteState(route: initial_route, email:) =
    routing.get_initial_route_state()
  let modem_init = modem.init(url_init_effect)
  let initial_effects = case initial_route {
    TabRoute(ActiveSearches) ->
      effect.batch([modem_init, requests.fetch_searches(email)])
    TabRoute(CreateSearch) -> modem_init
    EmailRoute -> modem_init
  }
  #(
    Model(
      route: initial_route,
      searches: [],
      form: ui_types.empty_form(),
      user_email: email,
    ),
    initial_effects,
  )
}

fn url_init_effect(uri) -> Msg {
  OnRouteChange(routing.get_route_from_uri(uri))
}

fn on_route_change(model: Model, route: routing.Route) -> #(Model, Effect(Msg)) {
  case route {
    TabRoute(ActiveSearches) -> #(
      Model(..model, route: TabRoute(ActiveSearches)),
      requests.fetch_searches(model.user_email),
    )
    TabRoute(CreateSearch) -> #(
      Model(..model, route: TabRoute(CreateSearch)),
      effect.none(),
    )
    EmailRoute -> #(Model(..model, route: EmailRoute), effect.none())
  }
}

fn on_appointment_form_change(
  action: ui_types.AppointmentFormAction,
  model: Model,
) -> #(Model, Effect(Msg)) {
  case action {
    UpdateField(field, value) -> #(
      Model(..model, form: ui_types.update_field(model.form, field, value)),
      effect.none(),
    )
    Submit -> #(
      Model(..model, form: ui_types.empty_form()),
      requests.post_search(model.form, model.user_email),
    )
  }
}

fn on_http_request(
  model: Model,
  request: ui_types.HttpRequest,
) -> #(Model, Effect(Msg)) {
  case request {
    ui_types.SearchRequestSubmitted(Ok(_)) -> #(
      model,
      requests.fetch_searches(model.user_email),
    )
    ui_types.SearchRequestSubmitted(Error(_)) -> #(model, effect.none())
    ui_types.SearchesFetched(Ok(searches)) -> #(
      Model(..model, searches: searches),
      effect.none(),
    )
    ui_types.SearchesFetched(Error(_)) -> #(model, effect.none())
  }
}

pub fn on_email_form_change(
  action: ui_types.EmailFormAction,
  model: Model,
) -> #(Model, Effect(Msg)) {
  case action {
    EmailInput(value) -> #(Model(..model, user_email: value), effect.none())
    EmailSubmit -> #(model, modem.push("/" <> model.user_email, None, None))
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(route) -> on_route_change(model, route)
    OnHttpRequest(http_request) -> on_http_request(model, http_request)
    AppointmentForm(action) -> on_appointment_form_change(action, model)
    EmailForm(action) -> on_email_form_change(action, model)
  }
}
