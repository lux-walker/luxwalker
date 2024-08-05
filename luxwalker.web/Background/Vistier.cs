
using System.Net;

public record VisitActionInfo(
    LuxwalkerRequest request,
    DateTime Start,
    TimeSpan Delay,
    Func<VisitActionInfo, Task> Action,
    Func<CancellationToken, Task> OriginAction,
    CancellationTokenSource CancellationTokenSource);

public class Visiter
{
    private static Dictionary<Guid, VisitActionInfo> _visits = new();

    private static async Task InternalCall(VisitActionInfo info)
    {
        try
        {
            Console.WriteLine($"Visiting {info.request.Service}. Start at {info.Start}. Processing time ${DateTime.Now - info.Start}. Delay {info.Delay}");
            await Task.Delay(info.Delay, info.CancellationTokenSource.Token);
            await info.OriginAction(info.CancellationTokenSource.Token);
            _visits.Remove(info.request.Id);
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
        {
            Console.WriteLine($"Too many requests for {info.request.Service}. Delaying for {info.Delay}");
            var newDelay = info.Delay == TimeSpan.Zero ? TimeSpan.FromDays(1) : info.Delay * 2;
            _visits[info.request.Id] = info with { Delay = newDelay };
            await info.Action(info);
        }
        catch (Exception e)
        {
            Console.WriteLine($"Error while processing {info.request.Service} {e.Message}");
            Console.WriteLine($"Error while processing {info.request.Service}");
            _visits.Remove(info.request.Id);
        }
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
            Visit(visitInfo.request, visitInfo.OriginAction);
        }
    }

    public static void Visit(LuxwalkerRequest request, Func<CancellationToken, Task> visitAction)
    {
        if (_visits.TryGetValue(request.Id, out VisitActionInfo visitInfo))
        {
            return;
        }

        var visit = new VisitActionInfo(request, DateTime.Now, TimeSpan.Zero, InternalCall, visitAction, new());
        _visits[request.Id] = visit;
        visit.Action(visit);
    }
}