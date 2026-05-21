import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import shared/charon.{type Doctor}
import utils/log.{type Logger}

pub type SearchStatus {
  NoResult
  Processing(attempts: Int, last_message: String)
  HasResult(terms: List(charon.TermResult))
  Booked(terms: List(charon.TermResult), booking: charon.BookingInfo)
  AwaitingConfirmation(
    terms: List(charon.TermResult),
    candidate: charon.ReservationCandidate,
  )
}

pub type SearchRecord {
  SearchRecord(
    status: SearchStatus,
    service: String,
    doctor: Doctor,
    timestamp: Timestamp,
    user_email: String,
    notification_email: String,
  )
}

pub type Credentials {
  Credentials(password: String)
}

pub type RequestDetails {
  RequestDetails(record: SearchRecord, credentials: Credentials)
}

pub fn format_timestamp(ts: Timestamp) -> String {
  let #(date, time) = timestamp.to_calendar(ts, calendar.local_offset())
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

pub type Message {
  Register(
    id: String,
    service: String,
    doctor: Doctor,
    user_email: String,
    notification_email: String,
    password: String,
  )
  AttemptFailed(id: String, attempts: Int, last_message: String)
  Completed(id: String, terms: List(charon.TermResult))
  BookingConfirmed(
    id: String,
    terms: List(charon.TermResult),
    booking: charon.BookingInfo,
  )
  AwaitingConfirmationStored(
    id: String,
    terms: List(charon.TermResult),
    candidate: charon.ReservationCandidate,
  )
  Delete(id: String)
  GetResult(id: String, reply_with: process.Subject(SearchRecord))
  GetRequestDetails(
    id: String,
    reply_with: process.Subject(Result(RequestDetails, Nil)),
  )
  GetAllResults(reply_with: process.Subject(Dict(String, SearchRecord)))
  GetUserResults(
    user_email: String,
    reply_with: process.Subject(Dict(String, SearchRecord)),
  )
}

pub type State {
  State(results: Dict(String, RequestDetails), logger: Logger)
}

pub fn start(
  logger: Logger,
) -> Result(process.Subject(Message), actor.StartError) {
  let result =
    actor.new(State(results: dict.new(), logger: logger))
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
  user_email: String,
  notification_email: String,
  password: String,
) -> Nil {
  registry
  |> process.send(Register(
    id,
    service,
    doctor,
    user_email,
    notification_email,
    password,
  ))
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
  terms: List(charon.TermResult),
) -> Nil {
  process.send(registry, Completed(id, terms))
}

pub fn request_booked(
  registry: process.Subject(Message),
  id: String,
  terms: List(charon.TermResult),
  booking: charon.BookingInfo,
) -> Nil {
  process.send(registry, BookingConfirmed(id, terms, booking))
}

pub fn request_awaiting_confirmation(
  registry: process.Subject(Message),
  id: String,
  terms: List(charon.TermResult),
  candidate: charon.ReservationCandidate,
) -> Nil {
  process.send(registry, AwaitingConfirmationStored(id, terms, candidate))
}

pub fn delete_search(registry: process.Subject(Message), id: String) -> Nil {
  process.send(registry, Delete(id))
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

pub fn get_request_details(
  registry: process.Subject(Message),
  id: String,
  timeout_ms: Int,
) -> Result(RequestDetails, Nil) {
  let reply_subject = process.new_subject()
  registry |> process.send(GetRequestDetails(id, reply_subject))
  case reply_subject |> process.receive(timeout_ms) |> result.flatten() {
    Ok(details) -> Ok(details)
    Error(_) -> Error(Nil)
  }
}

pub fn get_all_results(
  registry: process.Subject(Message),
  timeout_ms: Int,
) -> Result(Dict(String, SearchRecord), Nil) {
  let reply_subject = process.new_subject()
  process.send(registry, GetAllResults(reply_subject))
  process.receive(reply_subject, timeout_ms)
}

pub fn get_user_results(
  registry registry: process.Subject(Message),
  user_email user_email: String,
  timeout_ms timeout_ms: Int,
) -> Result(Dict(String, SearchRecord), Nil) {
  let reply_subject = process.new_subject()
  registry |> process.send(GetUserResults(user_email, reply_subject))
  reply_subject |> process.receive(timeout_ms)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Register(id, service, doctor, user_email, notification_email, password) -> {
      log.info(state.logger, "search_registered", [
        #("search_id", id),
        #("service", service),
        #("user_email", user_email),
      ])
      let record =
        SearchRecord(
          status: NoResult,
          service:,
          doctor:,
          timestamp: timestamp.system_time(),
          user_email:,
          notification_email:,
        )
      let credentials = Credentials(password:)
      let details = RequestDetails(record:, credentials:)
      let new_results = dict.insert(state.results, id, details)
      actor.continue(State(..state, results: new_results))
    }

    AttemptFailed(id, attempts, last_message) -> {
      log.warn(state.logger, "search_attempt_failed", [
        #("search_id", id),
        #("attempts", int.to_string(attempts)),
        #("reason", last_message),
      ])
      let new_results = case dict.get(state.results, id) {
        Ok(details) -> {
          let updated_record =
            SearchRecord(
              ..details.record,
              status: Processing(attempts, last_message),
              timestamp: timestamp.system_time(),
            )
          dict.insert(
            state.results,
            id,
            RequestDetails(..details, record: updated_record),
          )
        }
        Error(Nil) -> state.results
      }
      actor.continue(State(..state, results: new_results))
    }

    Completed(id, terms) -> {
      log.info(state.logger, "search_completed", [
        #("search_id", id),
        #("terms", int.to_string(list.length(terms))),
      ])
      let new_results = case dict.get(state.results, id) {
        Ok(details) -> {
          let updated_record =
            SearchRecord(
              ..details.record,
              status: HasResult(terms),
              timestamp: timestamp.system_time(),
            )
          dict.insert(
            state.results,
            id,
            RequestDetails(..details, record: updated_record),
          )
        }
        Error(Nil) -> state.results
      }
      actor.continue(State(..state, results: new_results))
    }

    BookingConfirmed(id, terms, booking) -> {
      log.info(state.logger, "search_booked", [
        #("search_id", id),
        #("terms", int.to_string(list.length(terms))),
        #("date_time", booking.date_time),
      ])
      let new_results = case dict.get(state.results, id) {
        Ok(details) -> {
          let updated_record =
            SearchRecord(
              ..details.record,
              status: Booked(terms, booking),
              timestamp: timestamp.system_time(),
            )
          dict.insert(
            state.results,
            id,
            RequestDetails(..details, record: updated_record),
          )
        }
        Error(Nil) -> state.results
      }
      actor.continue(State(..state, results: new_results))
    }

    AwaitingConfirmationStored(id, terms, candidate) -> {
      log.info(state.logger, "search_awaiting_confirmation", [
        #("search_id", id),
        #("terms", int.to_string(list.length(terms))),
        #("date_time", candidate.date_time_from),
      ])
      let new_results = case dict.get(state.results, id) {
        Ok(details) -> {
          let updated_record =
            SearchRecord(
              ..details.record,
              status: AwaitingConfirmation(terms, candidate),
              timestamp: timestamp.system_time(),
            )
          dict.insert(
            state.results,
            id,
            RequestDetails(..details, record: updated_record),
          )
        }
        Error(Nil) -> state.results
      }
      actor.continue(State(..state, results: new_results))
    }

    Delete(id) -> {
      log.info(state.logger, "search_deleted", [#("search_id", id)])
      actor.continue(State(..state, results: dict.delete(state.results, id)))
    }

    GetResult(id, reply_subject) -> {
      let record = case dict.get(state.results, id) {
        Ok(details) -> details.record
        Error(Nil) ->
          SearchRecord(
            status: NoResult,
            service: "",
            doctor: charon.Doctor(first_name: "", last_name: ""),
            timestamp: timestamp.system_time(),
            user_email: "",
            notification_email: "",
          )
      }
      reply_subject |> process.send(record)
      actor.continue(state)
    }

    GetRequestDetails(id, reply_subject) -> {
      reply_subject |> process.send(dict.get(state.results, id))
      actor.continue(state)
    }

    GetAllResults(reply_subject) -> {
      let records =
        dict.map_values(state.results, fn(_id, details) { details.record })
      reply_subject |> process.send(records)
      actor.continue(state)
    }

    GetUserResults(user_email, reply_subject) -> {
      let filtered =
        dict.filter(state.results, fn(_id, details) {
          details.record.user_email == user_email
        })
        |> dict.map_values(fn(_id, details) { details.record })
      reply_subject |> process.send(filtered)
      actor.continue(state)
    }
  }
}

