import actors/notification_actor
import actors/search_registry
import app_context.{type AppContext}
import clients/luxmed_client.{type LuxmedClient}
import config.{Development, Production}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import handlers/confirm_handler
import handlers/lock_term_handler
import handlers/search_handler.{type AppointmentRequest}
import shared/charon.{
  type BookingOutcome, type TermResult, BookingCreated, BookingFailed,
  BookingNone, TermResult,
}
import utils/log.{type Logger}

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
  SearchComplete(result: String, booking: BookingOutcome)
  SearchFailed(reason: String)
}

type PipelineSuccess {
  PipelineSuccess(
    terms: List(TermResult),
    booking: BookingOutcome,
    candidate: option.Option(charon.ReservationCandidate),
  )
}

type State {
  State(
    id: String,
    self: process.Subject(Message),
    attempt: Int,
    request: AppointmentRequest,
    context: AppContext,
    logger: Logger,
    notifier: Notifier,
    registry: Registry,
    schedule: fn() -> Int,
  )
}

type Notifier {
  Notifier(
    on_started: fn() -> Nil,
    on_appointment_found: fn() -> Nil,
    on_term_locked: fn(String, String) -> Nil,
  )
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
    on_term_locked: fn(clinic, date_time) {
      notification_actor.send_term_locked(
        notification,
        request.notification_email,
        request.service,
        doctor_name,
        clinic,
        date_time,
      )
    },
  )
}

