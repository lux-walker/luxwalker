import actors/notification_actor
import actors/search_registry
import app_context.{Actors, AppContext}
import config
import envoy
import gleam/erlang/process
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/result
import mist
import repeatedly
import root_http_requests_handler
import utils/log
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

fn load_config(logger: log.Logger) -> config.AppConfig {
  case config.load(logger) {
    Ok(cfg) -> cfg
    Error(error) -> {
      log.error(logger, "config_load_failed", [
        #("reason", config.print_error(error)),
      ])
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

fn send_ping(logger: log.Logger, environment: config.Environment) -> Nil {
  let url = ping_endpoint_url(environment)
  log.info(logger, "ping_start", [#("url", url)])

  case request.to(url) {
    Ok(req) -> {
      case httpc.send(req) {
        Ok(_response) -> log.info(logger, "ping_ok", [])
        Error(_) -> log.warn(logger, "ping_failed", [#("url", url)])
      }
    }
    Error(_) -> log.error(logger, "ping_invalid_url", [#("url", url)])
  }

  Nil
}

pub fn main() {
  wisp.configure_logger()
  log.configure()

  let root_logger = log.root([#("service", "luxwalker")])

  let app_config = load_config(root_logger)
  config.print_config(root_logger, app_config)

  let registry_logger = log.child(root_logger, [#("component", "search_registry")])
  let assert Ok(registry) = search_registry.start(registry_logger)

  let assert Ok(notification) = notification_actor.start(app_config)

  let ctx =
    AppContext(
      actors: Actors(registry, notification),
      config: app_config,
      logger: root_logger,
    )

  let port = get_port()
  log.info(root_logger, "server_starting", [#("port", int.to_string(port))])

  let assert Ok(_) =
    wisp_mist.handler(
      root_http_requests_handler.handle_request(ctx, _),
      "secret-key",
    )
    |> mist.new
    |> mist.port(port)
    |> mist.bind("0.0.0.0")
    |> mist.start

  let ping_logger = log.child(root_logger, [#("component", "ping")])
  every_minute()
  |> repeatedly.call(Nil, fn(_, _) {
    send_ping(ping_logger, app_config.environment)
  })

  process.sleep_forever()
}
