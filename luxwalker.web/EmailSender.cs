using System.Net;
using MailKit.Net.Smtp;
using MimeKit;

public class EmailSenderFactory
{
    private readonly string _login;
    private readonly string _password;
    private readonly string _emailExceptionNotification;

    public EmailSenderFactory(string login, string password, string emailExceptionNotification)
    {
        _login = login ?? throw new ArgumentNullException(nameof(login));
        _password = password ?? throw new ArgumentNullException(nameof(password));
        _emailExceptionNotification = emailExceptionNotification;
    }


    public async Task<T> Authenticate<T>(Func<EmailSender, Task<T>> sendAction)
    {
        using var client = new SmtpClient();
        await client.ConnectAsync("smtp.gmail.com", 587, false);
        await client.AuthenticateAsync(_login, _password);
        return await sendAction(new EmailSender(client, _emailExceptionNotification));
    }

    public class EmailSender(SmtpClient authenticatedClient, string emailExceptionNotification)
    {
        private static readonly MailboxAddress _from = new("Luxwalker", "luxmedwalker@gmail.com");
        private readonly SmtpClient _authenticatedClient = authenticatedClient;

        public async Task SendErrorAsync(Exception exception)
        {
            var email = new MimeMessage();

            email.From.Add(new MailboxAddress("Luxwalker", "luxmedwalker@gmail.com"));
            email.To.Add(new MailboxAddress("", emailExceptionNotification ?? "luxmedwalker@gmail.com"));

            var (subject, bodyText) = GetErrorText(exception);
            email.Subject = subject;

            email.Body = new TextPart(MimeKit.Text.TextFormat.Html)
            {
                Text = bodyText
            };

            await _authenticatedClient.SendAsync(email);
        }

        public async Task SendBookedOnBehalfMessageAsync(LuxwalkerRequest request)
        {
            var email = new MimeMessage();

            email.From.Add(_from);
            email.To.Add(new MailboxAddress("", request.NotificationEmail));
            email.Subject = $"Zarezerwowano termin {request.Service}";

            var text = $"<b>Zarezerwowano termin {request.Service}. Sprawdź w Luxmedzie!</b>";
            email.Body = new TextPart(MimeKit.Text.TextFormat.Html)
            {
                Text = text
            };

            await _authenticatedClient.SendAsync(email);
        }

        public async Task SendMessageAsync(LuxwalkerRequest request)
        {
            var email = new MimeMessage();

            email.From.Add(_from);
            email.To.Add(new MailboxAddress("", request.NotificationEmail));
            email.Subject = $"Nowe terminy {request.Service} w Luxmedzie!";

            var text = $"<b>Pojawiły się nowe terminy {request.Service} w Luxmedzie!</b>";
            if (request.Doctor is not null)
            {
                text += $"<p> Terminy dla lekarza {request.Doctor.FirstName} {request.Doctor.LastName}</p>";
            }

            email.Body = new TextPart(MimeKit.Text.TextFormat.Html)
            {
                Text = text
            };

            await _authenticatedClient.SendAsync(email);
        }

        private (string subject, string bodyText) GetErrorText(Exception exception) => exception switch
        {
            HttpRequestException ex when ex.StatusCode == HttpStatusCode.TooManyRequests => ("Too many requests", "Too many requests"),
            _ => ("Unhandled Exception", exception.Message)
        };
    }
}
