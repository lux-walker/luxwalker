import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io

pub type NtfyClient {
  NtfyClient(
    send_appointment_found: fn(String, String) -> Nil,
    send_search_started: fn(String, String) -> Nil,
  )
}

pub fn create_client(topic: String, skip: Bool) -> NtfyClient {
  case skip {
    True ->
      NtfyClient(
        send_appointment_found: fn(_, _) {
          io.println("Ntfy: Skipping appointment found (notifications disabled)")
        },
        send_search_started: fn(_, _) {
          io.println("Ntfy: Skipping search started (notifications disabled)")
        },
      )
    False ->
      NtfyClient(
        send_appointment_found: fn(service, doctor) {
          send(
            topic,
            "Nowe terminy w Luxmedzie!",
            "Nowe terminy " <> service <> " u lekarza " <> doctor,
            "urgent",
            "rotating_light",
          )
        },
        send_search_started: fn(service, doctor) {
          send(
            topic,
            "Nowe wyszukiwanie w Luxmedzie",
            "Rozpoczęto wyszukiwanie "
              <> service
              <> " u lekarza "
              <> doctor,
            "default",
            "mag",
          )
        },
      )
  }
}

fn send(
  topic: String,
  title: String,
  body: String,
  priority: String,
  tags: String,
) -> Nil {
  let url = "https://ntfy.sh/" <> topic

  case request.to(url) {
    Error(_) -> {
      io.println("Ntfy: Failed to build request for topic " <> topic)
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
          io.println("Ntfy: Notification sent to topic " <> topic)
          Nil
        }
        Error(_) -> {
          io.println("Ntfy: Failed to send notification to topic " <> topic)
          Nil
        }
      }
    }
  }
}
