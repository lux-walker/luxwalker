import clients/email_client
import clients/ntfy_client
import config.{type AppConfig}
import gleam/erlang/process
import gleam/otp/actor

pub type Message {
  SearchStarted(service: String, doctor_name: String)
  AppointmentFound(
    notification_email: String,
    service: String,
    doctor_name: String,
  )
  TermLocked(
    notification_email: String,
    service: String,
    doctor_name: String,
    clinic: String,
    date_time: String,
  )
}

pub type State {
  State(email: email_client.EmailClient, ntfy: ntfy_client.NtfyClient)
}

pub fn start(
  config: AppConfig,
) -> Result(process.Subject(Message), actor.StartError) {
  let initial_state =
    State(
      email: email_client.create_client(config.email, config.skip_notifications),
      ntfy: ntfy_client.create_client(
        config.ntfy_topic,
        config.skip_notifications,
      ),
    )

  let result =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start

  case result {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn send_search_started(
  notifier: process.Subject(Message),
  service: String,
  doctor_name: String,
) -> Nil {
  notifier |> process.send(SearchStarted(service, doctor_name))
}

pub fn send_appointment_found(
  notifier: process.Subject(Message),
  notification_email: String,
  service: String,
  doctor_name: String,
) -> Nil {
  notifier
  |> process.send(AppointmentFound(notification_email, service, doctor_name))
}

pub fn send_term_locked(
  notifier: process.Subject(Message),
  notification_email: String,
  service: String,
  doctor_name: String,
  clinic: String,
  date_time: String,
) -> Nil {
  notifier
  |> process.send(TermLocked(
    notification_email,
    service,
    doctor_name,
    clinic,
    date_time,
  ))
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    SearchStarted(service, doctor_name) -> {
      state.ntfy.send_search_started(service, doctor_name)
      actor.continue(state)
    }
    AppointmentFound(notification_email, service, doctor_name) -> {
      state.ntfy.send_appointment_found(service, doctor_name)
      state.email.send_appointment_found(
        notification_email,
        service,
        doctor_name,
      )
      actor.continue(state)
    }
    TermLocked(notification_email, service, doctor_name, clinic, date_time) -> {
      state.ntfy.send_term_locked(service, doctor_name, clinic, date_time)
      state.email.send_term_locked(
        notification_email,
        service,
        doctor_name,
        clinic,
        date_time,
      )
      actor.continue(state)
    }
  }
}
