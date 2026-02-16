import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri

const base_url = "portalpacjenta.luxmed.pl"

pub type LuxmedClient {
  LuxmedClient(cookies: List(String), auth_token: String, xsrf_token: String)
}

pub type LuxmedApiError {
  RequestFailed(message: String)
  ParseError(message: String)
  NotFound(resource: String)
  Unauthorized(message: String)
}

pub type LoginResponse {
  LoginResponse(token: String)
}

pub type ForgeryTokenResponse {
  ForgeryTokenResponse(token: String)
}

pub type ServiceVariant {
  ServiceVariant(id: Int, name: String)
}

pub type ServiceVariantGroup {
  ServiceVariantGroup(children: List(ServiceVariant))
}

pub type Doctor {
  Doctor(id: Int, first_name: Option(String), last_name: Option(String))
}

pub type DoctorRoot {
  DoctorRoot(doctors: List(Doctor))
}

pub type Term {
  Term(
    clinic_id: Int,
    clinic: String,
    room_id: Int,
    schedule_id: Int,
    date_time_from: String,
    date_time_to: String,
    doctor: Doctor,
  )
}

pub type TermForDay {
  TermForDay(terms: List(Term))
}

pub type TermsForService {
  TermsForService(terms_for_days: List(TermForDay))
}

pub type SearchVisitRoot {
  SearchVisitRoot(terms_for_service: TermsForService)
}

fn login_decoder() -> decode.Decoder(LoginResponse) {
  use token <- decode.field("token", decode.string)
  decode.success(LoginResponse(token:))
}

fn forgery_token_decoder() -> decode.Decoder(ForgeryTokenResponse) {
  use token <- decode.field("token", decode.string)
  decode.success(ForgeryTokenResponse(token:))
}

fn service_variant_decoder() -> decode.Decoder(ServiceVariant) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(ServiceVariant(id:, name:))
}

fn service_variant_group_decoder() -> decode.Decoder(ServiceVariantGroup) {
  use children <- decode.field(
    "children",
    decode.list(service_variant_decoder()),
  )
  decode.success(ServiceVariantGroup(children:))
}

fn doctor_decoder() -> decode.Decoder(Doctor) {
  use id <- decode.field("id", decode.int)
  use first_name <- decode.field("firstName", decode.optional(decode.string))
  use last_name <- decode.field("lastName", decode.optional(decode.string))
  decode.success(Doctor(id:, first_name:, last_name:))
}

fn doctor_root_decoder() -> decode.Decoder(DoctorRoot) {
  use doctors <- decode.field("doctors", decode.list(doctor_decoder()))
  decode.success(DoctorRoot(doctors:))
}

fn term_decoder() -> decode.Decoder(Term) {
  use clinic_id <- decode.field("clinicId", decode.int)
  use clinic <- decode.field("clinic", decode.string)
  use room_id <- decode.field("roomId", decode.int)
  use schedule_id <- decode.field("scheduleId", decode.int)
  use date_time_from <- decode.field("dateTimeFrom", decode.string)
  use date_time_to <- decode.field("dateTimeTo", decode.string)
  use doctor <- decode.field("doctor", doctor_decoder())
  decode.success(Term(
    clinic_id:,
    clinic:,
    room_id:,
    schedule_id:,
    date_time_from:,
    date_time_to:,
    doctor:,
  ))
}

fn term_for_day_decoder() -> decode.Decoder(TermForDay) {
  use terms <- decode.field("terms", decode.list(term_decoder()))
  decode.success(TermForDay(terms:))
}

fn terms_for_service_decoder() -> decode.Decoder(TermsForService) {
  use terms_for_days <- decode.field(
    "termsForDays",
    decode.list(term_for_day_decoder()),
  )
  decode.success(TermsForService(terms_for_days:))
}

fn search_visit_root_decoder() -> decode.Decoder(SearchVisitRoot) {
  use terms_for_service <- decode.field(
    "termsForService",
    terms_for_service_decoder(),
  )
  decode.success(SearchVisitRoot(terms_for_service:))
}

fn extract_cookies(resp: Response(String)) -> List(String) {
  resp.headers
  |> list.filter_map(fn(header) {
    case header.0 {
      "set-cookie" -> Ok(header.1)
      _ -> Error(Nil)
    }
  })
}

