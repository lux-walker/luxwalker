using Coravel;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddEnvironmentVariables();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddScheduler();
builder.Services.AddSingleton<KeepAliveBackgroundTask>();
builder.Services.AddSingleton<VisitSearchBackgroundTask>();

string login = builder.Configuration.GetValue<string>("GMAIL_USERNAME")!;
string password = builder.Configuration.GetValue<string>("GMAIL_PASSWORD")!;
builder.Services.AddSingleton(new EmailSender(login, password));

var app = builder.Build();


app.Services.UseScheduler(scheduler =>
{
    if (app.Environment.IsDevelopment())
    {
        scheduler.Schedule<KeepAliveBackgroundTask>()
                 .Cron("*/13 * * * *")
                 .RunOnceAtStart();
    }

    scheduler.Schedule<VisitSearchBackgroundTask>()
                 .EveryMinute()
                 .RunOnceAtStart();


});
app.UseSwagger();
app.UseSwaggerUI();
app.UseHttpsRedirection();

app.MapEndpoints();
app.Run();
