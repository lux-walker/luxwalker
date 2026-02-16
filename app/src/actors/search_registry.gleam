import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import types/appointment_request.{type Doctor}

pub type SearchStatus {
  NoResult
  Processing(attempts: Int, last_message: String)
  HasResult(result: String)
}

pub type SearchRecord {
  SearchRecord(status: SearchStatus, service: String, doctor: Doctor)
}

pub type Message {
  Register(id: String, service: String, doctor: Doctor)
  AttemptFailed(id: String, attempts: Int, last_message: String)
  Completed(id: String, result: String)
  GetResult(id: String, reply_with: process.Subject(SearchRecord))
  GetAllResults(reply_with: process.Subject(Dict(String, SearchRecord)))
}

pub type State {
  State(results: Dict(String, SearchRecord))
}

pub fn start() -> Result(process.Subject(Message), actor.StartError) {
  let result =
    actor.new(State(results: dict.new()))
    |> actor.on_message(handle_message)
    |> actor.start

  case result {
    Ok(started) -> Ok(started.data)
    Error(e) -> Error(e)
  }
}

pub fn register_search(
  registry: process.Subject(Message),
  id: String,
  service: String,
  doctor: Doctor,
) -> Nil {
  process.send(registry, Register(id, service, doctor))
}

pub fn request_attempt_failed(
  registry: process.Subject(Message),
  id: String,
  attempts: Int,
  last_message: String,
) -> Nil {
  process.send(registry, AttemptFailed(id, attempts, last_message))
}

pub fn request_completed(
  registry: process.Subject(Message),
  id: String,
  result: String,
) -> Nil {
  process.send(registry, Completed(id, result))
}

pub fn get_result(
  registry: process.Subject(Message),
  id: String,
  timeout_ms: Int,
) -> Result(SearchRecord, Nil) {
  let reply_subject = process.new_subject()
  process.send(registry, GetResult(id, reply_subject))
  process.receive(reply_subject, timeout_ms)
}

pub fn get_all_results(
  registry: process.Subject(Message),
  timeout_ms: Int,
) -> Result(Dict(String, SearchRecord), Nil) {
  let reply_subject = process.new_subject()
  process.send(registry, GetAllResults(reply_subject))
  process.receive(reply_subject, timeout_ms)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Register(id, service, doctor) -> {
      io.println("Registry: Registered search " <> id)
      let record = SearchRecord(status: NoResult, service: service, doctor: doctor)
      let new_results = dict.insert(state.results, id, record)
      actor.continue(State(results: new_results))
    }

    AttemptFailed(id, attempts, last_message) -> {
      io.println("Registry: Attempt failed for " <> id)
      let new_results = case dict.get(state.results, id) {
        Ok(record) -> {
          let updated_record =
            SearchRecord(
              ..record,
              status: Processing(attempts, last_message),
            )
          dict.insert(state.results, id, updated_record)
        }
        Error(Nil) -> state.results
      }
      actor.continue(State(results: new_results))
    }

    Completed(id, result) -> {
      io.println("Registry: Completed search for " <> id)
      let new_results = case dict.get(state.results, id) {
        Ok(record) -> {
          let updated_record = SearchRecord(..record, status: HasResult(result))
          dict.insert(state.results, id, updated_record)
        }
        Error(Nil) -> state.results
      }
      actor.continue(State(results: new_results))
    }

    GetResult(id, reply_subject) -> {
      let record = case dict.get(state.results, id) {
        Ok(r) -> r
        Error(Nil) ->
          SearchRecord(
            status: NoResult,
            service: "",
            doctor: appointment_request.Doctor(first_name: "", last_name: ""),
          )
      }
      process.send(reply_subject, record)
      actor.continue(state)
    }
    GetAllResults(reply_subject) -> {
      process.send(reply_subject, state.results)
      actor.continue(state)
    }
  }
}
