import api/api_request_handler
import app_context.{type AppContext}
import gleam/http
import ui/ui_request_handler
import wisp

pub fn handle_request(ctx: AppContext, req: wisp.Request) -> wisp.Response {
  case wisp.path_segments(req), req.method {
    [], http.Get -> ui_request_handler.serve_page()
    ["api", ..rest], _ ->
      api_request_handler.handle_http_api_requests(ctx, rest, req)
    _, _ -> wisp.not_found()
  }
}
