import actors/search_actor
import app_context.{type AppContext}
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/io
import gleam/json
import types/appointment_request
import wisp
import youid/uuid

pub fn handle_http_api_requests(
  ctx: AppContext,
  path path_segments: List(String),
  req req: wisp.Request,
) -> wisp.Response {
  case req.method, path_segments {
    Post, ["walker"] -> handle_walker(ctx, req)
    _, _ -> wisp.not_found()
  }
}

fn handle_walker(ctx: AppContext, req: wisp.Request) -> wisp.Response {
  use json_body <- wisp.require_json(req)
  case decode.run(json_body, appointment_request.decoder()) {
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
