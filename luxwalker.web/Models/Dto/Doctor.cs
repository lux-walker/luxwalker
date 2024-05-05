public record DoctorRoot(Doctor[] Doctors);

public record Doctor(string FirstName, string LastName, int Id);