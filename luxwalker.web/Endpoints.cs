using System.Net;
using System.Net.Http.Headers;
using System.Net.Mail;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using MiniValidation;

using MailKit.Net.Smtp;
using MailKit;
using MimeKit;


public static class Endpoints
{
      public static void MapEndpoints(this WebApplication app)
      {
            app.MapGet("api/keep-alive", () => Results.Ok())
               .ExcludeFromDescription();

            app.MapPost("api/walker", async ([FromBody] CreateLuxwalkerRequest request) =>
            {
                  if (!MiniValidator.TryValidate(request, out var errors))
                  {
                        return Results.ValidationProblem(errors);
                  }

                  var luxmed = await LuxmedClient.LoginAsync(request.Login, request.Password);
                  var variant = await luxmed.FindVariantAsync(request.Service);

                  Doctor? doctor = null;
                  if (request.Doctor is not null)
                  {
                        doctor = await luxmed.FindDoctor(variant.Id, request.Doctor.FirstName, request.Doctor.LastName);
                        if (doctor is null)
                        {
                              return Results.NotFound($"Doctor {request.Doctor.FirstName} {request.Doctor.LastName} not found");
                        }
                  }

                  if (variant is null)
                  {
                        return Results.NotFound($"Service {request.Service} not found");
                  }

                  try
                  {
                        var days = await luxmed.SearchForVisitsAsync(variant, doctor?.Id);
                        /*  var ordered = days
                               .SelectMany(x => x.Terms)
                               .OrderByDescending(x => x.DateTimeFrom)
                               .ToList();

                         var first = ordered.FirstOrDefault(x =>
                         {
                               return x.Doctor.LastName == "Chudzik".ToUpper() && x.DateTimeFrom.Day == 24 && TimeOnly.FromDateTime(x.DateTimeFrom) == TimeOnly.Parse("07:30");
                         });

                         LockTermResult reservation = await luxmed.LockTermAsync(first, variant);
                         await luxmed.Book(reservation, first, variant); */
                  }
                  catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
                  {
                        Console.WriteLine("To many requests, but accepting");
                  }

                  var model = LuxwalkerRequest.Create(request, doctor);
                  Exchange.Add(model);
                  return Results.Json(model);
            })
            .WithDescription("Use this endpoint to start searching from appointments")
            .WithOpenApi();

            app.MapGet("api/walker/{email}", (string email) => Exchange.Requests.Where(x => x.NotificationEmail == email).ToList())
               .WithDescription("Return all requests for given email")
               .WithOpenApi();

            app.MapDelete("api/walker/{id}", (Guid id) =>
            {
                  var request = Exchange.Requests.FirstOrDefault(x => x.Id == id);
                  if (request is not null)
                  {
                        Exchange.Remove(request);
                        Visiter.Delete(id);
                        return Results.Ok();
                  }

                  return Results.NotFound();
            });

            app.MapPost("api/walker/{email}/service/{service}", (string email, string service) => Exchange.Dehibernate(email, service))
               .WithDescription("Repeat search for last processed service")
               .WithOpenApi();

            app.MapPost("api/walker/process/{id}/restart", (Guid id) =>
            {
                  Visiter.Restart(id);
                  return Results.Ok();
            });

            app.MapGet("api/walker/process", Visiter.GetVisits)
               .WithDescription("Return all active visits")
               .WithOpenApi();
      }
}