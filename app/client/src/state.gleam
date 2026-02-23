import gleam/uri
import lustre/effect.{type Effect}
import modem
import rsvp
import shared/types.{type AppointmentRequest}
import ui_types.{
  type Model, type Msg, type Route, ActiveSearches, CreateSearch, Form, Model,
  OnRouteChange, SearchHttpRequestSubmitted as CreateRequestSubmitted,
  SearchesFetched as GetSearchesFetched, Submit, UpdateField,
}

fn on_url_change(uri: uri.Uri) -> Msg {
  case uri.path_segments(uri.path) {
    ["create"] -> OnRouteChange(CreateSearch)
    _ -> OnRouteChange(ActiveSearches)
  }
}

fn get_initial_route() -> Route {
  case modem.initial_uri() {
    Ok(uri) ->
      case uri.path_segments(uri.path) {
        ["create"] -> CreateSearch
        _ -> ActiveSearches
      }
    Error(_) -> ActiveSearches
  }
}

pub fn init(_flags) -> #(Model, Effect(Msg)) {
  let initial_route = get_initial_route()
  let initial_effects = case initial_route {
    ActiveSearches ->
      effect.batch([modem.init(on_url_change), fetch_searches()])
    CreateSearch -> modem.init(on_url_change)
  }
  #(
    Model(route: initial_route, searches: [], form: ui_types.empty_form()),
    initial_effects,
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(ActiveSearches) -> #(
      Model(..model, route: ActiveSearches),
      fetch_searches(),
    )
    OnRouteChange(route) -> #(Model(..model, route: route), effect.none())
    Form(UpdateField(field, value)) -> #(
      Model(..model, form: ui_types.update_field(model.form, field, value)),
      effect.none(),
    )
    Form(Submit) -> #(
      Model(..model, form: ui_types.empty_form()),
      post_search(model.form),
    )
    CreateRequestSubmitted(Ok(_)) -> #(model, fetch_searches())
    CreateRequestSubmitted(Error(_)) -> #(model, effect.none())
    GetSearchesFetched(Ok(searches)) -> #(
      Model(..model, searches: searches),
      effect.none(),
    )
    GetSearchesFetched(Error(_)) -> #(model, effect.none())
  }
}

fn fetch_searches() -> Effect(Msg) {
  rsvp.get(
    "/api/walker",
    rsvp.expect_json(types.searches_decoder(), GetSearchesFetched),
  )
}

fn post_search(form: AppointmentRequest) -> Effect(Msg) {
  let body = types.encode_appointment_request(form)
  rsvp.post(
    "/api/walker",
    body,
    rsvp.expect_json(
      types.post_search_response_decoder(),
      CreateRequestSubmitted,
    ),
  )
}
