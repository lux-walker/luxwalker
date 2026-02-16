import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/io
import gleam/otp/actor

pub type SearchStatus {
  NoResult
  HasResult(result: String)
}

pub type Message {
  Register(id: String)
  UpdateResult(id: String, result: String)
  GetResult(id: String, reply_with: process.Subject(SearchStatus))
}

pub type State {
  State(results: Dict(String, SearchStatus))
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

pub fn register_search(registry: process.Subject(Message), id: String) -> Nil {
  process.send(registry, Register(id))
}

pub fn update_result(
  registry: process.Subject(Message),
  id: String,
  result: String,
) -> Nil {
  process.send(registry, UpdateResult(id, result))
}

pub fn get_result(
  registry: process.Subject(Message),
  id: String,
  timeout_ms: Int,
) -> Result(SearchStatus, Nil) {
  let reply_subject = process.new_subject()
  process.send(registry, GetResult(id, reply_subject))
  process.receive(reply_subject, timeout_ms)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Register(id) -> {
      io.println("Registry: Registered search " <> id)
      let new_results = dict.insert(state.results, id, NoResult)
      actor.continue(State(results: new_results))
    }

    UpdateResult(id, result) -> {
      io.println("Registry: Updated result for " <> id)
      let new_results = dict.insert(state.results, id, HasResult(result))
      actor.continue(State(results: new_results))
    }

    GetResult(id, reply_subject) -> {
      let status = case dict.get(state.results, id) {
        Ok(s) -> s
        Error(Nil) -> NoResult
      }
      process.send(reply_subject, status)
      actor.continue(state)
    }
  }
}
