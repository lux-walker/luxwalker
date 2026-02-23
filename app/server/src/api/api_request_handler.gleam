import actors/search_actor
import actors/search_registry
import app_context.{type AppContext}
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/io
import gleam/json
import shared/types
import wisp
import youid/uuid

pub fn handle_http_api_requests(
  ctx: AppContext,
  path path_segments: List(String),
  req req: wisp.Request,
) -> wisp.Response {
  case req.method, path_segments {
    Post, ["walker"] -> handle_walker_post(ctx, req)
    Get, ["walker"] -> handle_walker_get(ctx)
    Get, ["ping"] -> handle_ping()
    _, _ -> wisp.not_found()
  }
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
  use json_body <- wisp.require_json(req)
  case decode.run(json_body, types.appointment_request_decoder()) {
    Ok(request) -> {
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
    search_registry.NoResult ->
      json.object([#("status", json.string("no_result"))])
    search_registry.Processing(attempts, last_message) ->
      json.object([
        #("status", json.string("processing")),
        #("attempts", json.int(attempts)),
        #("last_message", json.string(last_message)),
      ])
    search_registry.HasResult(result) ->
      json.object([
        #("status", json.string("completed")),
        #("result", json.string(result)),
      ])
  }
}

fn handle_walker_get(ctx: AppContext) -> wisp.Response {
  case search_registry.get_all_results(ctx.search_registry, 5000) {
    Ok(results) -> {
      let searches_json =
        dict.to_list(results)
        |> json.array(fn(entry) {
          let #(id, search_registry.SearchRecord(status, service, doctor, ts)) = entry
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
