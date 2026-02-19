import clients/luxmed_client.{
  type Doctor, type LuxmedClient, type ServiceVariant, type TermForDay,
}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import types/appointment_request.{type AppointmentRequest}

pub type SearchError {
  AuthenticationFailed
  VariantNotFound
  DoctorNotFound
  VisitsNotFound
  Unknown(message: String)
}

pub fn get_error_message(error: SearchError) -> String {
  case error {
    AuthenticationFailed -> "Authentication failed"
    VariantNotFound -> "Variant not found"
    DoctorNotFound -> "Doctor not found"
    VisitsNotFound -> "Visits not found"
    Unknown(message) -> message
  }
}

fn to_search_error(
  err: luxmed_client.LuxmedApiError,
  on_not_found: SearchError,
) -> SearchError {
  case err {
    luxmed_client.NotFound(_) -> on_not_found
    luxmed_client.Unauthorized(_) -> AuthenticationFailed
    luxmed_client.RequestFailed(msg) -> Unknown(msg)
    luxmed_client.ParseError(msg) -> Unknown(msg)
  }
}

fn try_api(
  result: Result(a, luxmed_client.LuxmedApiError),
  on_not_found: SearchError,
  next: fn(a) -> Result(b, SearchError),
) -> Result(b, SearchError) {
  result
  |> result.map_error(to_search_error(_, on_not_found))
  |> result.try(next)
}

fn find_service_variant(
  client: luxmed_client.LuxmedClient,
  request: AppointmentRequest,
) {
  use variant <- try_api(
    luxmed_client.find_service_variant(client, request.service),
    VariantNotFound,
  )

  io.println("Variant found: " <> variant.name)
  Ok(variant)
}

fn find_doctor(
  client: luxmed_client.LuxmedClient,
  variant: luxmed_client.ServiceVariant,
  request: AppointmentRequest,
) {
  use doctor <- try_api(
    luxmed_client.find_doctor(
      client,
      variant.id,
      request.doctor.first_name,
      request.doctor.last_name,
    ),
    DoctorNotFound,
  )

  io.println("Variant found: " <> variant.name)
  Ok(doctor)
}

fn date_to_string(date: calendar.Date) -> String {
  let year = int.to_string(date.year)
  let month =
    calendar.month_to_int(date.month)
    |> int.to_string
    |> string.pad_start(2, "0")
  let day = int.to_string(date.day) |> string.pad_start(2, "0")
  year <> "-" <> month <> "-" <> day
}

fn normalize_string(str: Option(String)) -> String {
  str
  |> option.unwrap("")
  |> string.lowercase
  |> string.trim
}

fn is_same_doctor(term_doctor: Doctor, requested_doctor: Doctor) -> Bool {
  let term_first = normalize_string(term_doctor.first_name)
  let term_last = normalize_string(term_doctor.last_name)
  let requested_first = normalize_string(requested_doctor.first_name)
  let requested_last = normalize_string(requested_doctor.last_name)

  term_first == requested_first && term_last == requested_last
}

fn filter_terms_by_doctor(
  terms_for_day: TermForDay,
  requested_doctor: Doctor,
) -> TermForDay {
  let filtered_terms =
    terms_for_day.terms
    |> list.filter(fn(term) { is_same_doctor(term.doctor, requested_doctor) })
  luxmed_client.TermForDay(filtered_terms)
}

fn filter_and_remove_empty(
  terms_list: List(TermForDay),
  requested_doctor: Doctor,
) -> List(TermForDay) {
  terms_list
  |> list.map(fn(tfd) { filter_terms_by_doctor(tfd, requested_doctor) })
  |> list.filter(fn(tfd) { !list.is_empty(tfd.terms) })
}

fn search_for_visits(
  client: luxmed_client.LuxmedClient,
  variant: luxmed_client.ServiceVariant,
  doctor: luxmed_client.Doctor,
) {
  let now = timestamp.system_time()
  let #(today_date, _) = timestamp.to_calendar(now, calendar.utc_offset)
  let today = date_to_string(today_date)

  let two_weeks_later = timestamp.add(now, duration.hours(14 * 24))
  let #(two_weeks_date, _) =
    timestamp.to_calendar(two_weeks_later, calendar.utc_offset)
  let two_weeks_from_now = date_to_string(two_weeks_date)

  use terms <- try_api(
    luxmed_client.search_for_visits(
      client,
      variant,
      today,
      two_weeks_from_now,
      Some(doctor.id),
    ),
    VisitsNotFound,
  )
  io.println("Terms found: " <> list.length(terms) |> int.to_string)
  Ok(terms)
}

fn create_client(
  request: AppointmentRequest,
) -> Result(luxmed_client.LuxmedClient, SearchError) {
  use client <- result.try(
    luxmed_client.login(request.login, request.password)
    |> result.map_error(fn(_) { AuthenticationFailed }),
  )

  io.println("Logged in to Luxmed")
  Ok(client)
}

pub fn handle_search(
  request: AppointmentRequest,
) -> Result(List(TermForDay), SearchError) {
  use client: LuxmedClient <- result.try(create_client(request))
  use variant: ServiceVariant <- result.try(find_service_variant(
    client,
    request,
  ))
  use doctor: Doctor <- result.try(find_doctor(client, variant, request))
  use terms: List(TermForDay) <- result.try(search_for_visits(
    client,
    variant,
    doctor,
  ))

  let filtered_terms = filter_and_remove_empty(terms, doctor)
  case filtered_terms |> list.length() {
    0 -> Error(VisitsNotFound)
    _ -> Ok(filtered_terms)
  }
}
