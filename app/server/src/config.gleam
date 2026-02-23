import clients/email_client.{type EmailConfig, EmailConfig}
import dot_env as dot
import envoy
import gleam/io
import gleam/result

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
  AppConfig(email: EmailConfig, environment: Environment, ntfy_topic: String)
}

pub fn load() -> Result(AppConfig, ConfigError) {
  load_env_file()

  use email_config <- result.try(load_email_config())
  use ntfy_topic <- result.try(
    envoy.get("NTFY_TOPIC")
    |> result.replace_error(MissingEnvVar("NTFY_TOPIC")),
  )
  let environment = get_environment()
  Ok(AppConfig(
    email: email_config,
    environment: environment,
    ntfy_topic: ntfy_topic,
  ))
}

fn load_env_file() -> Nil {
  dot.new()
  |> dot.set_path(".env")
  |> dot.load

  io.println("Attempted to load .env file")
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
