import gleam/dynamic/decode
import gleam/io
import gleam/json.{type Json}
import wisp

pub type Test

pub fn try_result(
  result: Result(a, b),
  error_callback: fn() -> wisp.Response,
  callback: fn(a) -> wisp.Response,
) -> wisp.Response {
  case result {
    Ok(value) -> callback(value)
    Error(_) -> error_callback()
  }
}

pub fn as_json_ok(entries: List(#(String, Json))) {
  as_json(entries, 200)
}

pub fn as_json(entries entries: List(#(String, Json)), status status: Int) {
  wisp.response(status)
  |> wisp.json_body(json.to_string(json.object(entries)))
}

pub fn decode_json_body(
  req: wisp.Request,
  decoder: decode.Decoder(a),
  callback: fn(a) -> wisp.Response,
) -> wisp.Response {
  use json_body <- wisp.require_json(req)
  case decode.run(json_body, decoder) {
    Ok(value) -> callback(value)
    Error(_) -> {
      io.println("Invalid JSON")
      json_error("Invalid JSON")
    }
  }
}

fn json_error(msg: String) -> wisp.Response {
  wisp.bad_request(msg)
  |> wisp.json_body(json.to_string(json.object([#("error", json.string(msg))])))
}
