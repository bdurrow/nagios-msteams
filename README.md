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
The request and response are logged on stderr with the webhook path and query (which hold the signature)
replaced by `/***`, so only the webhook host is shown; this includes environment macros that carry the URL.
`--nagios_url` to add "View Host" / "View Service" links in the notification.

The script exits 0 when the webhook answers 2xx. Otherwise it prints one line (webhook host and HTTP status) and
exits 1.

```
export NAGIOS_HOSTALIAS="hoge101" NAGIOS_SERVICEDESC="http" NAGIOS_SERVICESTATE="WARNING" NAGIOS_SERVICEOUTPUT="test output"
./nagios-msteams.pl --webhook 'https://your incoming webhook url'
```

Proxy environment variables can be specified using lowercase environment variables ending in "*_proxy".

```
export http_proxy="http://proxy.example.com/"
export no_proxy="localhost"
```

## installation

1. place the script in nagios plugin directory
2. `chmod +x <path to Nagios plugin>/nagios-msteams.pl`
3. configure commands, contacts


# Reference

https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference?ranMID=24542&ranEAID=je6NUbpObpQ&ranSiteID=je6NUbpObpQ-M2yBpYvoiCsKiucg39ve7Q