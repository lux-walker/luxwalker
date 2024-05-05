
using System.ComponentModel.DataAnnotations;

public record DoctorDto()
{
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
}

public record CreateLuxwalkerRequest
{
    public required string Login { get; set; }
    public required string Password { get; set; }
    public required string Service { get; set; }

    public DoctorDto? Doctor { get; set; }

    [EmailAddress]
    public required string NotificationEmail { get; set; }
}