import actors/search_registry
import gleam/json
import shared/charon

pub fn search_record_to_json(
  id: String,
  record: search_registry.SearchRecord,
) -> json.Json {
  json.object([
    #("id", json.string(id)),
    #("service", json.string(record.service)),
    #(
      "doctor",
      json.object([
        #("firstName", json.string(record.doctor.first_name)),
        #("lastName", json.string(record.doctor.last_name)),
      ]),
    ),
    #("status", search_status_to_json(record.status)),
    #(
      "timestamp",
      json.string(search_registry.format_timestamp(record.timestamp)),
    ),
    #("notificationEmail", json.string(record.notification_email)),
  ])
}

pub fn search_status_to_json(
  status: search_registry.SearchStatus,
) -> json.Json {
  case status {
    search_registry.NoResult -> charon.encode_search_status(charon.NoResult)
    search_registry.Processing(attempts, last_message) ->
      charon.encode_search_status(charon.Processing(attempts, last_message))
    search_registry.HasResult(terms) ->
      charon.encode_search_status(charon.Completed(terms))
    search_registry.Booked(terms, booking) ->
      charon.encode_search_status(charon.Booked(terms, booking))
    search_registry.AwaitingConfirmation(terms, candidate) ->
      charon.encode_search_status(charon.AwaitingConfirmation(terms, candidate))
  }
}
