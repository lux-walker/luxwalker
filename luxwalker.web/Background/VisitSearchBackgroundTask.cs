using Coravel.Invocable;

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
        IReadOnlyCollection<LuxwalkerRequest> requests = Exchange.Requests;
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
                var luxmed = await LuxmedClient.LoginAsync(request.Login, request.Password);
                var result = await RequestHandler.HandleAsync(luxmed, request, sendEmail);
                Action action = TakePostRequestAction(result, request);
                action();
                return result;
            }));
        }
    }

    private Action TakePostRequestAction(RequestHandlerResult result, LuxwalkerRequest request) => result switch
    {
        RequestHandlerResult.EMAIL_SENT => () => Hibernate(request, $"Email has been sent for {request.Service} {request.NotificationEmail}"),
        RequestHandlerResult.BOOKED_ON_BEHALF => () => Hibernate(request, $"Booked on behalf for {request.Service} {request.NotificationEmail}"),
        RequestHandlerResult.VARIANT_NOT_FOUND => () => _logger.LogWarning($"Variant not found for {request.Service} {request.NotificationEmail}"),
        RequestHandlerResult.NO_APPOINTMENTS_FOUND => () => _logger.LogWarning($"No appointments found for {request.Service} {request.NotificationEmail}"),
        RequestHandlerResult.BOOK_ON_BEHALF_FAILED_EMAIL_SENT => () => Hibernate(request, $"Book on behalf failed for {request.Service} {request.NotificationEmail}. Email has been sent"),
        _ => () => _logger.LogError($"Unknown error for {request.Service} {request.NotificationEmail}")
    };

    private static string Hibernate(LuxwalkerRequest request, string message)
    {
        Exchange.Hibernate(request);
        return message;
    }
}