import gleam/option.{type Option}
import routing.{type Route}
import rsvp
import shared/types.{
  type AppSettings, type CreateAppointmentRequest, type SearchSummary,
  CreateAppointmentRequest, Doctor,
}

pub fn empty_form() -> CreateAppointmentRequest {
  CreateAppointmentRequest(
    password: "",
    service: "",
    doctor: Doctor(first_name: "", last_name: ""),
    notification_email: "",
  )
}

pub type Model {
  Model(
    route: Route,
    searches: List(SearchSummary),
    form: CreateAppointmentRequest,
    user_email: String,
    app_settings: Option(AppSettings),
  )
}

pub type FormField {
  Password
  Service
  DoctorFirstName
  DoctorLastName
  NotificationEmail
}

pub fn update_field(
  form: CreateAppointmentRequest,
  field: FormField,
  value: String,
) -> CreateAppointmentRequest {
  case field {
    Password -> CreateAppointmentRequest(..form, password: value)
    Service -> CreateAppointmentRequest(..form, service: value)
    DoctorFirstName ->
      CreateAppointmentRequest(
        ..form,
        doctor: Doctor(..form.doctor, first_name: value),
      )
    DoctorLastName ->
      CreateAppointmentRequest(
        ..form,
        doctor: Doctor(..form.doctor, last_name: value),
      )
    NotificationEmail ->
      CreateAppointmentRequest(..form, notification_email: value)
  }
}

pub type AppointmentFormAction {
  UpdateField(field: FormField, value: String)
  Submit
}

pub type HttpRequest {
  SearchRequestSubmitted(Result(String, rsvp.Error))
  SearchesFetched(Result(List(SearchSummary), rsvp.Error))
  ConfigFetched(Result(AppSettings, rsvp.Error))
  SearchRerun(Result(String, rsvp.Error))
}

pub type EmailFormAction {
  EmailInput(String)
  EmailSubmit
}

pub type Msg {
  OnRouteChange(Route)
  OnHttpRequest(HttpRequest)
  AppointmentForm(AppointmentFormAction)
  EmailForm(EmailFormAction)
  RerunSearch(id: String)
}
