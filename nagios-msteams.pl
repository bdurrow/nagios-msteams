#!/usr/bin/perl

#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use warnings;
use strict;

use Getopt::Long;
use HTTP::Request::Common qw(POST);
use HTTP::Status qw(is_client_error);
use LWP::UserAgent;
use JSON;

my %nagios;
my @links;
my $webhook = "https://outlook.office365.com/webhook/MISSING";
my $nagios_url = "";
my $card = "messagecard";
my %color = ( 'OK' => '008000', 'WARNING' => 'ffff00', 'UNKNOWN' => '808080','CRITICAL' => 'ff0000',
              'UP' => '008000', 'DOWN' => 'ff0000', 'UNREACHABLE' => 'ff8700');
my %adaptive_color = ( 'OK' => 'Good', 'WARNING' => 'Warning', 'UNKNOWN' => 'Default', 'CRITICAL' => 'Attention',
                       'UP' => 'Good', 'DOWN' => 'Attention', 'UNREACHABLE' => 'Attention');
$nagios{'HOSTNOTES'} = "not defined";


# Webhook debugging options
#use LWP::Protocol::https;
#$IO::Socket::SSL::DEBUG=3;

#
# Get command-line options
#
GetOptions ("webhook=s" => \$webhook, "nagios_url=s" => \$nagios_url, "card=s" => \$card )
or die("Error in command line arguments\n");
die("--card must be messagecard or adaptive\n") unless $card =~ /^(?:adaptive|messagecard)$/;

#
# Read Nagios events
#
while ((my $k, my $v) = each %ENV) {
    next unless $k =~ /^(?:NAGIOS|ICINGA)_(.*)$/;
    $nagios{$1} = $v;
    print STDERR "$1 is $nagios{$1}\n";
}

#
# Collect notification fields
#
if (not length($nagios{'SERVICESTATE'})) {
    # if service state env is not defnined or empty, event is host notification.
    $nagios{'SERVICEDESC'} = "host status";
    $nagios{'SERVICESTATE'} = $nagios{'HOSTSTATE'};
    $nagios{'SERVICEOUTPUT'} = $nagios{'HOSTOUTPUT'};
    $nagios{'LONGSERVICEOUTPUT'} = $nagios{'LONGHOSTOUTPUT'};
}
if (not length($nagios{'HOSTALIAS'})) {
    $nagios{'HOSTALIAS'} = $nagios{'HOSTNAME'};
}
# plain-text one-liner: MessageCard title, and the text a workflow can post before the card
my $title = "$nagios{'HOSTALIAS'}/$nagios{'SERVICEDESC'} is $nagios{'SERVICESTATE'}";
my $output = $nagios{'SERVICEOUTPUT'} // "";
my $long_output = $nagios{'LONGSERVICEOUTPUT'} // "";

if ($nagios_url ne '') {
  push(@links, {
      'name' => 'View in Nagios',
      'uri' => "$nagios_url/cgi-bin/status.cgi?host=$nagios{'HOSTNAME'}"
  });
}

#
# Format message card (Office 365 connector format; Workflows render it without buttons)
#
sub message_card {
    my ($long_output) = @_;
    my %event;
    my @sections;
    my @actions;
    $event{'@type'} = "MessageCard";
    $event{'@context'} = "https://schema.org/extensions";
    $event{'themeColor'} = $color{"$nagios{'SERVICESTATE'}"};
    $event{'title'} = $title;
    $event{'summary'} = $title;
    my @facts = ({
        'name' => "Host:",
        'value' => "$nagios{'HOSTALIAS'}"
       },{
        'name' => "Details:",
        'value' => "$output $long_output"
    });
    my %section = ( 'facts' => \@facts, 'text' => "Host Notes: $nagios{'HOSTNOTES'}" );
    push(@sections, \%section);
    $event{'sections'} = \@sections;

    foreach my $link (@links) {
      my @targets = ({ 'os' => 'default', 'uri' => $link->{'uri'} });
      push(@actions, {
          '@type' => 'OpenUri',
          'name' => $link->{'name'},
          'targets' => \@targets
      });
    }
    if (@actions) {
      $event{'potentialAction'} = \@actions;
    }
    return \%event;
}

#
# Format Adaptive Card for Teams Workflows ("When a Teams webhook request is received").
# Version 1.4: Teams renders it on desktop and mobile; 1.5 cards are reported to fail
# with "We're sorry, this card couldn't be displayed" when posted by a workflow.
#
sub adaptive_card {
    my ($long_output) = @_;
    my $details = $output;
    $details .= "\n$long_output" if length($long_output);
    my @facts = ({ 'title' => "Host:", 'value' => "$nagios{'HOSTALIAS'}" });
    if ($nagios{'SERVICEDESC'} ne 'host status') {
      push(@facts, { 'title' => "Service:", 'value' => "$nagios{'SERVICEDESC'}" });
    }
    push(@facts, { 'title' => "State:", 'value' => "$nagios{'SERVICESTATE'}" });
    if (length($nagios{'NOTIFICATIONTYPE'})) {
      push(@facts, { 'title' => "Type:", 'value' => "$nagios{'NOTIFICATIONTYPE'}" });
    }
    my @body = ({
        'type' => 'TextBlock',
        'text' => $title,
        'weight' => 'Bolder',
        'size' => 'Medium',
        'color' => $adaptive_color{"$nagios{'SERVICESTATE'}"} // 'Default',
        'wrap' => JSON::true
       },{
        'type' => 'FactSet',
        'facts' => \@facts
       },{
        'type' => 'TextBlock',
        'text' => $details,
        'wrap' => JSON::true
       },{
        'type' => 'TextBlock',
        'text' => "Host Notes: $nagios{'HOSTNOTES'}",
        'isSubtle' => JSON::true,
        'wrap' => JSON::true
    });
    my @actions = map { +{ 'type' => 'Action.OpenUrl', 'title' => $_->{'name'}, 'url' => $_->{'uri'} } } @links;
    my %content = (
        '$schema' => 'http://adaptivecards.io/schemas/adaptive-card.json',
        'type' => 'AdaptiveCard',
        'version' => '1.4',
        'fallbackText' => $title,
        'speak' => $title,
        'msteams' => { 'width' => 'Full' },
        'body' => \@body
    );
    if (@actions) {
      $content{'actions'} = \@actions;
    }
    return {
        'type' => 'message',
        'summary' => $title,
        'attachments' => [{
            'contentType' => 'application/vnd.microsoft.card.adaptive',
            'contentUrl' => undef,
            'content' => \%content
        }]
    };
}

my $json = encode_json($card eq 'messagecard' ? message_card($long_output) : adaptive_card($long_output));

#
# Make the request
#

my $ua = LWP::UserAgent->new;
$ua->timeout(15);
$ua->env_proxy;

my $req = HTTP::Request->new('POST', $webhook);
$req->header('Content-Type' => 'application/json');
$req->content($json);

my $s = $req->as_string;
print STDERR "Request:\n$s\n";

my $resp = $ua->request($req);
$s = $resp->as_string;
print STDERR "Response:\n$s\n";
