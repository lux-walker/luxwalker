import clients/luxmed_client.{
  type LockTermResponse, type LuxmedClient, type ServiceVariant, type Term,
  type TermForDay,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import gleam/order
import gleam/time/duration
import gleam/time/timestamp
import utils/log.{type Logger}
import youid/uuid

const lock_window_hours = 48

pub type LockedTerm {
  LockedTerm(term: Term, response: LockTermResponse)
}

pub fn handle_lock_term(
  logger: Logger,
  client: LuxmedClient,
  variant: ServiceVariant,
  terms_for_days: List(TermForDay),
) -> Option(LockedTerm) {
  let all_terms = list.flat_map(terms_for_days, fn(day) { day.terms })
  let sample = case all_terms {
    [first, ..] -> first.date_time_from
    [] -> ""
  }
  log.info(logger, "lock_term_evaluating", [
    #("total_terms", int.to_string(list.length(all_terms))),
    #("sample_date", sample),
  ])
  case first_lockable_term(all_terms) {
    option.None -> {
      log.info(logger, "lock_term_skipped", [
        #("reason", "no_term_at_least_48h_away"),
      ])
      option.None
    }
    Some(term) -> attempt_lock(logger, client, variant, term)
  }
}

fn attempt_lock(
  logger: Logger,
  client: LuxmedClient,
  variant: ServiceVariant,
  term: Term,
) -> Option(LockedTerm) {
  let correlation_id = uuid.v4_string()
  log.info(logger, "lock_term_attempting", [
    #("schedule_id", int.to_string(term.schedule_id)),
    #("date", term.date_time_from),
  ])
  case luxmed_client.lock_term(client, variant, term, correlation_id) {
    Ok(response) -> {
      log.info(logger, "lock_term_response", [
        #(
          "temporary_reservation_id",
          int.to_string(response.temporary_reservation_id),
        ),
        #("valuations", int.to_string(list.length(response.valuations))),
      ])
      Some(LockedTerm(term:, response:))
    }
    Error(err) -> {
      let reason = case err {
        luxmed_client.Unauthorized(m) -> m
        luxmed_client.RequestFailed(m) -> m
        luxmed_client.ParseError(m) -> m
        luxmed_client.NotFound(r) -> r
      }
      log.warn(logger, "lock_term_failed", [#("reason", reason)])
      option.None
    }
  }
}

fn first_lockable_term(all_terms: List(Term)) -> Option(Term) {
  all_terms
  |> list.find(fn(term) { is_at_least_48h_away(term.date_time_from) })
  |> option.from_result
}

fn is_at_least_48h_away(date_iso: String) -> Bool {
  case parse_iso(date_iso) {
    Error(_) -> False
    Ok(term_ts) -> {
      let threshold =
        timestamp.system_time()
        |> timestamp.add(duration.hours(lock_window_hours))
      case timestamp.compare(term_ts, threshold) {
        order.Lt -> False
        _ -> True
      }
    }
  }
}

fn parse_iso(date_iso: String) -> Result(timestamp.Timestamp, Nil) {
  case timestamp.parse_rfc3339(date_iso) {
    Ok(ts) -> Ok(ts)
    Error(_) -> timestamp.parse_rfc3339(date_iso <> "Z")
  }
}
