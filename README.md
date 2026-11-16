# nagios-msteams
A Nagios plugin to send notifications to MS teams

## prerequisites

These perl modules need to be installed.

 - HTTP::Request
 - LWP::UserAgent
 - LWP::Protocol::https
 - JSON

## usage

`--webhook` is required option.
`--nagios_url` to add a link in the notification.
`--card messagecard|adaptive` selects the payload. The default, `messagecard`, is the Office 365 connector
MessageCard; Teams Workflows webhooks show it without buttons. `adaptive` sends an Adaptive Card (version 1.4)
with buttons; use it with Teams Workflows (see below).

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

Office 365 connectors (incoming webhooks) in Teams were switched off in May 2026. Create a Workflows webhook instead,
and run the script with `--card adaptive`:

1. Channel: in the channel, choose "..." > Workflows and pick the template "Send webhook alerts to a channel".
   Chat: in Teams Workflows pick "Post to a chat when a webhook request is received" (not offered to every
   organization type); the cards arrive from the Flow bot in a chat with the person you choose.
2. Finish the template and copy the webhook URL it shows. Treat the URL as a secret: anyone who has it can post to
   that channel or chat. Keep it out of version control.
3. Add a co-owner: a workflow belongs to the person who created it and stops working if that account is removed.
   In Power Automate, open the flow and add a co-owner (a second admin, or a shared service account).
4. Mobile banners: Teams mobile shows an Adaptive Card notification as just "Card". The payload has a top-level
   plain-text `summary` (for example `db-1/PostgreSQL is CRITICAL`). To get a readable banner, add a
   "Post message in a chat or channel" step before the card step with the message `@{triggerBody()?['summary']}`.

Workflows accept up to 28 KB per request and throttle more than 4 requests per second.

Example Nagios command (the script reads the `NAGIOS_*` environment macros, so `enable_environment_macros=1`
must be set in nagios.cfg):

```
define command {
    command_name    notify-service-by-teams
    command_line    /usr/local/nagios/libexec/nagios-msteams.pl --webhook '$_CONTACTWEBHOOKURL$' --card adaptive --nagios_url 'https://nagios.example.com/nagios'
}
```

## installation

1. place the script in nagios plugin directory
2. `chmod +x <path to Nagios plugin>/nagios-msteams.pl`
3. configure commands, contacts


# Reference

https://adaptivecards.io/explorer/
https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference?ranMID=24542&ranEAID=je6NUbpObpQ&ranSiteID=je6NUbpObpQ-M2yBpYvoiCsKiucg39ve7Q