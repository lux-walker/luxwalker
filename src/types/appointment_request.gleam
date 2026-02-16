import gleam/dynamic/decode
import gleam/io

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

fn doctor_decoder() -> decode.Decoder(Doctor) {
  use first_name <- decode.field("firstName", decode.string)
  use last_name <- decode.field("lastName", decode.string)
  decode.success(Doctor(first_name:, last_name:))
}

pub fn decoder() -> decode.Decoder(AppointmentRequest) {
  use login <- decode.field("login", decode.string)
  use password <- decode.field("password", decode.string)
  use service <- decode.field("service", decode.string)
  use doctor <- decode.field("doctor", doctor_decoder())
  use notification_email <- decode.field("notificationEmail", decode.string)
  decode.success(AppointmentRequest(
    login:,
    password:,
    service:,
    doctor:,
    notification_email:,
  ))
}

pub fn print(request: AppointmentRequest) -> Nil {
  io.println("=== Appointment Request ===")
  io.println("Login: " <> request.login)
  io.println("Password: *****")
  io.println("Service: " <> request.service)
  io.println(
    "Doctor: " <> request.doctor.first_name <> " " <> request.doctor.last_name,
  )
  io.println("Email: " <> request.notification_email)
  io.println("===========================")
}
