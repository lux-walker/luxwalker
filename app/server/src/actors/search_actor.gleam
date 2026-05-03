import actors/notification_actor
import actors/search_registry
import app_context.{type AppContext}
import clients/luxmed_client
import config.{Development, Production}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import handlers/search_handler.{type AppointmentRequest}
import shared/types.{type TermResult, TermResult}

const one_minute_ms = 60_000

const twenty_minutes_ms = 1_200_000

const one_hour_ms = 3_600_000

const two_hours_ms = 7_200_000

pub type Message {
  Init(self: process.Subject(Message))
  Search(reply_with: process.Subject(SearchResult))
  ContinueProcessing
}

pub type SearchResult {
  SearchComplete(result: String)
}

type State {
  State(
    id: String,
    self: process.Subject(Message),
    attempt: Int,
    request: AppointmentRequest,
    context: AppContext,
    notifier: Notifier,
    registry: Registry,
    schedule: fn() -> Int,
  )
}

type Notifier {
  Notifier(on_started: fn() -> Nil, on_appointment_found: fn() -> Nil)
}

fn build_notifier(
  notification: process.Subject(notification_actor.Message),
  request: AppointmentRequest,
) -> Notifier {
  let doctor_name = request.doctor.first_name <> " " <> request.doctor.last_name
  Notifier(
    on_started: fn() {
      notification_actor.send_search_started(
        notification,
        request.service,
        doctor_name,
      )
    },
    on_appointment_found: fn() {
      notification_actor.send_appointment_found(
        notification,
        request.notification_email,
        request.service,
        doctor_name,
      )
    },
  )
}

type Registry {
  Registry(
    register: fn() -> Nil,
    completed: fn(List(TermResult)) -> Nil,
    attempt_failed: fn(Int, String) -> Nil,
  )
}

fn build_registry(
  registry: process.Subject(search_registry.Message),
  id: String,
  request: AppointmentRequest,
) -> Registry {
  Registry(
    register: fn() {
      search_registry.register_search(
        registry,
        id,
        request.service,
        request.doctor,
        request.login,
        request.notification_email,
        request.password,
      )
    },
    completed: fn(terms) {
      search_registry.request_completed(registry, id, terms)
    },
    attempt_failed: fn(attempts, message) {
      search_registry.request_attempt_failed(registry, id, attempts, message)
    },
  )
}

fn production_timeout_ms() -> Int {
  let now = timestamp.system_time()
  let #(_, time) = timestamp.to_calendar(now, calendar.local_offset())
  let hour = time.hours
  let minute = time.minutes

  case hour {
    h if h >= 5 && h < 8 -> twenty_minutes_ms
    h if h >= 23 || h < 5 -> {
      let minutes_until_5am = case h >= 23 {
        True -> { 24 - hour } * 60 - minute + 5 * 60
        False -> { 5 - hour } * 60 - minute
      }
      int.min(two_hours_ms, minutes_until_5am * 60_000)
    }
    _ -> one_hour_ms
  }
}

fn send_continue_after(state: State) {
  let timeout_ms = case state.context.config.environment {
    Development -> one_minute_ms
    Production -> state.schedule()
  }

  process.send_after(state.self, timeout_ms, ContinueProcessing)
}

fn error_to_search_complete(error: search_handler.SearchError) -> SearchResult {
  case error {
    search_handler.AuthenticationFailed -> {
      "Authentication failed"
    }
    search_handler.DoctorNotFound -> {
      "Doctor not found"
    }
    search_handler.VariantNotFound -> {
      "Variant not found"
    }
    search_handler.VisitsNotFound -> {
      "Visits not found"
    }
    search_handler.Unknown(message) -> {
      "Unknown error: " <> message
    }
  }
  |> SearchComplete
}

fn print_search_error(error: search_handler.SearchError, state: State) -> Nil {
  case error {
    search_handler.AuthenticationFailed -> {
      io.println("Actor " <> state.id <> ": Authentication failed")
    }
    search_handler.DoctorNotFound -> {
      io.println("Actor " <> state.id <> ": Doctor not found")
    }
    search_handler.VariantNotFound -> {
      io.println("Actor " <> state.id <> ": Variant not found")
    }
    search_handler.VisitsNotFound -> {
      io.println("Actor " <> state.id <> ": Visits not found")
    }
    search_handler.Unknown(message) -> {
      io.println("Actor " <> state.id <> ": Unknown error: " <> message)
    }
  }
}