fn extract_xsrf_cookie(cookies: List(String)) -> Result(String, Nil) {
  cookies
  |> list.find_map(fn(cookie) {
    case string.contains(cookie, "XSRF-TOKEN") {
      True -> {
        cookie
        |> string.split(";")
        |> list.find_map(fn(part) {
          case string.contains(part, "XSRF-TOKEN") {
            True -> Ok(string.trim(part))
            False -> Error(Nil)
          }
        })
      }
      False -> Error(Nil)
    }
  })
}

fn build_cookie_header(cookies: List(String)) -> String {
  cookies
  |> list.map(fn(cookie) {
    cookie
    |> string.split(";")
    |> list.first
    |> result.unwrap("")
  })
  |> string.join("; ")
}

pub fn login(
  username: String,
  password: String,
) -> Result(LuxmedClient, LuxmedApiError) {
  let login_body =
    json.object([
      #("login", json.string(username)),
      #("password", json.string(password)),
    ])
    |> json.to_string

  let login_request =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> request.set_host(base_url)
    |> request.set_path("/PatientPortal/Account/LogIn")
    |> request.set_header("content-type", "application/json")
    |> request.set_header("accept", "application/json")
    |> request.set_body(login_body)

  let login_result = httpc.send(login_request)

  case login_result {
    Error(_) -> Error(RequestFailed("Login request failed"))
    Ok(login_response) -> {
      let cookies = extract_cookies(login_response)
      case list.is_empty(cookies) {
        True -> Error(Unauthorized("Missing cookies in login response"))
        False -> {
          case json.parse(login_response.body, login_decoder()) {
            Error(_) -> Error(ParseError("Failed to parse login response"))
            Ok(login_data) -> {
              get_forgery_token(cookies, login_data.token)
            }
          }
        }
      }
    }
  }
}

fn get_forgery_token(
  cookies: List(String),
  auth_token: String,
) -> Result(LuxmedClient, LuxmedApiError) {
  let cookie_header = build_cookie_header(cookies)

  let forgery_request =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_scheme(http.Https)
    |> request.set_host(base_url)
    |> request.set_path("/PatientPortal/NewPortal/security/getforgerytoken")
    |> request.set_header("accept", "application/json")
    |> request.set_header("cookie", cookie_header)
    |> request.set_header("authorization-token", "Bearer " <> auth_token)
    |> request.set_header("authorization", "Bearer " <> auth_token)

  case httpc.send(forgery_request) {
    Error(_) -> Error(RequestFailed("Forgery token request failed"))
    Ok(forgery_response) -> {
      let forgery_cookies = extract_cookies(forgery_response)
      case extract_xsrf_cookie(forgery_cookies) {
        Error(_) -> Error(Unauthorized("Missing XSRF cookie"))
        Ok(xsrf_cookie) -> {
          case json.parse(forgery_response.body, forgery_token_decoder()) {
            Error(_) ->
              Error(ParseError("Failed to parse forgery token response"))
            Ok(forgery_data) -> {
              let all_cookies = list.append(cookies, [xsrf_cookie])
              Ok(LuxmedClient(
                cookies: all_cookies,
                auth_token: auth_token,
                xsrf_token: forgery_data.token,
              ))
            }
          }
        }
      }
    }
  }
}

pub fn prepare_request(
  client: LuxmedClient,
  method: http.Method,
  path: String,
) -> request.Request(String) {
  let cookie_header = build_cookie_header(client.cookies)

  request.new()
  |> request.set_method(method)
  |> request.set_scheme(http.Https)
  |> request.set_host(base_url)
  |> request.set_path(path)
  |> request.set_header("accept", "application/json")
  |> request.set_header("cookie", cookie_header)
  |> request.set_header("authorization-token", "Bearer " <> client.auth_token)
  |> request.set_header("authorization", "Bearer " <> client.auth_token)
  |> request.set_header("xsrf-token", client.xsrf_token)
  |> request.set_body("")
}

pub fn get(
  client: LuxmedClient,
  path: String,
) -> Result(Response(String), LuxmedApiError) {
  let req = prepare_request(client, http.Get, path)
  case httpc.send(req) {
    Ok(resp) -> Ok(resp)
    Error(_) -> Error(RequestFailed("GET " <> path))
  }
}

