#!/usr/bin/perl -w

use strict;
use warnings;
use feature qw/say/;

use Data::Dumper;
use Encode qw/encode_utf8/;
use FindBin;
use Google::API::Client;
use Google::API::OAuth2::Client;

use ghelp;

my $client         = Google::API::Client->new;
my $service        = $client->build('calendar', 'v3');
my $client_secrets = "client_secrets.json";
my $token_file     = "oauth_refresh_token.dat";

my $auth_driver    = Google::API::OAuth2::Client->new_from_client_secrets($client_secrets, $service->{auth_doc});
my $access_token   = get_or_restore_token($token_file,$auth_driver);


my $body = {
 maxResults => 3,
};

my $list = $service->calendarList->list(body => $body,)->execute({auth_driver => $auth_driver });

foreach my $entry (@{$list->{items}}) {
 print "summary: $entry->{summary}\n";
 my $cal = $service->calendarList->get(
  body => {
   calendarId => $entry->{id},
  })->execute({auth_driver => $auth_driver});

 my $evs = $service->events->get(
  body => {
   calendarId => $entry->{id},
   q => 'wakeup',
   timeMax => '2016-02-16T00:00:00Z',
   timeMin => '2016-01-01T00:00:00Z',
   singleEvents => 'true',
  }
 )->execute({auth_driver => $auth_driver});

 foreach my $ev (@{$evs->{items}}) {
  print "summary: $ev->{summary}\n";
  print "description: $ev->{description}\n";
  print "start: $ev->{start}{dateTime}\n";
  print "organizer: $ev->{organizer}{displayName}\n";
 } 
}

store_token($token_file, $auth_driver);


__END__

my $dat_file = "$FindBin::Bin/token.dat";
my $access_token = get_or_restore_token($dat_file, $auth_driver);



my $page_token;
my $count = 1;
do {
    say "=== page $count ===";
    my %body = (
        maxResults => MAX_PAGE_SIZE,
    );
    if ($page_token) {
        $body{pageToken} = $page_token;
    }
    # Call calendarlist.list
    my $list = $service->calendarList->list(
        body => \%body,
    )->execute({ auth_driver => $auth_driver });
    $page_token = $list->{nextPageToken};
    for my $entry (@{$list->{items}}) {
        say '* ' . encode_utf8($entry->{summary});
        # Call calendarlist.get
        my $calendar = $service->calendarList->get(
            body => {
                calendarId => $entry->{id},
            }
        )->execute({ auth_driver => $auth_driver });
        if (my $description = $calendar->{description}) {
            say '  ' . encode_utf8($description);
        }
    }
    $count++;
} until (!$page_token);


