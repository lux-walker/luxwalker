public record SearchVisitRoot(bool Success, TermsForService TermsForService);
public record TermsForService(TermForDay[] TermsForDays, int ServiceVariantId);
public record TermForDay(DateTime Day, Term[] Terms);
public record Term(string Clinic);