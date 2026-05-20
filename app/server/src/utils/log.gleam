import gleam/list

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
  ffi_log_info(event, list.append(logger.fields, extra))
}

pub fn warn(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  ffi_log_warn(event, list.append(logger.fields, extra))
}

pub fn error(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  ffi_log_error(event, list.append(logger.fields, extra))
}

pub fn debug(
  logger: Logger,
  event: String,
  extra: List(#(String, String)),
) -> Nil {
  ffi_log_debug(event, list.append(logger.fields, extra))
}

pub fn configure() -> Nil {
  ffi_configure()
}

@external(erlang, "luxwalker_log_ffi", "log_info")
fn ffi_log_info(event: String, fields: List(#(String, String))) -> Nil

@external(erlang, "luxwalker_log_ffi", "log_warn")
fn ffi_log_warn(event: String, fields: List(#(String, String))) -> Nil

@external(erlang, "luxwalker_log_ffi", "log_error")
fn ffi_log_error(event: String, fields: List(#(String, String))) -> Nil

@external(erlang, "luxwalker_log_ffi", "log_debug")
fn ffi_log_debug(event: String, fields: List(#(String, String))) -> Nil

@external(erlang, "luxwalker_log_ffi", "configure")
fn ffi_configure() -> Nil
