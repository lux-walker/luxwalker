using Coravel.Invocable;

public class VisitSearchBackgroundTask : IInvocable
{
    private readonly ILogger _logger;
    private readonly EmailSender _emailSender;

    public VisitSearchBackgroundTask(ILogger<VisitSearchBackgroundTask> logger, EmailSender emailSender)
    {
        _logger = logger;
        _emailSender = emailSender;
    }

    public async Task Invoke()
    {
        IReadOnlyCollection<LuxwalkerRequest> requests = Exchange.Requests.AsReadOnly();
        if (requests.Count == 0)
        {
            _logger.LogInformation("No requests to process");
            return;
        }

        _logger.LogInformation($"Processing {requests.Count} requests");
        await ProcessRequests(requests);
    }

    private Task ProcessRequests(IReadOnlyCollection<LuxwalkerRequest> requests)
    => _emailSender.SendAsync(async sendEmail =>
    {
        var tasks = requests.Select(x => ProcessRequest(x, sendEmail)).ToList();
        await Task.WhenAll(tasks);
    });

    private async Task ProcessRequest(LuxwalkerRequest request, Func<LuxwalkerRequest, Task> sendEmail)
    {
        var luxmed = await LuxmedClient.LoginAsync(request.Login, request.Password);
        var variant = await luxmed.FindVariantAsync(request.Service);
        if (variant is null)
        {
            _logger.LogWarning($"Service {request.Service} not found");
            return;
        }

        var days = await luxmed.SearchForVisitsAsync(variant, request.Doctor?.Id);
        if (days.Length == 0)
        {
            _logger.LogWarning($"No available visits for service {request.Service}");
            return;
        }

        await sendEmail(request);
        Exchange.Requests.Remove(request);
    }
}