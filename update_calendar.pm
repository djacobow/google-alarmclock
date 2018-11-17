use strict;
use warnings qw(all);

use local::lib;

package update_calendar;

use DateTime;
use DateTime::Format::RFC3339;
use Data::Dumper;
use LWP::Simple qw(get);
use Net::Google::Calendar;
use Google::API::Client;
use Google::API::OAuth2::Client;
use ghelp;
use Encode qw/encode_utf8/;

use threads;
use threads::shared;
use Thread::Queue;

sub new {
 my $class = shift;

 my $self = {
  # icp  => iCal::Parser->new(),
  shutdown => 0,
  ngcs => [],
  ready => 0,
  urls => [],
  titlekey => 'wakeup',
  dtformatter => DateTime::Format::RFC3339->new(),
  ev_lists => Thread::Queue->new(),
  ev_list  => {},
 };

 bless($self,$class);
 return $self;

};


sub setTitleKey {
 my $s = shift;
 my $k = shift;
 $s->{titlekey} = $k;  
};

sub addAccount_v3 {
 my $s = shift;
 my $acct = shift;
 my $user           = $acct->{user};
 my $tok_fn         = $acct->{tok_file};
 my $client         = Google::API::Client->new;
 my $service        = $client->build('calendar','v3');
 my $client_secrets_fn = 'client_secrets.json';
 my $auth_driver    = Google::API::OAuth2::Client->new_from_client_secrets($client_secrets_fn, $service->{auth_doc});
 my $access_token   = get_or_restore_token($tok_fn,$auth_driver);
 my $cal_list       = $service->calendarList->list(body => { maxResults => 3 })->execute({auth_driver => $auth_driver});

 my $cal_id = undef;
 foreach my $item (@{$cal_list->{items}}) {
  if ($item->{id} =~ /$acct->{id_pat}/i) {
   $cal_id = $item->{id};
   last;
  }
 }
 
 if (defined($cal_id)) {
  push (@{$s->{ngcs}}, { type => 'v3', 
		         service => $service, 
			 auth_driver => $auth_driver, 
			 token => $access_token, 
			 cal_id => $cal_id,
		         tok_fn => $tok_fn });
  store_token($tok_fn,$auth_driver);
 };
};

sub addUrl_v2 {
 my $s = shift;
 my $url = shift;
 my $ngc = Net::Google::Calendar->new(  url => $url );
 push (@{$s->{ngcs}}, { type => 'ngc', handle => $ngc });
};

sub addAccount_v2 {
 my $s = shift;
 my $acct = shift;
 my $user = $acct->{user};
 my $pwrd = $acct->{password};
 my $ngc  = Net::Google::Calendar->new();
 $ngc->login($user,$pwrd);
 my @calendars = $ngc->get_calendars();
 $ngc->set_calendar($calendars[0]);
 push(@{$s->{ngcs}}, { type => 'ngc', handle => $ngc });
};

sub startUpdateThread {
 my $s = shift;
 my $freq = shift;
 my $thr  = threads->create(\&updateThreadFn,$s,$freq);
 $thr->detach();
};

sub updateThreadFn {
 my $s = shift;
 my $freq = shift;
 while (!$s->{shutdown}) {
  $s->updateCals_thread();
  sleep $freq;
 }
};

sub updateCals_thread {
 my $s = shift;
 my $now = time;
 my $lb = $now - (1*60*60);
 my $ub = $now + (24*60*60);
 my $time_lb = DateTime->from_epoch(epoch => $lb);
 my $time_ub = DateTime->from_epoch(epoch => $ub);

 #my $now = DateTime->now;
 #my $time_lb = $now; $time_lb->subtract(hours => 1);
 #my $time_ub = $now; $time_ub->add(days => 1);

 $s->{ev_lists}->enqueue({ type => 'fetch_started'});
 my $new_list = { type => 'fetch_results', events => {}} ;

 foreach my $ngc (@{$s->{ngcs}}) {
  if ($ngc->{type} eq 'ngc') {
   $s->_fetch_v2($ngc,$new_list,$time_lb,$time_ub);
  } elsif ($ngc->{type} eq 'v3') {
   $s->_fetch_v3($ngc,$new_list,$time_lb,$time_ub);
  }
 }
 $s->{ev_lists}->enqueue($new_list);
};

sub _checkList {
 my $s = shift;
 my $v = $s->{ev_lists}->dequeue_nb();
 my $did_fetch = 0;
 if (defined($v) && ($v->{type} eq 'fetch_started')) {
  $did_fetch = 1;
 }
 if (defined($v) && ($v->{type} eq 'fetch_results')) {
  $s->{ev_list} = $v->{events};
 }
 return $did_fetch;
};

