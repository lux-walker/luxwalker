import clients/email_client.{type EmailConfig, EmailConfig}
import dot_env as dot
import envoy
import gleam/bool
import gleam/result
import utils/log.{type Logger}

pub type Environment {
  Development
  Production
}

pub fn get_environment() -> Environment {
  case envoy.get("GLEAM_ENV") {
    Ok(environment) ->
      case environment {
        "development" -> Development
        "production" -> Production
        _ -> Production
      }
    Error(_) -> Production
  }
}

pub type ConfigError {
  MissingEnvVar(name: String)
  InvalidValue(name: String, reason: String)
}

pub type AppConfig {
  AppConfig(
    email: EmailConfig,
    environment: Environment,
    ntfy_topic: String,
    skip_notifications: Bool,
  )
}

pub fn load(logger: Logger) -> Result(AppConfig, ConfigError) {
  load_env_file(logger)

  use email_config <- result.try(load_email_config())
  use ntfy_topic <- result.try(
    envoy.get("NTFY_TOPIC")
    |> result.replace_error(MissingEnvVar("NTFY_TOPIC")),
  )
  let environment = get_environment()
  let skip_notifications = case envoy.get("SKIP_NOTIFICATIONS") {
    Ok("true") -> True
    _ -> False
  }
  Ok(AppConfig(
    email: email_config,
    environment: environment,
    ntfy_topic: ntfy_topic,
    skip_notifications: skip_notifications,
  ))
}

pub fn print_config(logger: Logger, config: AppConfig) -> Nil {
  let env = case config.environment {
    Development -> "development"
    Production -> "production"
  }
  log.info(logger, "config_loaded", [
    #("environment", env),
    #("ntfy_topic", config.ntfy_topic),
    #("skip_notifications", bool.to_string(config.skip_notifications)),
    #("email_host", config.email.smtp_host),
    #("email_from", config.email.from_name <> " <" <> config.email.from_email <> ">"),
  ])
}

fn load_env_file(logger: Logger) -> Nil {
  dot.new()
  |> dot.set_path(".env")
  |> dot.load

  log.info(logger, "env_file_loaded", [#("path", ".env")])
}

fn load_email_config() -> Result(EmailConfig, ConfigError) {
  use username <- result.try(
    envoy.get("GMAIL_USERNAME")
    |> result.replace_error(MissingEnvVar("GMAIL_USERNAME")),
  )

  use password <- result.try(
    envoy.get("GMAIL_PASSWORD")
    |> result.replace_error(MissingEnvVar("GMAIL_PASSWORD")),
  )

  Ok(EmailConfig(
    smtp_host: "smtp.gmail.com",
    smtp_port: 587,
    username: username,
    password: password,
    from_email: "luxmedwalker@gmail.com",
    from_name: "Luxwalker",
  ))
}

pub fn print_error(error: ConfigError) -> String {
  case error {
    MissingEnvVar(name) -> "Missing environment variable: " <> name
    InvalidValue(name, reason) ->
      "Invalid config for " <> name <> ": " <> reason
  }
}
