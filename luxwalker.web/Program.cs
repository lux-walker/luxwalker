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

    scheduler.Schedule<KeepAliveBackgroundTask>()
             .Cron("*/5 * * * *")
             .RunOnceAtStart();

    scheduler.Schedule<VisitSearchBackgroundTask>()
                 .EveryFiveMinutes()
                 .RunOnceAtStart();


});
app.UseSwagger();
app.UseSwaggerUI();
app.UseHttpsRedirection();

app.MapEndpoints();
app.Run();
