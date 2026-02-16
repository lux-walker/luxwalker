import actors/search_registry
import clients/email_client
import clients/luxmed_client
import config.{type AppConfig}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import handlers/search_handler
import types/appointment_request.{type AppointmentRequest}

const one_minute_ms = 60_000

pub type Message {
  Init(self: process.Subject(Message))
  Search(reply_with: process.Subject(SearchResult))
  ContinueProcessing
}

pub type SearchResult {
  SearchComplete(result: String)
}

pub type State {
  State(
    id: String,
    self: process.Subject(Message),
    attempt: Int,
    request: AppointmentRequest,
    registry: process.Subject(search_registry.Message),
    config: AppConfig,
  )
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
  registry: process.Subject(search_registry.Message),
  id: String,
  request: AppointmentRequest,
  config: AppConfig,
  timeout_ms: Int,
) -> Result(SearchResult, process.Subject(Message)) {
  let assert Ok(started) = create_actor(registry, id, request, config)
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
  registry: process.Subject(search_registry.Message),
  id: String,
  request: AppointmentRequest,
  config: AppConfig,
) -> Result(actor.Started(process.Subject(Message)), actor.StartError) {
  let initial_state =
    State(
      id: id,
      self: process.new_subject(),
      attempt: 0,
      request: request,
      registry: registry,
      config: config,
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
  appointment_request.print(state.request)
  search_registry.register_search(state.registry, state.id)
  io.println("Actor " <> state.id <> ": Registered search")
  actor.continue(State(..state, self: self))
}

fn terms_to_string(
  terms: List(luxmed_client.TermForDay),
  state: State,
) -> String {
  "Results for "
  <> state.id
  <> " found "
  <> list.length(terms) |> int.to_string
  <> " terms"
}

fn search(
  state: State,
  reply_subject: process.Subject(SearchResult),
) -> actor.Next(State, Message) {
  io.println("Actor " <> state.id <> ": Searching...")
  case search_handler.handle_search(state.request) {
    Ok(terms) -> {
      io.println("Actor " <> state.id <> ": Search complete, stopping actor")
      let result = terms |> terms_to_string(state)
      search_registry.update_result(state.registry, state.id, result)
      process.send(reply_subject, SearchComplete(result))
      actor.stop()
    }
    Error(error) ->
      case error {
        search_handler.VisitsNotFound -> {
          io.println("Visit not found, will retry in the future. Accepted.")
          process.send(reply_subject, SearchComplete("Error: " <> state.id))
          process.send_after(state.self, one_minute_ms, ContinueProcessing)
          actor.continue(State(..state, attempt: state.attempt + 1))
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
    Ok(_) -> {
      io.println(
        "Actor " <> state.id <> ": Processing complete, stopping actor",
      )
      let result = "Results for " <> state.id
      search_registry.update_result(state.registry, state.id, result)
      email_client.send_appointment_found_email(
        state.config.email,
        state.request.notification_email,
        state.request.service,
        state.request.doctor.first_name <> " " <> state.request.doctor.last_name,
      )
      actor.stop()
    }
    Error(_) -> {
      io.println("Actor " <> state.id <> ": Processing failed, will retry")
      process.send_after(state.self, one_minute_ms, ContinueProcessing)
      actor.continue(State(..state, attempt: state.attempt + 1))
    }
  }
}
