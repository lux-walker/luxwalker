import lustre/attribute.{class, placeholder, type_, value}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, h2, input, label}
import lustre/event.{on_input, on_submit}
import ui_types.{type Model, type Msg}

pub fn view(model: Model) -> Element(Msg) {
  form(
    [
      class("bg-white rounded-xl shadow-sm border border-slate-200 p-6"),
      on_submit(fn(_) { ui_types.EmailForm(ui_types.EmailSubmit) }),
    ],
    [
      h2([class("text-lg font-semibold text-slate-800 mb-4")], [
        text("Enter your email"),
      ]),
      div([], [
        label([class("block text-sm font-medium text-slate-700 mb-1")], [
          text("Email"),
        ]),
        input([
          type_("email"),
          value(model.user_email),
          placeholder("you@example.com"),
          class(
            "w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 placeholder:text-slate-400",
          ),
          on_input(fn(v) { ui_types.EmailForm(ui_types.EmailInput(v)) }),
        ]),
      ]),
      button(
        [
          type_("submit"),
          class(
            "mt-6 w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2.5 px-4 rounded-lg transition-colors cursor-pointer",
          ),
        ],
        [text("Continue")],
      ),
    ],
  )
}
