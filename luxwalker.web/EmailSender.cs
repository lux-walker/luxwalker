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


    public async Task SendAsync(Func<Func<string, Task>, Task> sendAction)
    {
        using var client = new MailKit.Net.Smtp.SmtpClient();
        await client.ConnectAsync("smtp.gmail.com", 587, false);
        await client.AuthenticateAsync(_login, _password);
        Func<string, Task> sender = async to =>
        {
            var email = new MimeMessage();

            email.From.Add(new MailboxAddress("Luxwalker", "luxmedwalker@gmail.com"));
            email.To.Add(new MailboxAddress("", to));

            email.Subject = "Nowe terminy w Luxmedzie!";
            email.Body = new TextPart(MimeKit.Text.TextFormat.Html)
            {
                Text = "<b>Pojawiły się nowe terminy w Luxmedzie!</b>"
            };

            await client.SendAsync(email);
        };

        await sendAction(sender);
    }
}