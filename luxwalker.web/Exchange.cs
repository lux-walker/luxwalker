
public static class Exchange
{
    private record HibernatedRequest(LuxwalkerRequest Request, DateTime HibernationDate);
    private static List<LuxwalkerRequest> _requests { get; } = new();
    private static List<HibernatedRequest> _hibernatedRequests { get; } = new();

    public static IReadOnlyCollection<LuxwalkerRequest> Requests => _requests.AsReadOnly();

    public static void Add(LuxwalkerRequest request)
    {
        _requests.Add(request);
    }

    public static void Remove(LuxwalkerRequest request)
    {
        _requests.Remove(request);
    }

    public static void Hibernate(LuxwalkerRequest request)
    {
        _requests.Remove(request);
        var hibernatedRequest = _hibernatedRequests.Find(x =>
        {
            var isSameLogin = x.Request.Login.ToLower() == request.Login.ToLower();
            var isSameService = x.Request.Service.ToLower() == request.Service.ToLower();
            return isSameLogin && isSameService;
        });

        if (hibernatedRequest is not null)
        {
            _hibernatedRequests.Remove(hibernatedRequest);
        }

        _hibernatedRequests.Add(new HibernatedRequest(request, DateTime.Now));
    }

    public static bool Dehibernate(string login, string service)
    {
        var hibernatedRequest = _hibernatedRequests.Find(x => x.Request.Login.ToLower() == login.ToLower() && x.Request.Service.ToLower() == service.ToLower());
        if (hibernatedRequest is not null)
        {
            _hibernatedRequests.Remove(hibernatedRequest);
            _requests.Add(hibernatedRequest.Request);
            return true;
        }

        return false;
    }
}
