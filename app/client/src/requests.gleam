import gleam/http
import gleam/http/request
import gleam/json
import lustre/effect.{type Effect}
import rsvp
import shared/types.{type CreateAppointmentRequest}
import ui_types.{type Msg, OnHttpRequest}

fn api_request(user_email: String) -> request.Request(String) {
  request.new()
  |> request.set_path("/api/walker")
  |> request.set_header("x-user-email", user_email)
}

pub fn fetch_searches(user_email: String) -> Effect(Msg) {
  api_request(user_email)
  |> rsvp.send(
    rsvp.expect_json(types.searches_decoder(), fn(result) {
      OnHttpRequest(ui_types.SearchesFetched(result))
    }),
  )
}

pub fn post_search(
  form: CreateAppointmentRequest,
  user_email: String,
) -> Effect(Msg) {
  let body = types.encode_create_appointment_request(form)
  api_request(user_email)
  |> request.set_method(http.Post)
  |> request.set_header("content-type", "application/json")
  |> request.set_body(json.to_string(body))
  |> rsvp.send(
    rsvp.expect_json(types.post_search_response_decoder(), fn(result) {
      OnHttpRequest(ui_types.SearchRequestSubmitted(result))
    }),
  )
}
