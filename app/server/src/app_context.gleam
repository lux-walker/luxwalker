import actors/notification_actor.{type Message as NotificationMessage}
import actors/search_registry.{type Message as RegistryMessage}
import config.{type AppConfig}
import gleam/erlang/process

pub type Actors {
  Actors(
    search_registry: process.Subject(RegistryMessage),
    notification: process.Subject(NotificationMessage),
  )
}

pub type AppContext {
  AppContext(actors: Actors, config: AppConfig)
}

pub type RequestAppContext {
  RequestAppContext(user_email: String)
}
