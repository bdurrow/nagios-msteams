# nagios-msteams
A Nagios plugin to send notifications to MS teams

## prerequisites

These perl modules need to be installed.

 - HTTP::Request
 - LWP::UserAgent
 - LWP::Protocol::https
 - JSON
 - URI (installed with LWP)

## usage

`--webhook` or `--webhook_file` is required. `--webhook_file` names a file whose first line is the webhook URL;
use it in production so the URL (a credential) is not on the command line, where `ps` and logs can show it.
Make the file readable only by the Nagios user (`chmod 600`).
If the file is missing, unreadable or empty, the script prints one line and exits 1.
`--nagios_url` to add "View Host" / "View Service" links in the notification.
`--card adaptive|messagecard` selects the payload. The default, `adaptive`, is an Adaptive Card (version 1.4) for
Teams Workflows webhooks; `messagecard` sends the old Office 365 connector MessageCard (Workflows show it without buttons).

The script exits 0 when the webhook answers 2xx. Otherwise it prints one line (webhook host and HTTP status) and
exits 1. The request and response are logged on stderr, with the webhook path and query (which hold the
signature) replaced by `/***` everywhere in that log (only the webhook host is shown), including environment macros that carry the URL.

```
export NAGIOS_HOSTALIAS="hoge101" NAGIOS_SERVICEDESC="http" NAGIOS_SERVICESTATE="WARNING" NAGIOS_SERVICEOUTPUT="test output"
./nagios-msteams.pl --webhook 'https://your incoming webhook url'
```

Proxy environment variables can be specified using lowercase environment variables ending in "*_proxy".

```
export http_proxy="http://proxy.example.com/"
export no_proxy="localhost"
```

## Teams Workflows webhook

Office 365 connectors (incoming webhooks) in Teams were switched off in May 2026. Create a Workflows webhook instead:

1. Channel: in the channel, choose "..." > Workflows and pick the template "Post to a channel when a webhook request
   is received". Chat: in Teams Workflows pick "Post to a chat when a webhook request is received"; the cards arrive
   from the Flow bot in a chat with the person you choose.
2. Finish the template and copy the webhook URL it shows. Treat the URL as a secret: anyone who has it can post to
   that channel or chat. Keep it out of version control.
3. Add a co-owner: a workflow belongs to the person who created it and stops working if that account is removed.
   In Power Automate, open the flow and add a co-owner (a second admin, or a shared service account).
4. Mobile banners: Teams mobile shows an Adaptive Card notification as just "Card". The payload has a top-level
   plain-text `summary` (for example `db-1/PostgreSQL is CRITICAL`). To get a readable banner, add a
   "Post message in a chat or channel" step before the card step with the message `@{triggerBody()?['summary']}`.

Workflows accept up to 28 KB per request (the script cuts long plugin output to stay under it) and throttle more than
4 requests per second.

Example Nagios command (the script reads the `NAGIOS_*` environment macros, so `enable_environment_macros=1`
must be set in nagios.cfg):

```
define command {
    command_name    notify-service-by-teams
    command_line    /usr/local/nagios/libexec/nagios-msteams.pl --webhook_file '/etc/nagios/teams-webhooks/$CONTACTNAME$.url' --nagios_url 'https://nagios.example.com/nagios'
}
```

## installation

1. place the script in nagios plugin directory
2. `chmod +x <path to Nagios plugin>/nagios-msteams.pl`
3. configure commands, contacts


# Reference

https://adaptivecards.io/explorer/
https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference?ranMID=24542&ranEAID=je6NUbpObpQ&ranSiteID=je6NUbpObpQ-M2yBpYvoiCsKiucg39ve7Q