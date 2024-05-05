using MimeKit;

public class EmailSender
{
    private readonly string _login;
    private readonly string _password;

    public EmailSender(string login, string password)
    {
        _login = login ?? throw new ArgumentNullException(nameof(login));
        _password = password ?? throw new ArgumentNullException(nameof(password));
    }


    public async Task SendAsync(Func<Func<LuxwalkerRequest, Task>, Task> sendAction)
    {
        using var client = new MailKit.Net.Smtp.SmtpClient();
        await client.ConnectAsync("smtp.gmail.com", 587, false);
        await client.AuthenticateAsync(_login, _password);
        Func<LuxwalkerRequest, Task> sender = async request =>
        {
            var email = new MimeMessage();

            email.From.Add(new MailboxAddress("Luxwalker", "luxmedwalker@gmail.com"));
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

            await client.SendAsync(email);
        };

        await sendAction(sender);
    }
}