import actors/search_actor
import actors/search_registry
import app_context.{type AppContext, type RequestAppContext, RequestAppContext}
import config
import gleam/dict
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/io
import gleam/json
import handlers/search_handler
import shared/types
import utils/httpx
import wisp
import youid/uuid

pub fn handle_http_api_requests(
  app_context ctx: AppContext,
  path path_segments: List(String),
  req req: wisp.Request,
) -> wisp.Response {
  case req.method, path_segments {
    Get, ["config"] -> handle_config(ctx)
    Get, ["ping"] -> handle_ping()
    _, _ -> handle_request_context_oriented(ctx, path_segments, req)
  }
}

fn handle_request_context_oriented(
  app_context ctx: AppContext,
  path path_segments: List(String),
  req req: wisp.Request,
) -> wisp.Response {
  use user_email <- get_user_email(req)
  let request_context = RequestAppContext(user_email)
  case req.method, path_segments {
    Post, ["walker"] -> handle_walker_post_for_user(ctx, request_context, req)
    Get, ["walker"] -> handle_walker_get_for_user(ctx, request_context)
    Post, ["walker", id, "rerun"] ->
      handle_walker_rerun_for_user(ctx, request_context, id)
    _, _ -> wisp.not_found()
  }
}

fn get_user_email(
  req: wisp.Request,
  callback: fn(String) -> wisp.Response,
) -> wisp.Response {
  case request.get_header(req, "x-user-email") {
    Ok(email) -> callback(email)
    Error(_) -> wisp.bad_request("Missing x-user-email header")
  }
}

fn handle_config(ctx: AppContext) -> wisp.Response {
  let environment = case ctx.config.environment {
    config.Development -> "development"
    config.Production -> "production"
  }

  httpx.as_json_ok([
    #("environment", json.string(environment)),
    #("skipNotifications", json.bool(ctx.config.skip_notifications)),
  ])
}

fn handle_ping() -> wisp.Response {
  httpx.as_json_ok([#("message", json.string("pong"))])
}

fn handle_walker_post_for_user(
  ctx: AppContext,
  request_ctx: RequestAppContext,
  req: wisp.Request,
) -> wisp.Response {
  use create_appointment <- httpx.decode_json_body(
    req,
    types.create_appointment_request_decoder(),
  )

  let request =
    search_handler.AppointmentRequest(
      login: request_ctx.user_email,
      password: create_appointment.password,
      service: create_appointment.service,
      doctor: create_appointment.doctor,
      notification_email: create_appointment.notification_email,
    )

  let id = uuid.v4_string()
  let actor_result =
    search_actor.create_and_call(
      context: ctx,
      id: id,
      request: request,
      timeout_ms: 5000,
    )

  case actor_result {
    Ok(search_actor.SearchComplete(result)) ->
      httpx.as_json_ok([
        #("status", json.string("completed")),
        #("id", json.string(id)),
        #("message", json.string(result)),
      ])
    Error(_subject) ->
      httpx.as_json_ok([
        #("status", json.string("processing")),
        #("id", json.string(id)),
        #("message", json.string("Search is being processed in the background")),
      ])
  }
}

fn handle_walker_rerun_for_user(
  ctx: AppContext,
  request_context: RequestAppContext,
  old_id: String,
) -> wisp.Response {
  use details <- httpx.try_result(
    search_registry.get_request_details(
      ctx.actors.search_registry,
      old_id,
      5000,
    ),
    wisp.not_found,
  )

  case details.record.user_email == request_context.user_email {
    False -> httpx.as_json([#("error", json.string("Not authorized"))], 403)
    True -> {
      let new_request =
        search_handler.AppointmentRequest(
          login: request_context.user_email,
          password: details.credentials.password,
          service: details.record.service,
          doctor: details.record.doctor,
          notification_email: details.record.notification_email,
        )
      let new_id = uuid.v4_string()
      search_registry.delete_search(ctx.actors.search_registry, old_id)
      let _ = search_actor.create_actor(ctx, new_id, new_request)
      io.println("Rerun started: " <> new_id)
      httpx.as_json_ok([
        #("status", json.string("processing")),
        #("id", json.string(new_id)),
      ])
    }
  }
}

fn handle_walker_get_for_user(
  ctx: AppContext,
  request_context: RequestAppContext,
) -> wisp.Response {
  let get_user_result =
    search_registry.get_user_results(
      ctx.actors.search_registry,
      request_context.user_email,
      timeout_ms: 5000,
    )

  use results <- httpx.try_result(get_user_result, fn() {
    httpx.as_json(
      [
        #("error", json.string("Failed to retrieve search results")),
      ],
      status: 500,
    )
  })

  let searches_json =
    dict.to_list(results)
    |> json.array(fn(entry) {
      let #(id, record) = entry
      search_record_to_json(id, record)
    })

  httpx.as_json_ok([#("searches", searches_json)])
}

fn search_record_to_json(
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

fn search_status_to_json(status: search_registry.SearchStatus) -> json.Json {
  case status {
    search_registry.NoResult -> types.encode_search_status(types.NoResult)
    search_registry.Processing(attempts, last_message) ->
      types.encode_search_status(types.Processing(attempts, last_message))
    search_registry.HasResult(terms) ->
      types.encode_search_status(types.Completed(terms))
  }
}
