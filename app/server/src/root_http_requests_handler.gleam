import api/api_request_handler
import app_context.{type AppContext}
import wisp

pub fn handle_request(ctx: AppContext, req: wisp.Request) -> wisp.Response {
  use <- wisp.serve_static(req, under: "/", from: static_directory())

  case wisp.path_segments(req), req.method {
    ["api", ..rest], _ ->
      api_request_handler.handle_http_api_requests(ctx, rest, req)
    _, _ -> wisp.not_found()
  }
}

fn static_directory() -> String {
  let assert Ok(priv) = wisp.priv_directory("server")
  priv <> "/static"
}