pub fn create_and_call(
  context context: AppContext,
  id id: String,
  request request: AppointmentRequest,
  timeout_ms timeout_ms: Int,
) -> Result(SearchResult, process.Subject(Message)) {
  let assert Ok(started) = create_actor(context, id, request)
  let subject = started.data
  let result = try_call(subject, timeout_ms, Search)

  case result {
    Ok(search_result) -> Ok(search_result)
    Error(Nil) -> Error(subject)
  }
}

fn try_call(
  subject: process.Subject(Message),
  timeout_ms: Int,
  make_request: fn(process.Subject(SearchResult)) -> Message,
) -> Result(SearchResult, Nil) {
  let reply_subject = process.new_subject()
  process.send(subject, make_request(reply_subject))
  process.receive(reply_subject, timeout_ms)
}

pub fn create_actor(
  context: AppContext,
  id: String,
  request: AppointmentRequest,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  let initial_state =
    State(
      id: id,
      self: process.new_subject(),
      attempt: 0,
      request: request,
      context: context,
      notifier: build_notifier(context.actors.notification, request),
      registry: build_registry(context.actors.search_registry, id, request),
      schedule: production_timeout_ms,
    )
  let result =
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start

  use started <- result.try(result)
  process.send(started.data, Init(started.data))
  Ok(started)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Init(self) -> state |> init(self)
    Search(reply_subject) -> state |> search(reply_subject)
    ContinueProcessing -> state |> continue_processing()
  }
}

fn init(
  state: State,
  self: process.Subject(Message),
) -> actor.Next(State, Message) {
  io.println("Actor " <> state.id <> ": Initialized")
  search_handler.print_request(state.request)
  state.registry.register()
  io.println("Actor " <> state.id <> ": Registered search")
  state.notifier.on_started()

  actor.continue(State(..state, self: self))
}

fn terms_to_result_list(
  terms: List(luxmed_client.TermForDay),
) -> List(TermResult) {
  terms
  |> list.flat_map(fn(day) { day.terms })
  |> list.map(fn(term) {
    TermResult(
      clinic: term.clinic,
      date_time_from: term.date_time_from,
      date_time_to: term.date_time_to,
      doctor_first_name: option.unwrap(term.doctor.first_name, ""),
      doctor_last_name: option.unwrap(term.doctor.last_name, ""),
    )
  })
}

fn search(
  state: State,
  reply_subject: process.Subject(SearchResult),
) -> actor.Next(State, Message) {
  io.println("Actor " <> state.id <> ": Searching...")

  case search_handler.handle_search(state.request) {
    Ok(terms) -> {
      io.println("Actor " <> state.id <> ": Search complete, stopping actor")
      let term_results = terms_to_result_list(terms)
      state.registry.completed(term_results)
      let count = list.length(term_results) |> int.to_string
      process.send(reply_subject, SearchComplete("Found " <> count <> " terms"))
      actor.stop()
    }
    Error(error) ->
      case error {
        search_handler.VisitsNotFound -> {
          io.println("Visit not found, will retry in the future. Accepted.")
          let new_attempt = state.attempt + 1
          state.registry.attempt_failed(new_attempt, "Visits not found")
          process.send(
            reply_subject,
            SearchComplete("No visits, request scheduled"),
          )
          let new_state = State(..state, attempt: new_attempt)
          send_continue_after(new_state)
          actor.continue(new_state)
        }
        actual_error -> {
          print_search_error(error, state)
          process.send(reply_subject, error_to_search_complete(actual_error))
          actor.stop()
        }
      }
  }
}

fn continue_processing(state: State) -> actor.Next(State, Message) {
  io.println("Actor " <> state.id <> ": Processing again...")
  case search_handler.handle_search(state.request) {
    Ok(terms) -> {
      io.println(
        "Actor " <> state.id <> ": Processing complete, stopping actor",
      )

      state.notifier.on_appointment_found()

      let term_results = terms_to_result_list(terms)
      state.registry.completed(term_results)
      io.println("Actor " <> state.id <> ": Request completed, stopping actor")
      actor.stop()
    }
    Error(error) -> {
      io.println("Actor " <> state.id <> ": Processing failed, will retry")
      let new_attempt = state.attempt + 1
      state.registry.attempt_failed(
        new_attempt,
        search_handler.get_error_message(error),
      )
      send_continue_after(state)
      actor.continue(State(..state, attempt: new_attempt))
    }
  }
}
