import actors/search_actor
import actors/search_registry
import app_context.{type AppContext}
import config
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/io
import gleam/json
import shared/types
import handlers/search_handler
import wisp
import youid/uuid

pub fn handle_http_api_requests(
  ctx: AppContext,
  path path_segments: List(String),
  req req: wisp.Request,
) -> wisp.Response {
  case req.method, path_segments {
    Post, ["walker"] -> handle_walker_post(ctx, req)
    Get, ["walker"] -> handle_walker_get(ctx, req)
    Get, ["config"] -> handle_config(ctx)
    Get, ["ping"] -> handle_ping()
    _, _ -> wisp.not_found()
  }
}

fn get_user_email(req: wisp.Request) -> Result(String, Nil) {
  request.get_header(req, "x-user-email")
}

fn handle_config(ctx: AppContext) -> wisp.Response {
  let environment = case ctx.config.environment {
    config.Development -> "development"
    config.Production -> "production"
  }
  wisp.ok()
  |> wisp.json_body(
    json.to_string(
      json.object([
        #("environment", json.string(environment)),
        #("skipNotifications", json.bool(ctx.config.skip_notifications)),
      ]),
    ),
  )
}

fn handle_ping() -> wisp.Response {
  wisp.ok()
  |> wisp.json_body(
    json.to_string(
      json.object([#("message", json.string("pong"))]),
    ),
  )
}

fn handle_walker_post(ctx: AppContext, req: wisp.Request) -> wisp.Response {
  case get_user_email(req) {
    Error(Nil) ->
      wisp.bad_request("Missing x-user-email header")
      |> wisp.json_body(
        json.to_string(
          json.object([
            #("error", json.string("Missing x-user-email header")),
          ]),
        ),
      )
    Ok(user_email) -> handle_walker_post_for_user(ctx, req, user_email)
  }
}

fn handle_walker_post_for_user(
  ctx: AppContext,
  req: wisp.Request,
  user_email: String,
) -> wisp.Response {
  use json_body <- wisp.require_json(req)
  case decode.run(json_body, types.create_appointment_request_decoder()) {
    Ok(create_req) -> {
      let request =
        search_handler.AppointmentRequest(
          login: user_email,
          password: create_req.password,
          service: create_req.service,
          doctor: create_req.doctor,
          notification_email: create_req.notification_email,
        )
      let id = uuid.v4_string()
      case
        search_actor.create_and_call(ctx.search_registry, id, request, ctx.config, 5000)
      {
        Ok(search_actor.SearchComplete(result)) -> {
          io.println("Search completed")
          wisp.ok()
          |> wisp.json_body(
            json.to_string(
              json.object([
                #("status", json.string("completed")),
                #("id", json.string(id)),
                #("message", json.string(result)),
              ]),
            ),
          )
        }
        Error(_subject) -> {
          io.println("Search subject error")
          wisp.ok()
          |> wisp.json_body(
            json.to_string(
              json.object([
                #("status", json.string("processing")),
                #("id", json.string(id)),
                #("message", json.string("Search is being processed in the background")),
              ]),
            ),
          )
        }
      }
    }
    Error(_) -> {
      io.println("Invalid JSON")
      wisp.bad_request("Invalid JSON")
      |> wisp.json_body(
        json.to_string(
          json.object([
            #("error", json.string("Invalid JSON")),
          ]),
        ),
      )
    }
  }
}

fn search_status_to_json(status: search_registry.SearchStatus) -> json.Json {
  case status {
    search_registry.NoResult -> types.encode_search_status(types.NoResult)
    search_registry.Processing(attempts, last_message) ->
      types.encode_search_status(types.Processing(attempts, last_message))
    search_registry.HasResult(terms) ->
      types.encode_search_status(types.Completed(terms))
  }
}

fn handle_walker_get(ctx: AppContext, req: wisp.Request) -> wisp.Response {
  case get_user_email(req) {
    Error(Nil) -> {
      wisp.bad_request("Missing x-user-email header")
      |> wisp.json_body(
        json.to_string(
          json.object([
            #("error", json.string("Missing x-user-email header")),
          ]),
        ),
      )
    }
    Ok(user_email) -> handle_walker_get_for_user(ctx, user_email)
  }
}

fn handle_walker_get_for_user(
  ctx: AppContext,
  user_email: String,
) -> wisp.Response {
  case search_registry.get_user_results(ctx.search_registry, user_email, 5000) {
    Ok(results) -> {
      let searches_json =
        dict.to_list(results)
        |> json.array(fn(entry) {
          let #(id, search_registry.SearchRecord(status, service, doctor, ts, _)) = entry
          json.object([
            #("id", json.string(id)),
            #("service", json.string(service)),
            #(
              "doctor",
              json.object([
                #("firstName", json.string(doctor.first_name)),
                #("lastName", json.string(doctor.last_name)),
              ]),
            ),
            #("status", search_status_to_json(status)),
            #("timestamp", json.string(search_registry.format_timestamp(ts))),
          ])
        })

      wisp.ok()
      |> wisp.json_body(
        json.to_string(
          json.object([#("searches", searches_json)]),
        ),
      )
    }
    Error(_) -> {
      wisp.internal_server_error()
      |> wisp.json_body(
        json.to_string(
          json.object([
            #("error", json.string("Failed to retrieve search results")),
          ]),
        ),
      )
    }
  }
}