type Registry {
  Registry(
    register: fn() -> Nil,
    completed: fn(List(TermResult)) -> Nil,
    booked: fn(List(TermResult), charon.BookingInfo) -> Nil,
    awaiting_confirmation: fn(List(TermResult), charon.ReservationCandidate) ->
      Nil,
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
    booked: fn(terms, booking) {
      search_registry.request_booked(registry, id, terms, booking)
    },
    awaiting_confirmation: fn(terms, candidate) {
      search_registry.request_awaiting_confirmation(
        registry,
        id,
        terms,
        candidate,
      )
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
  let reason = case error {
    search_handler.AuthenticationFailed -> "Authentication failed"
    search_handler.DoctorNotFound -> "Doctor not found"
    search_handler.VariantNotFound -> "Service not found"
    search_handler.VisitsNotFound -> "Visits not found"
    search_handler.Unknown(m) -> "Unknown error: " <> m
  }
  SearchFailed(reason)
}

fn log_search_error(state: State, error: search_handler.SearchError) -> Nil {
  let kind = case error {
    search_handler.AuthenticationFailed -> "authentication_failed"
    search_handler.DoctorNotFound -> "doctor_not_found"
    search_handler.VariantNotFound -> "variant_not_found"
    search_handler.VisitsNotFound -> "visits_not_found"
    search_handler.Unknown(_) -> "unknown"
  }
  let message = search_handler.get_error_message(error)
  log.warn(state.logger, "search_failed", [
    #("kind", kind),
    #("reason", message),
  ])
}

pub fn create_and_call(
  context context: AppContext,
  id id: String,
  request request: AppointmentRequest,
) -> Result(SearchResult, process.Subject(Message)) {
  let assert Ok(started) = create_actor(context, id, request)
  let subject = started.data
  let timeout_ms = 30_000
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
  let logger =
    log.child(context.logger, [
      #("component", "search_actor"),
      #("search_id", id),
    ])
  let initial_state =
    State(
      id: id,
      self: process.new_subject(),
      attempt: 0,
      request: request,
      context: context,
      logger: logger,
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
  log.info(state.logger, "actor_initialized", [])
  search_handler.log_request(state.logger, state.request)
  state.registry.register()
  log.info(state.logger, "actor_registered", [])
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
  log.info(state.logger, "actor_searching", [
    #("attempt", int.to_string(state.attempt)),
  ])

  case search_and_create(state) {
    Ok(pipeline) -> {
      let count = list.length(pipeline.terms)
      log.info(state.logger, "actor_search_complete", [
        #("terms", int.to_string(count)),
      ])
      record_pipeline_outcome(state, pipeline)
      process.send(
        reply_subject,
        SearchComplete(
          "Found " <> int.to_string(count) <> " terms",
          pipeline.booking,
        ),
      )
      actor.stop()
    }
    Error(error) ->
      case error {
        search_handler.VisitsNotFound -> {
          log.info(state.logger, "actor_no_visits_scheduled_retry", [])

          let new_attempt = state.attempt + 1
          new_attempt |> state.registry.attempt_failed("Visits not found")

          reply_subject
          |> process.send(SearchComplete(
            "No visits, request scheduled",
            BookingNone,
          ))

          let new_state = State(..state, attempt: new_attempt)
          send_continue_after(new_state)
          actor.continue(new_state)
        }
        actual_error -> {
          log_search_error(state, error)
          reply_subject |> process.send(error_to_search_complete(actual_error))
          actor.stop()
        }
      }
  }
}

fn continue_processing(state: State) -> actor.Next(State, Message) {
  log.info(state.logger, "actor_processing_again", [
    #("attempt", int.to_string(state.attempt)),
  ])
  case search_and_create(state) {
    Ok(pipeline) -> {
      log.info(state.logger, "actor_processing_complete", [])
      record_pipeline_outcome(state, pipeline)
      log.info(state.logger, "actor_request_completed", [])
      actor.stop()
    }
    Error(error) -> {
      let message = search_handler.get_error_message(error)
      log.warn(state.logger, "actor_processing_failed", [
        #("reason", message),
      ])

      let new_attempt = state.attempt + 1
      new_attempt |> state.registry.attempt_failed(message)

      send_continue_after(state)
      actor.continue(State(..state, attempt: new_attempt))
    }
  }
}

fn record_pipeline_outcome(state: State, pipeline: PipelineSuccess) -> Nil {
  case pipeline.booking, pipeline.candidate {
    BookingCreated(clinic, date_time, doctor), _ ->
      state.registry.booked(
        pipeline.terms,
        charon.BookingInfo(clinic:, date_time:, doctor:),
      )
    _, option.Some(candidate) ->
      state.registry.awaiting_confirmation(pipeline.terms, candidate)
    _, option.None -> state.registry.completed(pipeline.terms)
  }
}

fn search_and_create(
  state: State,
) -> Result(PipelineSuccess, search_handler.SearchError) {
  use client <- result.try(create_luxmed_client(state.logger, state.request))
  use success <- result.try(search_handler.handle_search(
    state.logger,
    client,
    state.request,
  ))

  let booking = try_lock_and_confirm(state, client, success)
  let candidate = case booking {
    BookingNone -> first_candidate(success.variant, success.terms)
    _ -> option.None
  }

  Ok(PipelineSuccess(
    terms: terms_to_result_list(success.terms),
    booking:,
    candidate:,
  ))
}

fn try_lock_and_confirm(
  state: State,
  client: LuxmedClient,
  success: search_handler.SearchSuccess,
) -> BookingOutcome {
  case
    lock_term_handler.handle_lock_term(
      state.logger,
      client,
      success.variant,
      success.terms,
    )
  {
    option.None -> {
      state.notifier.on_appointment_found()
      BookingNone
    }
    option.Some(locked) ->
      confirm_locked(state, client, success.variant, locked)
  }
}

fn confirm_locked(
  state: State,
  client: LuxmedClient,
  variant: luxmed_client.ServiceVariant,
  locked: lock_term_handler.LockedTerm,
) -> BookingOutcome {
  case
    confirm_handler.handle_confirm(
      state.logger,
      client,
      variant,
      locked.term,
      locked.response,
    )
  {
    True -> {
      state.notifier.on_term_locked(
        locked.term.clinic,
        locked.term.date_time_from,
      )
      BookingCreated(
        clinic: locked.term.clinic,
        date_time: locked.term.date_time_from,
        doctor: option.unwrap(locked.term.doctor.first_name, "")
          <> " "
          <> option.unwrap(locked.term.doctor.last_name, ""),
      )
    }
    False -> {
      state.notifier.on_appointment_found()
      BookingFailed
    }
  }
}

fn first_candidate(
  variant: luxmed_client.ServiceVariant,
  terms_for_days: List(luxmed_client.TermForDay),
) -> option.Option(charon.ReservationCandidate) {
  case list.flat_map(terms_for_days, fn(d) { d.terms }) {
    [] -> option.None
    [term, ..] ->
      option.Some(charon.ReservationCandidate(
        service_variant_id: variant.id,
        service_variant_name: variant.name,
        facility_id: term.clinic_id,
        facility_name: term.clinic,
        room_id: term.room_id,
        schedule_id: term.schedule_id,
        date_time_from: term.date_time_from,
        date_time_to: term.date_time_to,
        doctor_id: term.doctor.id,
        doctor_academic_title: option.unwrap(term.doctor.academic_title, ""),
        doctor_first_name: option.unwrap(term.doctor.first_name, ""),
        doctor_last_name: option.unwrap(term.doctor.last_name, ""),
      ))
  }
}

fn create_luxmed_client(
  logger: Logger,
  request: AppointmentRequest,
) -> Result(LuxmedClient, search_handler.SearchError) {
  case luxmed_client.login(request.login, request.password) {
    Ok(client) -> {
      log.info(logger, "luxmed_login_ok", [])
      Ok(client)
    }
    Error(err) -> {
      let #(reason, search_err) = case err {
        luxmed_client.Unauthorized(m) -> #(
          m,
          search_handler.AuthenticationFailed,
        )
        luxmed_client.RequestFailed(m) -> #(m, search_handler.Unknown(m))
        luxmed_client.ParseError(m) -> #(m, search_handler.Unknown(m))
        luxmed_client.NotFound(r) -> #(
          r,
          search_handler.Unknown("Login: " <> r),
        )
      }
      log.warn(logger, "luxmed_login_failed", [#("reason", reason)])
      Error(search_err)
    }
  }
}