pub fn post_json(
  client: LuxmedClient,
  path: String,
  body: String,
) -> Result(Response(String), LuxmedApiError) {
  let req =
    prepare_request(client, http.Post, path)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)
  case httpc.send(req) {
    Ok(resp) -> Ok(resp)
    Error(_) -> Error(RequestFailed("POST " <> path))
  }
}

pub fn find_service_variant(
  client: LuxmedClient,
  examination: String,
) -> Result(ServiceVariant, LuxmedApiError) {
  let path = "/PatientPortal/NewPortal/Dictionary/serviceVariantsGroups"
  let lower_examination = string.lowercase(examination)

  case get(client, path) {
    Error(err) -> Error(err)
    Ok(response) -> {
      let groups_decoder = decode.list(service_variant_group_decoder())
      case json.parse(response.body, groups_decoder) {
        Error(_) -> Error(ParseError("Failed to parse service variants"))
        Ok(groups) -> {
          let all_variants =
            groups
            |> list.flat_map(fn(group) { group.children })

          case
            list.find(all_variants, fn(variant) {
              string.lowercase(variant.name) == lower_examination
            })
          {
            Ok(variant) -> Ok(variant)
            Error(_) -> Error(NotFound("Service variant: " <> examination))
          }
        }
      }
    }
  }
}

pub fn find_doctor(
  client: LuxmedClient,
  variant_id: Int,
  first_name: String,
  last_name: String,
) -> Result(Doctor, LuxmedApiError) {
  let path =
    "/PatientPortal/NewPortal/Dictionary/facilitiesAndDoctors?cityId=3&serviceVariantId="
    <> int.to_string(variant_id)
  let lower_first = string.lowercase(first_name)
  let lower_last = string.lowercase(last_name)

  use response <- result.try(get(client, path))

  case json.parse(response.body, doctor_root_decoder()) {
    Error(_) -> Error(ParseError("Failed to parse doctors response"))
    Ok(root) -> {
      case
        list.find(root.doctors, fn(doc) {
          case doc.first_name, doc.last_name {
            Some(doc_first), Some(doc_last) ->
              string.lowercase(doc_first) == lower_first
              && string.lowercase(doc_last) == lower_last
            _, _ -> False
          }
        })
      {
        Ok(doctor) -> Ok(doctor)
        Error(_) ->
          Error(NotFound("Doctor: " <> first_name <> " " <> last_name))
      }
    }
  }
}

fn search_for_visits_in_range(
  client: LuxmedClient,
  variant: ServiceVariant,
  date_from: String,
  date_to: String,
  doctor_id: Option(Int),
) -> Result(List(TermForDay), LuxmedApiError) {
  use doctor_id <- result.try(option.to_result(
    doctor_id,
    NotFound("Doctor id not provided. Doctor not found?"),
  ))

  let query =
    "searchPlace.id=3"
    <> "&searchPlace.name="
    <> uri.percent_encode("Kraków")
    <> "&searchPlace.type=0"
    <> "&serviceVariantId="
    <> int.to_string(variant.id)
    <> "&searchDateFrom="
    <> date_from
    <> "&searchDateTo="
    <> date_to
    <> "&doctorsIds="
    <> int.to_string(doctor_id)
    <> "&delocalized=false"
    <> "&languageId=10"
    <> "&processId=0d19dadb-ac9f-4d80-ad72-14d4c30d285f"

  let path = "/PatientPortal/NewPortal/terms/index?" <> query
  use response <- result.try(get(client, path))
  case json.parse(response.body, search_visit_root_decoder()) {
    Error(_) -> Error(ParseError("Failed to parse visits response"))
    Ok(root) -> {
      let terms_for_days = root.terms_for_service.terms_for_days
      let filtered =
        terms_for_days
        |> list.filter(fn(day) {
          list.any(day.terms, fn(term) { term.doctor.id == doctor_id })
        })

      Ok(filtered)
    }
  }
}

pub fn search_for_visits(
  client client: LuxmedClient,
  variant variant: ServiceVariant,
  date_from date_from: String,
  date_to date_to: String,
  doctor_id doctor_id: Option(Int),
) -> Result(List(TermForDay), LuxmedApiError) {
  search_for_visits_in_range(client, variant, date_from, date_to, doctor_id)
}
