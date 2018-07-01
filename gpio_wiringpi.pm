package gpio_wiringpi;

use Inline C => Config => ENABLE => AUTOWRAP,
                          INC  => '-I/usr/local/include',
                          LIBS => '-lwiringPi';

use Inline C;
use Scalar::Util qw(looks_like_number);
use Exporter qw(import);
our @EXPORT = qw(p_digitalWrite p_pinMode p_wiringPiSetup 
                 p_digitalRead p_pulse);


sub p_wiringPiSetup {
 c_wiringPiSetup();
};

sub p_pulse {
 my $p = shift;
 my $t = shift;
 c_pulse($p,$t);
};

sub p_pinMode {
 my $p = shift;
 my $v = shift;

 if (!defined($p) || !defined($v) || 
     !looks_like_number($p) || !looks_like_number($v)) {
  return -1;
 }
 c_pinMode($p,$v);
}

sub p_digitalRead {
 my $p = shift;
 if (!defined($p) || !looks_like_number($p)) {
  return -1;
 }
 return c_digitalRead($p);
}

sub p_digitalWrite {
 my $p = shift;
 my $v = shift;
 if (!defined($p) || !defined($v) || 
     !looks_like_number($p) || !looks_like_number($v)) {
  return -1;
 }
     
 if ($v) { $v = 1; } else { ($v) = 0; }
 c_digitalWrite($p,$v);
};


__DATA__
__C__

#ifndef _WIN32

#include <wiringPi.h>

void c_pulse(unsigned int p, unsigned int t) {
 unsigned int v = digitalRead(p);
 digitalWrite(p,!v);
 delay(t);
 digitalWrite(p,v); 
}

int c_wiringPiSetup() {
 return wiringPiSetup();
}
void c_digitalWrite(unsigned int p, unsigned int v) {
 digitalWrite(p,v);
}
unsigned int c_digitalRead(unsigned int p) {
 return digitalRead(p);
}
void c_pinMode(unsigned int p, unsigned int m) {
 pinMode(p,m);
}

void c_delay(unsigned int t) {
 delay(t);
}

#else 

#include <stdio.h>
#include <windows.h>

void c_pulse(unsigned int p, unsigned int t) {
 printf("-gpio-wiringpi- c_pulse(%d,%d)\n",p,t);
}

int c_wiringPiSetup() {
 printf("-gpio-wiringpi- c_wiringPiSetup()\n");
}

void c_digitalWrite(unsigned int p, unsigned int v) {
 printf("-gpio-wiringpi- c_digitalWrite(%d,%d)\n",p,v);
}

unsigned int c_digitalRead(unsigned int p) {
 printf("-gpio-wiringpi- c_digitalRead(%d) [returning 0]\n",p);
 return 0;
}

void c_pinMode(unsigned int p, unsigned int m) {
 printf("-gpio-wiringpi- c_pinMode(%d,%d)\n",p,m);
 return 0;
}

void c_delay(unsigned int t) {
 printf("-gpio-wiringpi- c_delay(%d)\n",t);
 Sleep(t);
}

#endif


