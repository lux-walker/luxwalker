import gleam/bool
import gleam/http
import gleam/http/request
import gleam/httpc
import utils/log.{type Logger}

pub type NtfyClient {
  NtfyClient(
    send_appointment_found: fn(String, String) -> Nil,
    send_search_started: fn(String, String) -> Nil,
  )
}

pub fn create_client(topic: String, skip: Bool) -> NtfyClient {
  let logger = log.root([#("component", "ntfy_client")])
  log.info(logger, "ntfy_client_created", [
    #("enabled", bool.to_string(!skip)),
    #("topic", topic),
  ])
  case skip {
    True ->
      NtfyClient(
        send_appointment_found: fn(_, _) {
          log.info(logger, "ntfy_skipped", [#("kind", "appointment_found")])
        },
        send_search_started: fn(_, _) {
          log.info(logger, "ntfy_skipped", [#("kind", "search_started")])
        },
      )
    False ->
      NtfyClient(
        send_appointment_found: fn(service, doctor) {
          log.info(logger, "ntfy_sending", [
            #("kind", "appointment_found"),
            #("topic", topic),
            #("service", service),
            #("doctor", doctor),
          ])
          send(
            logger,
            topic,
            "Nowe terminy w Luxmedzie!",
            "Nowe terminy " <> service <> " u lekarza " <> doctor,
            "urgent",
            "rotating_light",
          )
        },
        send_search_started: fn(service, doctor) {
          log.info(logger, "ntfy_sending", [
            #("kind", "search_started"),
            #("topic", topic),
            #("service", service),
            #("doctor", doctor),
          ])
          send(
            logger,
            topic,
            "Nowe wyszukiwanie w Luxmedzie",
            "Rozpoczęto wyszukiwanie " <> service <> " u lekarza " <> doctor,
            "default",
            "mag",
          )
        },
      )
  }
}

fn send(
  logger: Logger,
  topic: String,
  title: String,
  body: String,
  priority: String,
  tags: String,
) -> Nil {
  let url = "https://ntfy.sh/" <> topic

  case request.to(url) {
    Error(_) -> {
      log.error(logger, "ntfy_request_build_failed", [#("topic", topic)])
      Nil
    }
    Ok(req) -> {
      let req =
        req
        |> request.set_method(http.Post)
        |> request.set_header("title", title)
        |> request.set_header("priority", priority)
        |> request.set_header("tags", tags)
        |> request.set_body(body)

      case httpc.send(req) {
        Ok(_) -> {
          log.info(logger, "ntfy_sent", [#("topic", topic)])
          Nil
        }
        Error(_) -> {
          log.error(logger, "ntfy_send_failed", [#("topic", topic)])
          Nil
        }
      }
    }
  }
}
