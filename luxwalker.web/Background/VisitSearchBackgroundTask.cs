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

    public VisitSearchBackgroundTask(ILogger<VisitSearchBackgroundTask> logger, EmailSenderFactory emailSender)
    {
        _logger = logger;
        _emailSender = emailSender;
    }

    public Task Invoke()
    {
        IReadOnlyCollection<LuxwalkerRequest> requests = Exchange.Requests.AsReadOnly();
        if (requests.Count == 0)
        {
            _logger.LogInformation("No requests to process");
            return Task.CompletedTask;
        }

        _logger.LogInformation($"Processing {requests.Count} requests");
        ProcessRequestsAsync(requests);
        return Task.CompletedTask;
    }

    private void ProcessRequestsAsync(IReadOnlyCollection<LuxwalkerRequest> requests)
    {
        foreach (var request in requests)
        {
            Visiter.Visit(request, async token => await _emailSender.Authenticate(async sendEmail =>
            {
                await FindVisitsAndSendEMail(request, sendEmail);
            }));
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