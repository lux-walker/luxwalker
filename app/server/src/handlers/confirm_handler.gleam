import clients/luxmed_client.{
  type LockTermResponse, type LuxmedClient, type ServiceVariant, type Term,
}
import gleam/int
import gleam/string
import utils/log.{type Logger}

pub fn handle_confirm(
  logger: Logger,
  client: LuxmedClient,
  variant: ServiceVariant,
  term: Term,
  lock_response: LockTermResponse,
) -> Bool {
  log.info(logger, "confirm_attempting", [
    #(
      "temporary_reservation_id",
      int.to_string(lock_response.temporary_reservation_id),
    ),
    #("schedule_id", int.to_string(term.schedule_id)),
    #("date", term.date_time_from),
  ])
  case luxmed_client.confirm_reservation(client, variant, term, lock_response) {
    Ok(resp) -> {
      let body_preview = string.slice(resp.body, 0, 500)
      case resp.status {
        s if s >= 200 && s < 300 -> {
          log.info(logger, "confirm_response", [
            #("status", int.to_string(s)),
            #("body", body_preview),
          ])
          True
        }
        s -> {
          log.warn(logger, "confirm_response", [
            #("status", int.to_string(s)),
            #("body", body_preview),
          ])
          False
        }
      }
    }
    Error(err) -> {
      let reason = case err {
        luxmed_client.Unauthorized(m) -> m
        luxmed_client.RequestFailed(m) -> m
        luxmed_client.ParseError(m) -> m
        luxmed_client.NotFound(r) -> r
      }
      log.warn(logger, "confirm_failed", [#("reason", reason)])
      False
    }
  }
}
