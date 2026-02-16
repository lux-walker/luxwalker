import gcourier/message
import gcourier/smtp
import gleam/option.{Some}

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

pub type EmailError {
  SendFailed(message: String)
}

pub fn send_test_email(config: EmailConfig, to: String) -> Nil {
  let subject = "Luxwalker Test Email"
  let body =
    "<html><body><h1>Test Email from Luxwalker</h1><p>This is a test email sent from the Gleam application.</p></body></html>"

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

pub fn send_appointment_found_email(
  config: EmailConfig,
  to: String,
  service: String,
  doctor: String,
) -> Nil {
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

pub fn send_error_email(
  config: EmailConfig,
  to: String,
  error_message: String,
) -> Nil {
  let subject = "Luxwalker Error"
  let body =
    "<html><body><b>Wystąpił błąd:</b><p>" <> error_message <> "</p></body></html>"

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
