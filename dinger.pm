#!/usr/bin/perl -w

package dinger;

use strict;
use warnings qw(all);

use Data::Dumper;
use gpio_wiringpi;

# GPIO17 == 0 == hringer
# GPIO27 == 2 == snooze led
# GPIO22 == 3 == snooze


sub new {
 my $s = {
  count => 5,
  delay => 10,
  pulse => 200,
  ring_pin   => 0,
  snooze_led_pin => 2,
  snooze_pin => 3,
  do_set => 0,
  setup_done => 0,
  lcd => undef,
 };

 p_wiringPiSetup();
 p_pinMode($s->{ring_pin},1); # output
 p_pinMode($s->{snooze_led_pin},1); #output
 p_pinMode($s->{snooze_pin},0); # input
 # note, the ringer is now active low. this is not what I wanted
 # but the FET I chose is has too high a threshold voltage to 
 # drive from 3.3V supply, so I added a little BJT common emitter
 # up front, but that inverts 
 p_digitalWrite($s->{ring_pin},1);
 p_digitalWrite($s->{snooze_led_pin},0);
 #on Ard this sets pulldowns, does it work on RPi?
 p_digitalWrite($s->{snooze_pin},0); 

 $s->{setup_done} = 1;

 bless($s);
 return $s;

};

sub setLCD {
 my $s = shift;
 my $lcd = shift;
 $s->{lcd} = $lcd;
};

sub set {
 my $s = shift;
 if (@_) {
  my %args = @_;
  foreach my $aname (keys %args) {
   $s->{$aname} = $args{$aname};
   #print "-dinger set $aname = $args{$aname}\n";
  }
 }
};


sub ring {
 my $s = shift;
 p_digitalWrite($s->{snooze_led_pin},1);
 for (my $i=0;$i<$s->{count};$i++) {
  #print "-dinger- ding!\n";
  p_pulse($s->{ring_pin}, $s->{pulse});
  for (my $j=0;$j<$s->{delay};$j++) {
   my $snooze = p_digitalRead($s->{snooze_pin});
   if ($snooze) {
    #print "-dinger- Snoozed!\n";
    goto snoozed;
   }
   if (defined($s->{lcd})) {
    $s->{lcd}->updateTime();
   }
   sleep(1);
  }
 }
snoozed:
 p_digitalWrite($s->{snooze_led_pin},0);
}

1;

