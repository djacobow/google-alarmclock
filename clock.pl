#!/usr/bin/perl -w

# This is required because newer perls default to JSON::XS, which 
# seems not to work reliably in multi-threaded programs. 1/27/2018
BEGIN { $ENV{PERL_JSON_BACKEND} = 'JSON::PP' };

use FindBin;
use lib "$FindBin::Bin";
use local::lib;

use strict;
use warnings qw(all);

use DateTime;
use Net::Address::IP::Local;
use Sys::Hostname;
use Socket;
use Data::Dumper;
use update_calendar;
use dinger;
use lcd;

my $cfg = {
 # list all the calendars that you'd like to check. For each you
 # must provide a gmail username and password (recommend an 
 # "application specific password" rather than your normal password)
 # or you can provide your calendar public URL. More info here:
 # https://support.google.com/calendar/answer/37103?hl=en
 accounts => [
# { user => "so.and.so\@gmail.com", password => "ixnayasswordpay" },
# { url  => "https://www.google.com/calendar/feeds/so.and.so%40gmail.com/private-[googly_digits]/full" },
 { user => "david.jacobowitz\@gmail.com", tok_file => "oauth_tokens.json", id_pat => 'jacobowitz' },
 ],
 # how often to re-check the calendar. Probably once every 5 minutes
 # is plenty for most people. The only advantage of setting it shorter
 # is that you can pick up events you just added to your calendar
 update_freq => 300,
 # the "title" name of the events that we'll pick up.
 titlekey => 'wakeup',
 splash_time => 1,
};

my $lcd         = new lcd;
my $dinger      = new dinger;
$dinger->setLCD($lcd);

my $calkeeper   = new update_calendar;

foreach my $account (@{$cfg->{accounts}}) {
 if (defined($account->{user}) && defined($account->{password})) {
  $calkeeper->addAccount_v2($account);
 } elsif (defined($account->{url})) {
  $calkeeper->addUrl_v2($account->{url});
 } elsif(defined($account->{user}) && defined($account->{tok_file})) {
  $calkeeper->addAccount_v3($account);
 }
}

$calkeeper->setTitleKey($cfg->{titlekey});
$calkeeper->startUpdateThread($cfg->{update_freq});

splash();

my $last_ev_start      = -1;
my $bl                 = { time => 0, status => 'off', };
my $last_alarm_started = DateTime->from_epoch(epoch => 0);

my $loop_count        = 0;
while (1) {
 my ($f1, $alarms)  = $calkeeper->getAlarms();
 my ($f2, $evs)     = $calkeeper->getPendingEvents();
 my $did_fetch = $f1 || $f2;
 my $ev_start       = printPending($lcd,$evs);
 my $alarm_started  = dispatchAlarm($alarms, $last_alarm_started);
 $lcd->updateTime();
 $last_alarm_started = $alarm_started;
 if ($did_fetch) {
  $loop_count = 0;
 } elsif ($loop_count > ($cfg->{update_freq} * 3)) {
  print "Restarting fetch thread because it apparently died.\n";
  $calkeeper->startUpdateThread($cfg->{update_freq});
 }
 $loop_count++;
 sleep 1;
}


sub printPending {
 my $lcd = shift;
 my $evs = shift;
 my $done = 0;

 my $start = 0;
 my $ev         = undef;
 if (@$evs) {
  $ev = $evs->[0];
  #print Dumper $ev;
  $start = $ev->{start};
 }

 if ($last_ev_start != $start) {
  if ($start > 0) {
   my @t = localtime $start;
   my $tstring = sprintf("%2.2d/%2.2d %2.2d:%2.2d",
    $t[4]+1,$t[3],$t[2],$t[1]);
   $lcd->printxy(1,0,"next: $tstring");
   my $title = $ev->{title};
   # the titlekey is how we determine this is an event for us,
   # but the user has no need to see that on the clock, so we
   # get rid of it to make more room for any other title text
   $title =~ s/\s*$cfg->{titlekey}\s*//;
   $lcd->printxy(2,0,$title);
   $lcd->printxy(3,0,join(',',@{$ev->{who}}));
  } else {
   $lcd->printxy(1,0,"no events");
   $lcd->printxy(2,0,"");
   $lcd->printxy(3,0,"");
  }
 }
 $last_ev_start = $start;
 return $start;
}

sub dispatchAlarm {
 my $alarms = shift;
 my $last_alarm_start = shift;
 my $alarm_started = DateTime->from_epoch(epoch => 0);

 #my $alarm_started = 0;
 if (defined($alarms) && (@$alarms)) { 
  foreach my $alarm (@$alarms) {
   if ($last_alarm_start != $alarm->{start}) {
    my @tps = split(/\s/,$alarm->{text});
    foreach my $tp (@tps) {
     if ($tp =~ /(\w+)=(\w+)/) {
      $dinger->set($1 => $2);
     }
    }
    # rather than start another thread, we'll just wait for the 
    # alarm to complete. Why not?
    $lcd->printxy(1,0,"Alarm");
    $lcd->printxy(2,0,$alarm->{title});
    $lcd->printxy(3,0,$alarm->{text});
    $dinger->ring();
    $alarm_started = $alarm->{start};
   }
  }
 };
 return $alarm_started;
};

sub splash {
  my $host    = hostname();
  my $address = inet_ntoa(scalar gethostbyname($host || 'localhost'));
                    #01234567890123456789
  $lcd->printxy(0,0,"Dinging Alarm Clock ");
  $lcd->printxy(1,0,"version 0.0         ");
  $lcd->printxy(2,0,$host);
  my $ip = 'no_ip';
  if ($^O ne 'MSWin32') {
   my $ev_ok = eval { $ip = Net::Address::IP::Local->public; };
  }
  $lcd->printxy(3,0,$ip);
  sleep $cfg->{splash_time};
};

