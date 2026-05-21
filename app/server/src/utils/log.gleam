import gleam/io
import gleam/list
import gleam/string

pub opaque type Logger {
  Logger(fields: List(#(String, String)))
}

pub fn new() -> Logger {
  Logger(fields: [])
}

pub fn root(fields: List(#(String, String))) -> Logger {
  Logger(fields: fields)
}

pub fn child(parent: Logger, fields: List(#(String, String))) -> Logger {
  Logger(fields: list.append(parent.fields, fields))
}

pub fn info(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  emit(green("INFO "), logger, event, extra)
}

pub fn warn(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  emit(yellow("WARN "), logger, event, extra)
}

pub fn error(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  emit(red("ERROR"), logger, event, extra)
}

pub fn debug(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  emit(gray("DEBUG"), logger, event, extra)
}

fn emit(
  level: String,
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  let fields = list.append(logger.fields, extra)
  let pairs = list.map(fields, fn(kv) { dim(kv.0 <> "=") <> kv.1 })
  let suffix = case pairs {
    [] -> ""
    _ -> " " <> string.join(pairs, " ")
  }
  io.println(level <> " " <> bold(event) <> suffix)
}

const esc = "\u{001b}["

const reset = "\u{001b}[0m"

fn bold(s: String) -> String {
  esc <> "1m" <> s <> reset
}

fn dim(s: String) -> String {
  esc <> "2m" <> s <> reset
}

fn red(s: String) -> String {
  esc <> "31m" <> s <> reset
}

fn green(s: String) -> String {
  esc <> "32m" <> s <> reset
}

fn yellow(s: String) -> String {
  esc <> "33m" <> s <> reset
}

fn gray(s: String) -> String {
  esc <> "90m" <> s <> reset
}
