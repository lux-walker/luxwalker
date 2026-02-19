import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io

pub fn send_appointment_found(
  topic: String,
  service: String,
  doctor: String,
) -> Nil {
  send(
    topic,
    "Nowe terminy w Luxmedzie!",
    "Nowe terminy " <> service <> " u lekarza " <> doctor,
    "urgent",
    "rotating_light",
  )
}

pub fn send_search_started(
  topic: String,
  service: String,
  doctor: String,
) -> Nil {
  send(
    topic,
    "Nowe wyszukiwanie w Luxmedzie",
    "Rozpoczęto wyszukiwanie " <> service <> " u lekarza " <> doctor,
    "default",
    "mag",
  )
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
