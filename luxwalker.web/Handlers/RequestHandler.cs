
using static EmailSenderFactory;

public enum RequestHandlerResult
{
    VARIANT_NOT_FOUND,
    NO_APPOINTMENTS_FOUND,
    EMAIL_SENT,
    BOOK_ON_BEHALF_FAILED_EMAIL_SENT,
    BOOKED_ON_BEHALF
}

public class RequestHandler
{
    public static async Task<RequestHandlerResult> HandleAsync(
        LuxmedClient client,
        LuxwalkerRequest request,
        EmailSender emailSender)
    {
        ServiceVariant? variant = await client.FindVariantAsync(request.Service);
        if (variant is null)
        {
            return RequestHandlerResult.VARIANT_NOT_FOUND;
        }

        var days = await client.SearchForVisitsAsync(variant, request.Doctor?.Id);
        if (days.Length == 0)
        {
            return RequestHandlerResult.NO_APPOINTMENTS_FOUND;
        }

        IEnumerable<Term> allTerms = days.SelectMany(x => x.Terms).Where(x => !x.IsTelemedicine);
        if (allTerms.Count() == 0)
        {
            return RequestHandlerResult.NO_APPOINTMENTS_FOUND;
        }

        if (BookOnBehalfDecider.CanBook(allTerms, out var term))
        {
            var result = await BookOnBehalf(client, variant, term!);
            return await result.MatchAsync(
                async appointment =>
                {
                    await emailSender.SendBookedOnBehalfMessageAsync(request);
                    return RequestHandlerResult.BOOKED_ON_BEHALF;
                },
                async errors =>
                {
                    await emailSender.SendMessageAsync(request);
                    return RequestHandlerResult.BOOK_ON_BEHALF_FAILED_EMAIL_SENT;
                });
        }

        await emailSender.SendMessageAsync(request);
        return RequestHandlerResult.EMAIL_SENT;
    }

    private static async Task<BookedValue> BookOnBehalf(
        LuxmedClient client,
        ServiceVariant variant,
        Term term)
    {
        var lockTerm = await client.LockTermAsync(term, variant);
        var bookedValue = await client.Book(lockTerm, term, variant);
        return bookedValue;
    }
}

public class BookOnBehalfDecider
{
    public static bool CanBook(IEnumerable<Term> terms, out Term? term)
    {
        term = null;
        foreach (var t in terms)
        {
            if (CanBook(t))
            {
                term = t;
                return true;
            }
        }

        return false;
    }

    private static bool CanBook(Term term)
    {
        var now = DateTime.Now;
        return term.DateTimeFrom - now > TimeSpan.FromHours(14);
    }
}