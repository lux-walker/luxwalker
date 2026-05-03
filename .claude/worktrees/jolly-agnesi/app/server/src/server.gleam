import actors/search_registry
import app_context.{AppContext}
import config
import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/result
import mist
import repeatedly
import root_http_requests_handler
import wisp
import wisp/wisp_mist

fn every_minute() -> Int {
  60_000
}

fn get_port() -> Int {
  case envoy.get("PORT") {
    Ok(port_str) ->
      int.parse(port_str)
      |> result.unwrap(8080)
    Error(_) -> 8080
  }
}

fn load_config() -> config.AppConfig {
  case config.load() {
    Ok(cfg) -> cfg
    Error(error) -> {
      io.println("FATAL: " <> config.print_error(error))
      panic as "Failed to load configuration"
    }
  }
}

fn ping_endpoint_url(environment: config.Environment) -> String {
  case environment {
    config.Development -> "http://localhost:8080/api/ping"
    config.Production -> "https://luxwalker.onrender.com/api/ping"
  }
}

fn send_ping(environment: config.Environment) -> Nil {
  let url = ping_endpoint_url(environment)
  io.println("Ping")

  case request.to(url) {
    Ok(req) -> {
      case httpc.send(req) {
        Ok(_response) -> io.println("Pong")
        Error(_) -> io.println("Ping failed")
      }
    }
    Error(_) -> io.println("Invalid ping URL")
  }

  Nil
}

pub fn main() {
  wisp.configure_logger()
  let app_config = load_config()
  app_config |> config.print_config()

  let assert Ok(registry) = search_registry.start()
  let ctx = AppContext(search_registry: registry, config: app_config)

  repeatedly.call(every_minute(), Nil, fn(_, _: Int) {
    send_ping(app_config.environment)
    Nil
  })

  let port = get_port()
  io.println("Starting server on port " <> int.to_string(port))

  let assert Ok(_) =
    wisp_mist.handler(
      root_http_requests_handler.handle_request(ctx, _),
      "secret-key",
    )
    |> mist.new
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start

  process.sleep_forever()
}
