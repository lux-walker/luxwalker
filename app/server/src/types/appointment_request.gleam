import gleam/io
import shared/types.{type AppointmentRequest}

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
