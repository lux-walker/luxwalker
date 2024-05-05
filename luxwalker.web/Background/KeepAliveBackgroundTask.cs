using Coravel.Invocable;

public class KeepAliveBackgroundTask : IInvocable
{
    private readonly ILogger<KeepAliveBackgroundTask> _logger;
    private readonly HttpClient _httpClient;

    public KeepAliveBackgroundTask(ILogger<KeepAliveBackgroundTask> logger)
    {
        _logger = logger;
        _httpClient = new HttpClient();
    }

    public async Task Invoke()
    {
        HttpResponseMessage response = await _httpClient.GetAsync("https://luxwalker.onrender.com/api/keep-alive");
        response.EnsureSuccessStatusCode();
        _logger.LogInformation("Keep-alive request sent successfully.");
    }
}