sub getPendingEvents {
 my $s = shift;
 my ($did_fetch, $evs) = $s->getAllEvents();
 my $now = time;

 # print "before\n";
 # print Dumper $evs;

 my $ev_time = 0;
 if (@$evs) {
  $ev_time = $evs->[0]{start};
  if ($ev_time < $now) {
   shift @$evs;
  }
 }
 # print "after\n";
 # print Dumper $evs;
 return ($did_fetch, $evs);
}


sub getAllEvents {
 my $s = shift;
 my $did_fetch = $s->_checkList(); 
 my $o = [];
 foreach my $evt (sort { $a <=> $b } keys %{$s->{ev_list}}) {
  my $ev = $s->{ev_list}{$evt};
  push(@$o, { title => $ev->{title}, 
	     start => $ev->{start}->epoch(),
	     #end   => $ev->{finish}->epoch(), 
	     text  => $ev->{text},
             who   => $ev->{who}
           }
      );
 }
 # print Dumper $o;
 return ($did_fetch, $o);
};

sub getAlarms {
 my $s = shift;
 my $now = DateTime->now();
 # $now->truncate(to => 'minute');
 # this code considers time matching if they are withing the
 #  same 10 seconds. This compromise gets a reasonably accurate
 #  alarm but also means that we won't miss an alarm even if
 #  Raspbian gets bogged down and doesn't call this routine 
 #  for up to 10 seconds
 $now = int(time / 10);
 my $did_fetch = $s->_checkList();
 my $alarms = [];
 foreach my $ev (values %{$s->{ev_list}}) {
  my $start  = int($ev->{start}->epoch() / 10); 
  # if ((!DateTime->compare($now,$ev->{start})) && (!$ev->{caught})) {
  if (($now == $start) && (!$ev->{caught})) {
    $ev->{caught} = 1;
    push(@$alarms,{ start=> $ev->{start}, title => $ev->{title}, text => $ev->{text}});
  }
 }
 return ($did_fetch, $alarms);
};


sub _fetch_v2 {
 my $s        = shift;
 my $ngc      = shift;
 my $new_list = shift;
 my $time_lb = shift;
 my $time_ub = shift;

 my @evs = ();

 if ($ngc->{type} eq 'ngc') {
  my $query = {
    q => $s->{titlekey},
    'start-min' => $s->{dtformatter}->format_datetime($time_lb),
    'start-max' => $s->{dtformatter}->format_datetime($time_ub),
    singleevents => 'true',
  };
  my $ev_ok = eval {
   @evs = $ngc->{handle}->get_events(%$query);
   return 0;
  };
  if (!defined($ev_ok)) {
   $new_list->{result} = 'fail';
  } else {
   $new_list->{result} = 'success';
   if (@evs) {
    foreach my $ev (@evs) {
     my $title = $ev->title;
     my ($start, $finish) = $ev->when();
     my $text = $ev->content->body;
     my $t  = $start->epoch();
     my @who = map { $_->name } $ev->who;
     # print "==> " . (scalar localtime $t)  . "\n";
     $new_list->{events}{$t} = {
      title => $title,
      start => $start,
      finish => $finish,
      text => $text,
      who  => \@who,
      caught => 0,
     }
    };
   }
  }
 }
}

sub _fetch_v3 {
 my $s = shift;
 my $ngc = shift;
 my $new_list = shift;
 my $time_lb = shift;
 my $time_ub = shift;

 my @evs = ();

 if ($ngc->{type} eq 'v3') {
  my $query = {
   calendarId => $ngc->{cal_id},
   q => $s->{titlekey},
   timeMax => $s->{dtformatter}->format_datetime($time_ub),
   timeMin => $s->{dtformatter}->format_datetime($time_lb),
   singleEvents => 'true',
  };
  my $evs = $ngc->{service}->events->list(body => $query)->execute({auth_driver => $ngc->{auth_driver}});
  store_token($ngc->{tok_fn}, $ngc->{auth_driver});
  if (defined($evs)) {
   $new_list->{result} = 'success';
   foreach my $ev (@{$evs->{items}}) {
     my $start = $ev->{start}{dateTime};
     my $st_dt = $s->{dtformatter}->parse_datetime($start);
     my $end   = $ev->{end}{dateTime};
     my $ed_dt = $s->{dtformatter}->parse_datetime($end);
     my $t     = $st_dt->epoch();
     $new_list->{events}{$t} = {
      title   => $ev->{summary},
      text    => $ev->{description},
      start   => $st_dt,
      finish  => $ed_dt,
      who     => [ $ev->{organizer}{displayName} ],
      caought => 0,
     } 
   }
  } else {
   $new_list->{result} = 'fail';
  }
 }
}


1;

