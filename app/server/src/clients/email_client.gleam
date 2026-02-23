import gcourier/message
import gcourier/smtp
import gleam/int
import gleam/io
import gleam/option.{Some}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp

pub type EmailConfig {
  EmailConfig(
    smtp_host: String,
    smtp_port: Int,
    username: String,
    password: String,
    from_email: String,
    from_name: String,
  )
}

pub type EmailClient {
  EmailClient(
    send_appointment_found: fn(String, String, String) -> Nil,
    send_error: fn(String, String) -> Nil,
  )
}

pub fn create_client(config: EmailConfig, skip: Bool) -> EmailClient {
  case skip {
    True ->
      EmailClient(
        send_appointment_found: fn(_, _, _) {
          io.println("Email: Skipping appointment found (notifications disabled)")
        },
        send_error: fn(_, _) {
          io.println("Email: Skipping error email (notifications disabled)")
        },
      )
    False ->
      EmailClient(
        send_appointment_found: fn(to, service, doctor) {
          send_appointment_found_email(config, to, service, doctor)
        },
        send_error: fn(to, error_message) {
          send_error_email(config, to, error_message)
        },
      )
  }
}

fn send_appointment_found_email(
  config: EmailConfig,
  to: String,
  service: String,
  doctor: String,
) -> Nil {
  io.println(
    "Sending appointment found email to "
    <> to
    <> " for service "
    <> service
    <> " and doctor "
    <> doctor
    <> " timestamp "
    <> format_current_time(),
  )
  let subject = "Nowe terminy " <> service <> " w Luxmedzie!"
  let body =
    "<html><body><b>Pojawiły się nowe terminy "
    <> service
    <> " w Luxmedzie!</b><p>Terminy dla lekarza "
    <> doctor
    <> "</p></body></html>"

  let email =
    message.build()
    |> message.set_from(config.from_email, Some(config.from_name))
    |> message.add_recipient(to, message.To)
    |> message.set_subject(subject)
    |> message.set_html(body)

  smtp.send(
    config.smtp_host,
    config.smtp_port,
    Some(#(config.username, config.password)),
    email,
  )
}

fn format_current_time() -> String {
  let now = timestamp.system_time()
  let #(date, time) = timestamp.to_calendar(now, calendar.local_offset())
  let month = calendar.month_to_int(date.month)
  pad2(date.year)
  <> "-"
  <> pad2(month)
  <> "-"
  <> pad2(date.day)
  <> " "
  <> pad2(time.hours)
  <> ":"
  <> pad2(time.minutes)
}

fn pad2(value: Int) -> String {
  value |> int.to_string |> string.pad_start(2, "0")
}

fn send_error_email(
  config: EmailConfig,
  to: String,
  error_message: String,
) -> Nil {
  let subject = "Luxwalker Error"
  let body =
    "<html><body><b>Wystąpił błąd:</b><p>"
    <> error_message
    <> "</p></body></html>"

  let email =
    message.build()
    |> message.set_from(config.from_email, Some(config.from_name))
    |> message.add_recipient(to, message.To)
    |> message.set_subject(subject)
    |> message.set_html(body)

  smtp.send(
    config.smtp_host,
    config.smtp_port,
    Some(#(config.username, config.password)),
    email,
  )
}
