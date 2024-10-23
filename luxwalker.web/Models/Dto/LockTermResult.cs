public record Valuation(
    int PayerId,
    int ContractId,
    int ProductInContractId,
    int ProductId,
    int? ProductElementId,
    bool RequireReferralForPP,
    int ValuationType,
    float price,
    bool IsReferralRequired,
    bool IsExternalReferralAllowed,
    int? AlternativePrice);

public record LockTermValue(
    int TemporaryReservationId,
    Valuation[] Valuations);
public record LockTermResult(LockTermValue Value);