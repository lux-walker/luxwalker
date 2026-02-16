import lustre/attribute
import lustre/element
import lustre/element/html
import wisp

pub fn serve_page() -> wisp.Response {
  let page = hello_page()
  let html_string = element.to_document_string(page)

  wisp.ok()
  |> wisp.html_body(html_string)
}

fn hello_page() -> element.Element(Nil) {
  html.html([], [
    html.head([], [
      html.title([], "Hello World"),
      html.meta([attribute.attribute("charset", "utf-8")]),
    ]),
    html.body([], [
      html.div([attribute.id("app")], [element.text("Loading...")]),
      html.script(
        [],
        "
        fetch('/api')
          .then(res => res.json())
          .then(data => {
            document.getElementById('app').innerHTML =
              '<h1>' + data.message + '</h1>';
          });
        ",
      ),
    ]),
  ])
}
