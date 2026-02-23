import rsvp
import shared/types.{type AppointmentRequest, type SearchSummary, AppointmentRequest, Doctor}

pub type Route {
  CreateSearch
  ActiveSearches
}

pub fn empty_form() -> AppointmentRequest {
  AppointmentRequest(
    login: "",
    password: "",
    service: "",
    doctor: Doctor(first_name: "", last_name: ""),
    notification_email: "",
  )
}

pub type Model {
  Model(route: Route, searches: List(SearchSummary), form: AppointmentRequest)
}

pub type FormField {
  Login
  Password
  Service
  DoctorFirstName
  DoctorLastName
  NotificationEmail
}

pub fn update_field(
  form: AppointmentRequest,
  field: FormField,
  value: String,
) -> AppointmentRequest {
  case field {
    Login -> AppointmentRequest(..form, login: value)
    Password -> AppointmentRequest(..form, password: value)
    Service -> AppointmentRequest(..form, service: value)
    DoctorFirstName ->
      AppointmentRequest(..form, doctor: Doctor(..form.doctor, first_name: value))
    DoctorLastName ->
      AppointmentRequest(..form, doctor: Doctor(..form.doctor, last_name: value))
    NotificationEmail -> AppointmentRequest(..form, notification_email: value)
  }
}

pub type FormAction {
  UpdateField(field: FormField, value: String)
  Submit
}

pub type Msg {
  OnRouteChange(Route)
  Form(FormAction)
  SearchHttpRequestSubmitted(Result(String, rsvp.Error))
  SearchesFetched(Result(List(SearchSummary), rsvp.Error))
}
