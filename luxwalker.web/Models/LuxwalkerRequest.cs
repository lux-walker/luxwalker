
using System.Text.Json.Serialization;

public record LuxwalkerRequest
{
    [JsonIgnore]
    public string Login { get; init; }

    [JsonIgnore]
    public string Password { get; init; }
    public string Service { get; init; }

    [JsonIgnore]
    public string NotificationEmail { get; init; }

    public Guid Id { get; private init; }

    public Doctor? Doctor { get; init; }

    public LuxwalkerRequest()
    {
        Id = Guid.NewGuid();
    }

    public static LuxwalkerRequest Create(CreateLuxwalkerRequest request, Doctor? doctor)
    => new LuxwalkerRequest
    {
        Login = request.Login,
        Password = request.Password,
        Service = request.Service,
        NotificationEmail = request.NotificationEmail,
        Doctor = doctor
    };
}