import gleam/regexp
import gleam/uri
import modem

pub type ActiveTab {
  CreateSearch
  ActiveSearches
}

pub type Route {
  EmailRoute
  TabRoute(route: ActiveTab)
}

pub type RouteState {
  RouteState(route: Route, email: String)
}

fn is_valid_email(email: String) -> Bool {
  case regexp.from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$") {
    Ok(re) -> regexp.check(re, email)
    Error(_) -> False
  }
}

pub fn get_route_from_uri(uri: uri.Uri) -> Route {
  parse_route_state(uri).route
}

fn parse_route_state(uri: uri.Uri) -> RouteState {
  case uri.path_segments(uri.path) {
    [email, ..rest] ->
      case is_valid_email(email) {
        True ->
          case rest {
            ["create"] -> RouteState(route: TabRoute(CreateSearch), email:)
            _ -> RouteState(route: TabRoute(ActiveSearches), email:)
          }
        False -> RouteState(route: EmailRoute, email: "")
      }
    _ -> RouteState(route: EmailRoute, email: "")
  }
}

pub fn get_initial_route_state() -> RouteState {
  case modem.initial_uri() {
    Ok(uri) -> parse_route_state(uri)
    Error(_) -> RouteState(route: EmailRoute, email: "")
  }
}
