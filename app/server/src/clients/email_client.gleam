import gcourier/message
import gcourier/smtp
import gleam/bool
import gleam/erlang/process
import gleam/int
import gleam/option.{Some}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import utils/log.{type Logger}

const smtp_timeout_ms = 30_000

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
    send_term_locked: fn(String, String, String, String, String) -> Nil,
    send_error: fn(String, String) -> Nil,
  )
}

pub fn create_client(config: EmailConfig, skip: Bool) -> EmailClient {
  let logger = log.root([#("component", "email_client")])
  log.info(logger, "email_client_created", [
    #("enabled", bool.to_string(!skip)),
    #("smtp_host", config.smtp_host),
  ])
  case skip {
    True ->
      EmailClient(
        send_appointment_found: fn(_, _, _) {
          log.info(logger, "email_skipped", [
            #("kind", "appointment_found"),
          ])
        },
        send_term_locked: fn(_, _, _, _, _) {
          log.info(logger, "email_skipped", [#("kind", "term_locked")])
        },
        send_error: fn(_, _) {
          log.info(logger, "email_skipped", [#("kind", "error")])
        },
      )
    False ->
      EmailClient(
        send_appointment_found: fn(to, service, doctor) {
          send_appointment_found_email(logger, config, to, service, doctor)
        },
        send_term_locked: fn(to, service, doctor, clinic, date_time) {
          send_term_locked_email(
            logger,
            config,
            to,
            service,
            doctor,
            clinic,
            date_time,
          )
        },
        send_error: fn(to, error_message) {
          send_error_email(logger, config, to, error_message)
        },
      )
  }
}

fn send_appointment_found_email(
  logger: Logger,
  config: EmailConfig,
  to: String,
  service: String,
  doctor: String,
) -> Nil {
  log.info(logger, "email_sending", [
    #("kind", "appointment_found"),
    #("to", to),
    #("service", service),
    #("doctor", doctor),
    #("ts", format_current_time()),
  ])
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

  send_with_timeout(logger, config, email)
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

fn send_term_locked_email(
  logger: Logger,
  config: EmailConfig,
  to: String,
  service: String,
  doctor: String,
  clinic: String,
  date_time: String,
) -> Nil {
  log.info(logger, "email_sending", [
    #("kind", "term_locked"),
    #("to", to),
    #("service", service),
    #("doctor", doctor),
    #("clinic", clinic),
    #("date_time", date_time),
    #("ts", format_current_time()),
  ])
  let subject = "Zarezerwowany termin " <> service <> " w Luxmedzie"
  let body =
    "<html><body><b>Zarezerwowano termin "
    <> service
    <> " w Luxmedzie!</b><p>Lekarz: "
    <> doctor
    <> "<br>Placówka: "
    <> clinic
    <> "<br>Termin: "
    <> date_time
    <> "</p></body></html>"

  let email =
    message.build()
    |> message.set_from(config.from_email, Some(config.from_name))
    |> message.add_recipient(to, message.To)
    |> message.set_subject(subject)
    |> message.set_html(body)

  send_with_timeout(logger, config, email)
}

fn send_error_email(
  logger: Logger,
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

  send_with_timeout(logger, config, email)
}

fn send_with_timeout(
  logger: Logger,
  config: EmailConfig,
  email: message.Message,
) -> Nil {
  let subj = process.new_subject()

  process.spawn_unlinked(fn() {
    smtp.send(
      config.smtp_host,
      config.smtp_port,
      Some(#(config.username, config.password)),
      email,
    )
    process.send(subj, Nil)
  })

  case process.receive(subj, smtp_timeout_ms) {
    Ok(Nil) -> log.info(logger, "email_sent", [])
    Error(Nil) ->
      log.error(logger, "email_timeout", [
        #("timeout_ms", int.to_string(smtp_timeout_ms)),
      ])
  }
}
