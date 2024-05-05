using Coravel;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddScheduler();
builder.Services.AddSingleton<KeepAliveBackgroundTask>();
var app = builder.Build();

app.Services.UseScheduler(scheduler =>
{
    scheduler.Schedule<KeepAliveBackgroundTask>()
                 .Cron("*/13 * * * *")
                 .RunOnceAtStart();
});
app.UseSwagger();
app.UseSwaggerUI();
app.UseHttpsRedirection();

app.MapEndpoints();
app.Run();
