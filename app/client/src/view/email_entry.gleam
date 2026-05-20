import lustre/attribute.{class, placeholder, type_, value}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, h2, input, label}
import lustre/event.{on_input, on_submit}
import ui_types.{type Model, type Msg}

pub fn view(model: Model) -> Element(Msg) {
  form(
    [
      class("bg-surface rounded-xl shadow-sm border border-hl-med p-6"),
      on_submit(fn(_) { ui_types.EmailForm(ui_types.EmailSubmit) }),
    ],
    [
      h2([class("text-lg font-semibold text-text mb-4")], [
        text("Enter your email"),
      ]),
      div([], [
        label([class("block text-sm font-medium text-subtle mb-1")], [
          text("Email"),
        ]),
        input([
          type_("email"),
          value(model.user_email),
          placeholder("you@example.com"),
          class(
            "w-full px-3 py-2 bg-base border border-hl-high rounded-lg text-sm text-text focus:outline-none focus:ring-2 focus:ring-pine focus:border-pine placeholder:text-muted",
          ),
          on_input(fn(v) { ui_types.EmailForm(ui_types.EmailInput(v)) }),
        ]),
      ]),
      button(
        [
          type_("submit"),
          class(
            "mt-6 w-full bg-pine hover:bg-foam text-surface font-medium py-2.5 px-4 rounded-lg transition-colors cursor-pointer",
          ),
        ],
        [text("Continue")],
      ),
    ],
  )
}
