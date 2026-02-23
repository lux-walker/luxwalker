import gleam/dynamic/decode
import gleam/json

pub type Doctor {
  Doctor(first_name: String, last_name: String)
}

pub type AppointmentRequest {
  AppointmentRequest(
    login: String,
    password: String,
    service: String,
    doctor: Doctor,
    notification_email: String,
  )
}

pub fn encode_appointment_request(request: AppointmentRequest) -> json.Json {
  json.object([
    #("login", json.string(request.login)),
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

pub fn appointment_request_decoder() -> decode.Decoder(AppointmentRequest) {
  use login <- decode.field("login", decode.string)
  use password <- decode.field("password", decode.string)
  use service <- decode.field("service", decode.string)
  use doctor <- decode.field("doctor", {
    use first_name <- decode.field("firstName", decode.string)
    use last_name <- decode.field("lastName", decode.string)
    decode.success(Doctor(first_name:, last_name:))
  })
  use notification_email <- decode.field("notificationEmail", decode.string)
  decode.success(AppointmentRequest(
    login:,
    password:,
    service:,
    doctor:,
    notification_email:,
  ))
}

pub type SearchStatusDisplay {
  NoResult
  Processing(attempts: Int, last_message: String)
  Completed(result: String)
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

pub fn encode_search_status(status: SearchStatusDisplay) -> json.Json {
  case status {
    NoResult -> json.object([#("status", json.string("no_result"))])
    Processing(attempts, last_message) ->
      json.object([
        #("status", json.string("processing")),
        #("attempts", json.int(attempts)),
        #("last_message", json.string(last_message)),
      ])
    Completed(result) ->
      json.object([
        #("status", json.string("completed")),
        #("result", json.string(result)),
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
      use result <- decode.field("result", decode.string)
      decode.success(Completed(result))
    }
    _ -> decode.success(NoResult)
  }
}

pub fn search_summary_decoder() -> decode.Decoder(SearchSummary) {
  use id <- decode.field("id", decode.string)
  use service <- decode.field("service", decode.string)
  use #(doctor_first_name, doctor_last_name) <- decode.field(
    "doctor",
    {
      use first <- decode.field("firstName", decode.string)
      use last <- decode.field("lastName", decode.string)
      decode.success(#(first, last))
    },
  )
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
