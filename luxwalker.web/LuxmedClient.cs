using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

public record LockTerm(
        int ServiceVariantId,
        string ServiceVariantName,
        int RoomId,
        int ScheduleId,
        DateTime Date,
        TimeOnly TimeFrom,
        TimeOnly TimeTo,
        int DoctorId,
        Doctor Doctor
    );


public record Book(
    Valuation Valuation,
    int ServiceVariantId,
    int RoomId,
    int TemporaryReservationId,
    DateTime Date,
    TimeOnly TimeFrom,
    int ScheduleId,
    int? ReferralId = null,
    int? EReferralId = null,
    int? ParentReservationId = null,
    bool? ReferralRequired = false,
    int? ValuationId = null
);

class LoginContent
{
    public string Token { get; set; }
}

public record Cookie(string Name, string Value)
{
    public override string ToString() => $"{Name}={Value};";

    public static string Combine(params Cookie[] cookies) => string.Join(' ', cookies.Select(x => x.ToString()));

    public static Cookie[] ParseAsCookie(IEnumerable<string> collection)
    => collection.Select(x =>
    {
        var values = x.Split("=");
        return new Cookie(values[0], string.Join('=', values[1..]));
    }).ToArray();
}

public class LuxmedClient
{
    delegate HttpRequestMessage PrepareRequest(HttpMethod method, string url);
    private static readonly HttpClient _client;
    private readonly PrepareRequest _prepareRequest;

