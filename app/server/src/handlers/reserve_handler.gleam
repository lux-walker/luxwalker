import clients/luxmed_client.{
  type LuxmedClient, type ServiceVariant, type Term,
}
import gleam/int
import gleam/option.{Some}
import shared/charon.{type ReservationCandidate}
import utils/log.{type Logger}
import youid/uuid

pub type ReserveOutcome {
  Reserved(booking: charon.BookingInfo)
  ReserveFailed(reason: String)
}

pub fn reserve(
  logger: Logger,
  login: String,
  password: String,
  candidate: ReservationCandidate,
) -> ReserveOutcome {
  case luxmed_client.login(login, password) {
    Error(err) -> ReserveFailed(luxmed_error_reason(err))
    Ok(client) -> do_reserve(logger, client, candidate)
  }
}

fn do_reserve(
  logger: Logger,
  client: LuxmedClient,
  candidate: ReservationCandidate,
) -> ReserveOutcome {
  let variant =
    luxmed_client.ServiceVariant(
      id: candidate.service_variant_id,
      name: candidate.service_variant_name,
    )
  let term =
    luxmed_client.Term(
      clinic_id: candidate.facility_id,
      clinic: candidate.facility_name,
      room_id: candidate.room_id,
      schedule_id: candidate.schedule_id,
      date_time_from: candidate.date_time_from,
      date_time_to: candidate.date_time_to,
      doctor: luxmed_client.Doctor(
        id: candidate.doctor_id,
        academic_title: Some(candidate.doctor_academic_title),
        first_name: Some(candidate.doctor_first_name),
        last_name: Some(candidate.doctor_last_name),
      ),
    )
  case run_lock_and_confirm(logger, client, variant, term) {
    Ok(booking) -> Reserved(booking)
    Error(reason) -> ReserveFailed(reason)
  }
}

fn run_lock_and_confirm(
  logger: Logger,
  client: LuxmedClient,
  variant: ServiceVariant,
  term: Term,
) -> Result(charon.BookingInfo, String) {
  let correlation_id = uuid.v4_string()
  log.info(logger, "manual_lock_attempting", [
    #("schedule_id", int.to_string(term.schedule_id)),
    #("date", term.date_time_from),
  ])
  case luxmed_client.lock_term(client, variant, term, correlation_id) {
    Error(err) -> Error("Lock failed: " <> luxmed_error_reason(err))
    Ok(lock_response) -> {
      log.info(logger, "manual_lock_ok", [
        #(
          "temporary_reservation_id",
          int.to_string(lock_response.temporary_reservation_id),
        ),
      ])
      case
        luxmed_client.confirm_reservation(client, variant, term, lock_response)
      {
        Error(err) -> Error("Confirm failed: " <> luxmed_error_reason(err))
        Ok(resp) ->
          case resp.status {
            s if s >= 200 && s < 300 -> {
              log.info(logger, "manual_confirm_ok", [
                #("status", int.to_string(s)),
              ])
              Ok(charon.BookingInfo(
                clinic: term.clinic,
                date_time: term.date_time_from,
                doctor: option.unwrap(term.doctor.first_name, "")
                  <> " "
                  <> option.unwrap(term.doctor.last_name, ""),
              ))
            }
            s -> Error("Confirm returned status " <> int.to_string(s))
          }
      }
    }
  }
}

fn luxmed_error_reason(err: luxmed_client.LuxmedApiError) -> String {
  case err {
    luxmed_client.Unauthorized(m) -> m
    luxmed_client.RequestFailed(m) -> m
    luxmed_client.ParseError(m) -> m
    luxmed_client.NotFound(r) -> r
  }
}
