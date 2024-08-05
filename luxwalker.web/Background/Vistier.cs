
using System.Net;
using System.Text.Json.Serialization;

public record VisitActionInfo
{
    public LuxwalkerRequest Request { get; init; }
    public DateTime Start { get; init; }
    public TimeSpan Delay { get; init; }

    [JsonIgnore]
    public Func<VisitActionInfo, Task> Action { get; init; }

    [JsonIgnore]
    public Func<CancellationToken, Task> OriginAction { get; init; }

    [JsonIgnore]
    public CancellationTokenSource CancellationTokenSource { get; init; }
}

public class Visiter
{
    private static Dictionary<Guid, VisitActionInfo> _visits = new();

    private static async Task InternalCall(VisitActionInfo info)
    {
        try
        {
            Console.WriteLine($"Visiting {info.Request.Service}. Start at {info.Start}. Processing time ${DateTime.Now - info.Start}. Delay {info.Delay}");
            await Task.Delay(info.Delay, info.CancellationTokenSource.Token);
            await info.OriginAction(info.CancellationTokenSource.Token);
            _visits.Remove(info.Request.Id);
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
        {
            Console.WriteLine($"Too many requests for {info.Request.Service}. Delaying for {info.Delay}");
            var newDelay = info.Delay == TimeSpan.Zero ? TimeSpan.FromDays(1) : info.Delay * 2;
            _visits[info.Request.Id] = info with { Delay = newDelay };
            await info.Action(info);
        }
        catch (Exception e)
        {
            Console.WriteLine($"Error while processing {info.Request.Service} {e.Message}");
            Console.WriteLine($"Error while processing {info.Request.Service}");
            _visits.Remove(info.Request.Id);
        }
    }

    public static VisitActionInfo[] GetVisits()
    {
        return _visits.Values.ToArray();
    }

    public static void Delete(Guid requestId)
    {
        if (_visits.TryGetValue(requestId, out VisitActionInfo visitInfo))
        {
            visitInfo.CancellationTokenSource.Cancel();
        }
    }

    public static void Restart(Guid requestId)
    {
        if (_visits.TryGetValue(requestId, out VisitActionInfo visitInfo))
        {
            visitInfo.CancellationTokenSource.Cancel();
            Visit(visitInfo.Request, visitInfo.OriginAction);
        }
    }

    public static void Visit(LuxwalkerRequest request, Func<CancellationToken, Task> visitAction)
    {
        if (_visits.TryGetValue(request.Id, out VisitActionInfo visitInfo))
        {
            return;
        }

        var visit = new VisitActionInfo
        {
            Request = request,
            Start = DateTime.Now,
            Delay = TimeSpan.Zero,
            Action = InternalCall,
            OriginAction = visitAction,
            CancellationTokenSource = new()
        };

        _visits[request.Id] = visit;
        visit.Action(visit);
    }
}