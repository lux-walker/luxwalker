import gleam/dynamic/decode
import gleam/json

pub type Doctor {
  Doctor(first_name: String, last_name: String)
}

pub type CreateAppointmentRequest {
  CreateAppointmentRequest(
    password: String,
    service: String,
    doctor: Doctor,
    notification_email: String,
  )
}

pub fn encode_create_appointment_request(
  request: CreateAppointmentRequest,
) -> json.Json {
  json.object([
    #("password", json.string(request.password)),
    #("service", json.string(request.service)),
    #(
      "doctor",
      json.object([
        #("firstName", json.string(request.doctor.first_name)),
        #("lastName", json.string(request.doctor.last_name)),
      ]),
    ),
    #("notificationEmail", json.string(request.notification_email)),
  ])
}

pub fn create_appointment_request_decoder() -> decode.Decoder(
  CreateAppointmentRequest,
) {
  use password <- decode.field("password", decode.string)
  use service <- decode.field("service", decode.string)
  use doctor <- decode.field("doctor", {
    use first_name <- decode.field("firstName", decode.string)
    use last_name <- decode.field("lastName", decode.string)
    decode.success(Doctor(first_name:, last_name:))
  })
  use notification_email <- decode.field("notificationEmail", decode.string)
  decode.success(CreateAppointmentRequest(
    password:,
    service:,
    doctor:,
    notification_email:,
  ))
}

pub type AppSettings {
  AppSettings(environment: String, skip_notifications: Bool)
}

pub fn app_settings_decoder() -> decode.Decoder(AppSettings) {
  use environment <- decode.field("environment", decode.string)
  use skip_notifications <- decode.field("skipNotifications", decode.bool)
  decode.success(AppSettings(environment:, skip_notifications:))
}

pub type TermResult {
  TermResult(
    clinic: String,
    date_time_from: String,
    date_time_to: String,
    doctor_first_name: String,
    doctor_last_name: String,
  )
}

pub type SearchStatusDisplay {
  NoResult
  Processing(attempts: Int, last_message: String)
  Completed(terms: List(TermResult))
}

pub type SearchSummary {
  SearchSummary(
    id: String,
    service: String,
    doctor_first_name: String,
    doctor_last_name: String,
    status: SearchStatusDisplay,
    timestamp: String,
  )
}

// -- JSON Encoders --

pub fn encode_term_result(term: TermResult) -> json.Json {
  json.object([
    #("clinic", json.string(term.clinic)),
    #("dateTimeFrom", json.string(term.date_time_from)),
    #("dateTimeTo", json.string(term.date_time_to)),
    #("doctorFirstName", json.string(term.doctor_first_name)),
    #("doctorLastName", json.string(term.doctor_last_name)),
  ])
}

pub fn encode_search_status(status: SearchStatusDisplay) -> json.Json {
  case status {
    NoResult -> json.object([#("status", json.string("no_result"))])
    Processing(attempts, last_message) ->
      json.object([
        #("status", json.string("processing")),
        #("attempts", json.int(attempts)),
        #("last_message", json.string(last_message)),
      ])
    Completed(terms) ->
      json.object([
        #("status", json.string("completed")),
        #("terms", json.array(terms, encode_term_result)),
      ])
  }
}

pub fn encode_search_summary(summary: SearchSummary) -> json.Json {
  json.object([
    #("id", json.string(summary.id)),
    #("service", json.string(summary.service)),
    #(
      "doctor",
      json.object([
        #("firstName", json.string(summary.doctor_first_name)),
        #("lastName", json.string(summary.doctor_last_name)),
      ]),
    ),
    #("status", encode_search_status(summary.status)),
    #("timestamp", json.string(summary.timestamp)),
  ])
}

// -- JSON Decoders --

fn term_result_decoder() -> decode.Decoder(TermResult) {
  use clinic <- decode.field("clinic", decode.string)
  use date_time_from <- decode.field("dateTimeFrom", decode.string)
  use date_time_to <- decode.field("dateTimeTo", decode.string)
  use doctor_first_name <- decode.field("doctorFirstName", decode.string)
  use doctor_last_name <- decode.field("doctorLastName", decode.string)
  decode.success(TermResult(
    clinic:,
    date_time_from:,
    date_time_to:,
    doctor_first_name:,
    doctor_last_name:,
  ))
}

fn search_status_decoder() -> decode.Decoder(SearchStatusDisplay) {
  use status_type <- decode.field("status", decode.string)
  case status_type {
    "no_result" -> decode.success(NoResult)
    "processing" -> {
      use attempts <- decode.field("attempts", decode.int)
      use last_message <- decode.field("last_message", decode.string)
      decode.success(Processing(attempts, last_message))
    }
    "completed" -> {
      use terms <- decode.field("terms", decode.list(term_result_decoder()))
      decode.success(Completed(terms))
    }
    _ -> decode.success(NoResult)
  }
}

pub fn search_summary_decoder() -> decode.Decoder(SearchSummary) {
  use id <- decode.field("id", decode.string)
  use service <- decode.field("service", decode.string)
  use #(doctor_first_name, doctor_last_name) <- decode.field("doctor", {
    use first <- decode.field("firstName", decode.string)
    use last <- decode.field("lastName", decode.string)
    decode.success(#(first, last))
  })
  use status <- decode.field("status", search_status_decoder())
  use timestamp <- decode.field("timestamp", decode.string)
  decode.success(SearchSummary(
    id:,
    service:,
    doctor_first_name:,
    doctor_last_name:,
    status:,
    timestamp:,
  ))
}

pub fn searches_decoder() -> decode.Decoder(List(SearchSummary)) {
  use searches <- decode.field(
    "searches",
    decode.list(search_summary_decoder()),
  )
  decode.success(searches)
}

pub fn post_search_response_decoder() -> decode.Decoder(String) {
  use status <- decode.field("status", decode.string)
  decode.success(status)
}

pub type CreateAppointmentResponseStatus {
  ResponseCompleted
  ResponseProcessing
}

pub type CreateAppointmentResponse {
  CreateAppointmentResponse(
    status: CreateAppointmentResponseStatus,
    id: String,
    message: String,
  )
}

pub fn encode_create_appointment_response(
  response: CreateAppointmentResponse,
) -> json.Json {
  let status = case response.status {
    ResponseCompleted -> "completed"
    ResponseProcessing -> "processing"
  }
  json.object([
    #("status", json.string(status)),
    #("id", json.string(response.id)),
    #("message", json.string(response.message)),
  ])
}

pub fn create_appointment_response_decoder() -> decode.Decoder(
  CreateAppointmentResponse,
) {
  use status <- decode.field("status", decode.string)
  use id <- decode.field("id", decode.string)
  use message <- decode.field("message", decode.string)
  let parsed_status = case status {
    "completed" -> ResponseCompleted
    _ -> ResponseProcessing
  }
  decode.success(CreateAppointmentResponse(
    status: parsed_status,
    id:,
    message:,
  ))
}
