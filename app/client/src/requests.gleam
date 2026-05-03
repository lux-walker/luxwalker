import gleam/http
import gleam/http/request
import gleam/json
import lustre/effect.{type Effect}
import rsvp
import shared/types.{type CreateAppointmentRequest}
import ui_types.{type Msg, OnHttpRequest}

fn send_relative(
  path: String,
  configure: fn(request.Request(String)) -> request.Request(String),
  handler: rsvp.Handler(Msg),
) -> Effect(Msg) {
  case rsvp.parse_relative_uri(path) {
    Error(_) -> effect.none()
    Ok(uri) ->
      case request.from_uri(uri) {
        Error(_) -> effect.none()
        Ok(req) -> req |> configure |> rsvp.send(handler)
      }
  }
}

pub fn fetch_config() -> Effect(Msg) {
  send_relative(
    "/api/config",
    fn(r) { r },
    rsvp.expect_json(types.app_settings_decoder(), fn(result) {
      OnHttpRequest(ui_types.ConfigFetched(result))
    }),
  )
}

pub fn fetch_searches(user_email: String) -> Effect(Msg) {
  send_relative(
    "/api/walker",
    fn(r) { request.set_header(r, "x-user-email", user_email) },
    rsvp.expect_json(types.searches_decoder(), fn(result) {
      OnHttpRequest(ui_types.SearchesFetched(result))
    }),
  )
}

pub fn rerun_search(id: String, user_email: String) -> Effect(Msg) {
  send_relative(
    "/api/walker/" <> id <> "/rerun",
    fn(r) {
      r
      |> request.set_method(http.Post)
      |> request.set_header("x-user-email", user_email)
    },
    rsvp.expect_json(types.post_search_response_decoder(), fn(result) {
      OnHttpRequest(ui_types.SearchRerun(result))
    }),
  )
}

pub fn post_search(
  form: CreateAppointmentRequest,
  user_email: String,
) -> Effect(Msg) {
  let body = types.encode_create_appointment_request(form)
  send_relative(
    "/api/walker",
    fn(r) {
      r
      |> request.set_method(http.Post)
      |> request.set_header("x-user-email", user_email)
      |> request.set_header("content-type", "application/json")
      |> request.set_body(json.to_string(body))
    },
    rsvp.expect_json(types.post_search_response_decoder(), fn(result) {
      OnHttpRequest(ui_types.SearchRequestSubmitted(result))
    }),
  )
}
