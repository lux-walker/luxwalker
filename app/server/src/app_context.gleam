import actors/search_registry.{type Message as RegistryMessage}
import config.{type AppConfig}
import gleam/erlang/process

pub type AppContext {
  AppContext(
    search_registry: process.Subject(RegistryMessage),
    config: AppConfig,
  )
}
