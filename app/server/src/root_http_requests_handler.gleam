import api/api_request_handler
import app_context.{type AppContext}
import gleam/option
import wisp

pub fn handle_request(ctx: AppContext, req: wisp.Request) -> wisp.Response {
  use <- wisp.serve_static(req, under: "/", from: static_directory())

  case wisp.path_segments(req), req.method {
    ["api", ..rest], _ ->
      api_request_handler.handle_http_api_requests(ctx, rest, req)
    [_email, ..], _ -> serve_index()
    _, _ -> serve_index()
  }
}

fn serve_index() -> wisp.Response {
  let index_path = static_directory() <> "/index.html"
  wisp.ok()
  |> wisp.set_header("content-type", "text/html; charset=utf-8")
  |> wisp.set_body(wisp.File(index_path, 0, option.None))
}

fn static_directory() -> String {
  let assert Ok(priv) = wisp.priv_directory("server")
  priv <> "/static"
}