    static LuxmedClient()
    {
        var handler = new HttpClientHandler
        {

            AllowAutoRedirect = false,
            UseCookies = false
        };

        var client = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://portalpacjenta.luxmed.pl", UriKind.RelativeOrAbsolute)
        };
        _client = client;
    }

    private LuxmedClient(PrepareRequest prepareRequest)
    {
        _prepareRequest = prepareRequest;
    }

    public async Task<Doctor?> FindDoctor(int variant, string firstName, string lastName)
    {
        firstName = firstName.ToLower();
        lastName = lastName.ToLower();

        var url = $"PatientPortal/NewPortal/Dictionary/facilitiesAndDoctors?cityId=3&serviceVariantId={variant}";
        var request = _prepareRequest(HttpMethod.Get, url);
        var response = await _client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var responseModel = await response.Content.ReadFromJsonAsync<DoctorRoot>();
        return responseModel?.Doctors?
            .FirstOrDefault(x => x.FirstName.ToLower() == firstName &&
                                 x.LastName.ToLower() == lastName);
    }

    public async Task Book(LockTermResult lockTerm, Term term, ServiceVariant variant)
    {
        Book book = new(
            lockTerm.Value.Valuations.First(),
            variant.Id,
            term.RoomId,
            lockTerm.Value.TemporaryReservationId,
            term.DateTimeFrom.Date,
            TimeOnly.FromDateTime(term.DateTimeFrom),
            term.ScheduleId
        );

        var url = "PatientPortal/NewPortal/reservation/confirm";
        var request = _prepareRequest(HttpMethod.Post, url);
        var json = JsonSerializer.Serialize(book, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        var response = await _client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var message = await response.Content.ReadAsStringAsync();
    }

    public async Task<LockTermResult> LockTermAsync(Term term, ServiceVariant variant)
    {
        var lockTerm = new LockTerm(
            variant.Id,
            variant.Name,
            term.RoomId,
            term.ScheduleId,
            term.DateTimeFrom.Date,
            TimeOnly.FromDateTime(term.DateTimeFrom),
            TimeOnly.FromDateTime(term.DateTimeTo),
            term.Doctor.Id,
            term.Doctor
        );

        var url = "PatientPortal/NewPortal/reservation/lockterm";
        var request = _prepareRequest(HttpMethod.Post, url);
        var json = JsonSerializer.Serialize(lockTerm, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        request.Content = new StringContent(json, Encoding.UTF8, "application/json");

        var response = await _client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<LockTermResult>();
        return result;
    }

    public async Task<ServiceVariant?> FindVariantAsync(string examination)
    {
        var lExamination = examination.ToLower();
        var url = "PatientPortal/NewPortal/Dictionary/serviceVariantsGroups";
        var request = _prepareRequest(HttpMethod.Get, url);
        var response = await _client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var responseModel = await response.Content.ReadFromJsonAsync<ServiceVariantGroup[]>();
        return responseModel?.SelectMany(x => x.Children)?.FirstOrDefault(x => x.Name.ToLower() == lExamination);
    }

    private async Task<TermForDay[]> SearchForVisitsAsync(
        ServiceVariant variant, DateTime from, DateTime to, int? doctorId)
    {
        var queryString = new QueryString();

        if (doctorId.HasValue)
        {
            queryString = queryString.Add("doctorsIds", doctorId.Value.ToString());
        }

        var query = queryString
            .Add("searchPlace.id", "3")
            .Add("searchPlace.name", "Kraków")
            .Add("searchPlace.type", "0")
            .Add("serviceVariantId", variant.Id.ToString())
            .Add("searchDateFrom", from.ToString("yyyy-MM-dd"))
            .Add("searchDateTo", to.ToString("yyyy-MM-dd"))
            .Add("delocalized", "false")
            .ToString();

        string url = "PatientPortal/NewPortal/terms/index" + query;
        var request = _prepareRequest(HttpMethod.Get, url);

        var response = await _client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var responseModel = await response.Content.ReadFromJsonAsync<SearchVisitRoot>();
        var result = responseModel?.TermsForService?.TermsForDays ?? [];
        if (doctorId.HasValue)
        {
            result = result
                     .Where(x =>
                         x.Terms.Any(y => y.Doctor.Id == doctorId))
                     .ToArray();
        }

        return result;
    }

    public async Task<TermForDay[]> SearchForVisitsAsync(ServiceVariant variant, int? doctorId)
    {
        var firstResult = await SearchForVisitsAsync(variant, DateTime.Now, DateTime.Now.AddDays(14), doctorId);
        return firstResult.Length == 0
            ? await SearchForVisitsAsync(variant, DateTime.Now.AddDays(14), DateTime.Now.AddDays(28), doctorId)
            : firstResult;
    }

    public static async Task<LuxmedClient> LoginAsync(string login, string password)
    {
        var url = "PatientPortal/Account/LogIn";
        var json = $$"""{"login":"{{login}}", "password":"{{password}}"}""";

        var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        var response = await _client.SendAsync(request);

        response.EnsureSuccessStatusCode();

        var cookiesStringCollection = response.Headers.GetValues("Set-Cookie");
        var content = await response.Content.ReadFromJsonAsync<LoginContent>();
        if (cookiesStringCollection is null)
        {
            throw new Exception("No cookies in response");
        }

        if (cookiesStringCollection.Count() == 0)
        {
            throw new Exception("No cookies in response");
        }
        var cookies = Cookie.ParseAsCookie(cookiesStringCollection);
        var session = cookies.FirstOrDefault(x => x.Name == "ASP.NET_SessionId")
            ?? throw new Exception("No ASP.NET_SessionId cookie in response");

        PrepareRequest prepareRequest = (HttpMethod method, string url) =>
        {
            var request = new HttpRequestMessage(method, url);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            request.Headers.Add("Cookie", cookiesStringCollection);
            request.Headers.Add("authorization-token", $"Bearer {content.Token}");
            request.Headers.Add("Authorization", $"Bearer {content.Token}");
            return request;
        };

        var forgeryRequest = prepareRequest(HttpMethod.Get, "PatientPortal/NewPortal/security/getforgerytoken");
        var forgeryResponse = await _client.SendAsync(forgeryRequest);
        forgeryResponse.EnsureSuccessStatusCode();
        var forgeryToken = await forgeryResponse.Content.ReadFromJsonAsync<ForgeryToken>();

        PrepareRequest withForgery = (HttpMethod method, string url) =>
        {
            var request = prepareRequest(method, url);
            var cookieToken = forgeryResponse.Headers
            .GetValues("set-cookie")
            .First(x => x.Contains("XSRF-TOKEN"))
            .Split(";")
            .First(x => x.Contains("XSRF-TOKEN"))
            .Split(',')
            .First(x => x.Contains("XSRF-TOKEN"));

            var newCookies = request.Headers.GetValues("Cookie").ToList();
            newCookies.Add(cookieToken);

            request.Headers.Remove("Cookie");
            request.Headers.Add("Cookie", newCookies);
            request.Headers.Add("xsrf-token", forgeryToken.Token);
            return request;
        };

        return new LuxmedClient(withForgery);
    }
}

public record ForgeryToken(string Token);