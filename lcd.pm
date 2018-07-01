package lcd;

use strict;
use warnings qw(all);

use Data::Dumper;
use IO::Socket;
use if ($^O eq 'MSWin32'), 'Win32::Console';

my $object_copy = undef;

$SIG{PIPE} = sub {
 print "-error- received SIGPIPE!\n";
};


sub reset_sock {
 my $s = shift;
 print "-info- resetting socket connection to LCD.\n";
 $s->teardown_socket();
 $s->setup_socket();
}

sub setup_socket {
 my $s = shift;

 my $sock = new IO::Socket::INET(
  PeerAddr => 'localhost',
  Proto => 'tcp',
  PeerPort =>  13666,
 );
 if (defined($sock)) {
  $s->{socket} = $sock;
 }

 if (defined($sock)) {
  print $sock "hello\n";
  my $resp = <$sock>;
  my @respa = split(/\s/,$resp);
  while (@respa) {
   my $respi = shift @respa;
   if ($respi eq 'wid') {
    $s->{width} = shift @respa;
   } elsif ($respi eq 'hgt') {
    $s->{height} = shift @respa;
   }
  }
 }
 if (defined($s->{width}) && defined($s->{height})) {
  $s->{sock_set} = 1;
 }
 if ($s->{sock_set}) {
  print $sock "client_set name {aclock}\n";
  print $sock "screen_add s1\n";
  print $sock "screen_set s1 name {aclock_s1}\n";
  print $sock "screen_set s1 heartbeat off\n";
  print $sock "screen_set s1 backlight $s->{bl_status}\n";
  for (my $i=0;$i<$s->{height};$i++) {
   print $sock "widget_add s1 l$i string\n";
  }
 }
}

sub new {
 my $s = { 
  sock_set      => 0,
  bl_status     => 'off',
  bl_last_touch => time,
  bl_timeout    => 30,
 };

 $object_copy = $s;

 bless($s);
 reset_sock($s);


 if ($^O eq 'MSWin32') {
#  my $console = Win32::Console->new(STD_OUTPUT_HANDLE);
#  $console->Alloc();
#  $s->{w32console} = $console;
#  $console->Cls();
#  $console->Cursor(0,6);
 }
 return $s;
};

sub printxy {
 my $s = shift;
 my $x = shift || 0;
 my $y = shift || 0;
 my $t = shift;
 my $no_touch = shift || 0; 

 if (!$s->{sock_set} || ($s->{socket}->error) || !($s->{socket}->connected())) {
  $s->reset_sock();
 }

 if (($s->{sock_set}) && ($s->{socket}->connected()))  {
  my $sock = $s->{socket};

  if ($s->{bl_timeout}) {
   my $new_bl_status = 'on';
   if (time > ($s->{bl_last_touch} + $s->{bl_timeout})) {
    $new_bl_status = 'off';
   }
   print $sock "screen_set s1 backlight $new_bl_status\n";
   $s->{bl_status} = $new_bl_status;
  } 

  my $os   = "widget_set s1 l$x " . 
              ($y+1) . " " . ($x+1) .
              ' {' . $t . "}\n";
  print $sock $os;
  if (!$s->{sock_set} || ($s->{socket}->error) || !($s->{socket}->connected())) {
   $s->reset_sock();
  }

  # for debugging only
  # print $os;
 };
 if (($^O eq 'MSWin32') && defined($s->{w32console})) {
#  my @current_cursor = $s->{w32console}->Cursor();
#  $s->{w32console}->Cursor($y+1,$x+1, 50, 1);
#  if ($s->{bl_status} eq 'on') {
#   $s->{w32console}->Attr($FG_WHITE | $BG_LIGHTBLUE);
#  } else {
#   $s->{w32console}->Attr($FG_BLACK | $BG_GRAY);
#  }
#  print sprintf("%-20.20s\n",$t); 
#  $s->{w32console}->Attr($FG_WHITE | $BG_BLACK);
#  $s->{w32console}->Cursor(@current_cursor);
 }
 if (!defined($no_touch) || !$no_touch) {
  $s->{bl_last_touch} = time;
 }
};

sub set_backlight_timeout {
 my $s = shift;
 $s->{bl_timeout} = shift;
}

sub backlight {
 my $s = shift;
 my $v = shift;
 $s->{bl_status} = $v;
 $s->{backlight_timeout} = 0;
 my $sock = $s->{socket};
 if (($s->{sock_set}) && ($s->connected()))  {
  print $sock "screen_set s1 backlight $v\n";
 }
};

sub updateTime {
 my $s = shift;
 $s->printxy(0,0,scalar localtime time,1);
};

sub teardown_socket {
 my $s = shift;
 if (defined($s->{socket})) {
  close($s->{socket});
  $s->{sock_set} = 0;
  delete $s->{socket};
 }
}

sub DESTROY {
 my $s = shift;
 $s->teardown_socket();
};

1;

