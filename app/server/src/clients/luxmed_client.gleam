import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, Some}
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
  Doctor(
    id: Int,
    academic_title: Option(String),
    first_name: Option(String),
    last_name: Option(String),
  )
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

pub type Valuation {
  Valuation(
    payer_id: Int,
    contract_id: Int,
    product_in_contract_id: Int,
    product_id: Int,
    product_element_id: Int,
    require_referral_for_pp: Bool,
    valuation_type: Int,
    price: Float,
    is_referral_required: Bool,
    is_external_referral_allowed: Bool,
  )
}

pub type LockTermResponse {
  LockTermResponse(
    temporary_reservation_id: Int,
    valuations: List(Valuation),
  )
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
  use academic_title <- decode.field(
    "academicTitle",
    decode.optional(decode.string),
  )
  use first_name <- decode.field("firstName", decode.optional(decode.string))
  use last_name <- decode.field("lastName", decode.optional(decode.string))
  decode.success(Doctor(id:, academic_title:, first_name:, last_name:))
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

fn valuation_decoder() -> decode.Decoder(Valuation) {
  use payer_id <- decode.field("payerId", decode.int)
  use contract_id <- decode.field("contractId", decode.int)
  use product_in_contract_id <- decode.field("productInContractId", decode.int)
  use product_id <- decode.field("productId", decode.int)
  use product_element_id <- decode.field("productElementId", decode.int)
  use require_referral_for_pp <- decode.field(
    "requireReferralForPP",
    decode.bool,
  )
  use valuation_type <- decode.field("valuationType", decode.int)
  use price <- decode.field("price", decode.float)
  use is_referral_required <- decode.field("isReferralRequired", decode.bool)
  use is_external_referral_allowed <- decode.field(
    "isExternalReferralAllowed",
    decode.bool,
  )
  decode.success(Valuation(
    payer_id:,
    contract_id:,
    product_in_contract_id:,
    product_id:,
    product_element_id:,
    require_referral_for_pp:,
    valuation_type:,
    price:,
    is_referral_required:,
    is_external_referral_allowed:,
  ))
}

fn lock_term_inner_decoder() -> decode.Decoder(LockTermResponse) {
  use temporary_reservation_id <- decode.field(
    "temporaryReservationId",
    decode.int,
  )
  use valuations <- decode.field("valuations", decode.list(valuation_decoder()))
  decode.success(LockTermResponse(temporary_reservation_id:, valuations:))
}

fn lock_term_response_decoder() -> decode.Decoder(LockTermResponse) {
  use response <- decode.field("value", lock_term_inner_decoder())
  decode.success(response)
}

fn encode_valuation(v: Valuation) -> json.Json {
  json.object([
    #("payerId", json.int(v.payer_id)),
    #("contractId", json.int(v.contract_id)),
    #("productInContractId", json.int(v.product_in_contract_id)),
    #("productId", json.int(v.product_id)),
    #("productElementId", json.int(v.product_element_id)),
    #("requireReferralForPP", json.bool(v.require_referral_for_pp)),
    #("valuationType", json.int(v.valuation_type)),
    #("price", json.float(v.price)),
    #("isReferralRequired", json.bool(v.is_referral_required)),
    #("isExternalReferralAllowed", json.bool(v.is_external_referral_allowed)),
    #("alternativePrice", json.null()),
  ])
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
        True -> {
          Error(Unauthorized("Missing cookies in login response"))
        }
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

  use forgery_response <- result.try(
    httpc.send(forgery_request)
    |> result.map_error(fn(_) { RequestFailed("Forgery token request failed") }),
  )

  let forgery_cookies = extract_cookies(forgery_response)

  use xsrf_cookie <- result.try(
    extract_xsrf_cookie(forgery_cookies)
    |> result.map_error(fn(_) { Unauthorized("Missing XSRF cookie") }),
  )

  use forgery_data <- result.try(
    json.parse(forgery_response.body, forgery_token_decoder())
    |> result.map_error(fn(_) {
      ParseError("Failed to parse forgery token response")
    }),
  )

  let all_cookies = list.append(cookies, [xsrf_cookie])
  Ok(LuxmedClient(
    cookies: all_cookies,
    auth_token: auth_token,
    xsrf_token: forgery_data.token,
  ))
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

fn get(
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

pub fn lock_term(
  client client: LuxmedClient,
  variant variant: ServiceVariant,
  term term: Term,
  correlation_id correlation_id: String,
) -> Result(LockTermResponse, LuxmedApiError) {
  let doctor_obj =
    json.object([
      #("id", json.int(term.doctor.id)),
      #(
        "academicTitle",
        json.string(option.unwrap(term.doctor.academic_title, "")),
      ),
      #("firstName", json.string(option.unwrap(term.doctor.first_name, ""))),
      #("lastName", json.string(option.unwrap(term.doctor.last_name, ""))),
    ])

  let body =
    json.object([
      #("serviceVariantId", json.int(variant.id)),
      #("serviceVariantName", json.string(variant.name)),
      #("facilityId", json.int(term.clinic_id)),
      #("facilityName", json.string(term.clinic)),
      #("roomId", json.int(term.room_id)),
      #("scheduleId", json.int(term.schedule_id)),
      #("date", json.string(term.date_time_from)),
      #("timeFrom", json.string(extract_time(term.date_time_from))),
      #("timeTo", json.string(extract_time(term.date_time_to))),
      #("doctorId", json.int(term.doctor.id)),
      #("doctor", doctor_obj),
      #("isAdditional", json.bool(False)),
      #("isImpediment", json.bool(False)),
      #("impedimentText", json.string("")),
      #("isPreparationRequired", json.bool(False)),
      #("preparationItems", json.preprocessed_array([])),
      #("referralId", json.null()),
      #("eReferralId", json.null()),
      #("referralTypeId", json.null()),
      #("parentReservationId", json.null()),
      #("correlationId", json.string(correlation_id)),
      #("isTelemedicine", json.bool(False)),
      #("isPoz", json.bool(False)),
      #("isRehabilitation", json.bool(False)),
      #("isOnWhiteList", json.bool(False)),
      #("rehabilitationTermContext", json.null()),
      #("isVideoConsultation", json.bool(False)),
    ])
    |> json.to_string

  use resp <- result.try(post_json(
    client,
    "/PatientPortal/NewPortal/Reservation/LockTerm",
    body,
  ))
  case resp.status {
    s if s >= 200 && s < 300 ->
      json.parse(resp.body, lock_term_response_decoder())
      |> result.map_error(fn(_) {
        ParseError("Failed to parse LockTerm response: " <> resp.body)
      })
    s ->
      Error(RequestFailed(
        "LockTerm returned " <> int.to_string(s) <> ": " <> resp.body,
      ))
  }
}

pub fn confirm_reservation(
  client client: LuxmedClient,
  variant variant: ServiceVariant,
  term term: Term,
  lock_response lock_response: LockTermResponse,
) -> Result(Response(String), LuxmedApiError) {
  use valuation <- result.try(
    list.first(lock_response.valuations)
    |> result.replace_error(NotFound("Valuation in LockTerm response")),
  )

  let body =
    json.object([
      #("serviceVariantId", json.int(variant.id)),
      #("doctorId", json.int(term.doctor.id)),
      #("facilityId", json.int(term.clinic_id)),
      #("roomId", json.int(term.room_id)),
      #(
        "temporaryReservationId",
        json.int(lock_response.temporary_reservation_id),
      ),
      #("referralId", json.null()),
      #("eReferralId", json.null()),
      #("date", json.string(term.date_time_from)),
      #("timeFrom", json.string(extract_time(term.date_time_from))),
      #("parentReservationId", json.null()),
      #("referralRequired", json.bool(valuation.require_referral_for_pp)),
      #("valuationId", json.null()),
      #("scheduleId", json.int(term.schedule_id)),
      #("valuation", encode_valuation(valuation)),
    ])
    |> json.to_string

  post_json(client, "/PatientPortal/NewPortal/Reservation/Confirm", body)
}

fn extract_time(iso: String) -> String {
  case string.split(iso, "T") {
    [_, rest] -> string.slice(rest, 0, 5)
    _ -> ""
  }
}
