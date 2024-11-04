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

            app.MapPost("api/walker", async (
                  [FromBody] CreateLuxwalkerRequest request,
                  [FromServices] EmailSenderFactory emailSender) =>
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

                  var model = LuxwalkerRequest.Create(request, doctor);
                  try
                  {
                        return await emailSender.Authenticate(async sendEmail =>
                        {
                              var result = await RequestHandler.HandleAsync(luxmed, model, sendEmail);
                              return result switch
                              {
                                    RequestHandlerResult.EMAIL_SENT => Results.Ok("Email has been sent"),
                                    RequestHandlerResult.BOOKED_ON_BEHALF => Results.Ok("Booked on behalf"),
                                    RequestHandlerResult.VARIANT_NOT_FOUND => Results.NotFound($"Variant {request.Service} not found"),
                                    RequestHandlerResult.NO_APPOINTMENTS_FOUND => Results.NotFound($"No appointments found for {request.Service}"),
                                    RequestHandlerResult.BOOK_ON_BEHALF_FAILED_EMAIL_SENT => Results.Ok("Book on behalf failed, email has been sent"),
                                    _ => Results.BadRequest("Unknown error")
                              };
                        });
                  }
                  catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.TooManyRequests)
                  {
                        Console.WriteLine("To many requests, but accepting");
                  }

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