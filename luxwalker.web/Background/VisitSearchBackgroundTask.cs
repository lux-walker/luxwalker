using System.Net;
using Coravel.Invocable;
using static EmailSenderFactory;

enum Result
{
    NoResult,
    Sent
}

public class VisitSearchBackgroundTask : IInvocable
{
    private readonly ILogger _logger;
    private readonly EmailSenderFactory _emailSender;
    private readonly Dictionary<Guid, TimeSpan> _toManyRequestsDictionary = new();
    private DateTime? _processingTime;

    public VisitSearchBackgroundTask(ILogger<VisitSearchBackgroundTask> logger, EmailSenderFactory emailSender)
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

        if (_processingTime is not null)
        {
            var delay = DateTime.Now - _processingTime.Value;
            _logger.LogWarning($"Processing previous request since: {delay}");
            return;
        }

        _processingTime = DateTime.Now;

        try
        {
            _logger.LogInformation($"Processing {requests.Count} requests");
            await ProcessRequestsAsync(requests);
        }
        finally
        {
            _processingTime = null;
        }
    }

    private Task ProcessRequestsAsync(IReadOnlyCollection<LuxwalkerRequest> requests)
    => _emailSender.Authenticate(async sendEmail =>
    {
        var tasks = requests.Select(x => ProcessRequestAsync(x, sendEmail)).ToList();
        await Task.WhenAll(tasks);
    });

    private async Task ProcessRequestAsync(LuxwalkerRequest request, EmailSender emailSender)
    {
        _toManyRequestsDictionary.TryGetValue(request.Id, out var delay);
        if (delay > TimeSpan.Zero)
        {
            _logger.LogWarning($"Too many requests for {request.Login}. Waiting {delay}");
            await Task.Delay(delay);
        }

        try
        {
            var result = await FindVisitsAndSendEMail(request, emailSender);
            if (result == Result.NoResult)
            {
                return;
            }

            _toManyRequestsDictionary.Remove(request.Id);
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
        {
            var newDelay = delay == TimeSpan.Zero ? TimeSpan.FromMinutes(1) : delay * 2;
            _toManyRequestsDictionary[request.Id] = newDelay;
            _logger.LogWarning($"Too many requests for {request.Login}. Next Waiting {delay}");

            if (newDelay > TimeSpan.FromDays(1))
            {
                await emailSender.SendErrorAsync(ex);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error processing request {request.Id}");
            await emailSender.SendErrorAsync(ex);
        }
    }

    private async Task<Result> FindVisitsAndSendEMail(LuxwalkerRequest request, EmailSender emailSender)
    {
        var luxmed = await LuxmedClient.LoginAsync(request.Login, request.Password);
        var variant = await luxmed.FindVariantAsync(request.Service);
        if (variant is null)
        {
            _logger.LogWarning($"Service {request.Service} not found");
            return Result.NoResult;
        }

        var days = await luxmed.SearchForVisitsAsync(variant, request.Doctor?.Id);
        if (days.Length == 0)
        {
            _logger.LogWarning($"No available visits for service {request.Service}");
            return Result.NoResult;
        }

        await emailSender.SendMessageAsync(request);
        Exchange.Requests.Remove(request);
        return Result.Sent;
    }
}