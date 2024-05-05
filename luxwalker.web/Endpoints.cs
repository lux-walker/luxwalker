public static class Endpoints
{
    public static void MapEndpoints(this WebApplication app)
    {
        app.MapGet("api/keep-alive", () => Results.Ok())
           .ExcludeFromDescription();


        app.MapPost("api/walker", () => Results.Ok())
            .WithDescription("Use this endpoint to start searching from appointments")
            .WithOpenApi();
    }
}