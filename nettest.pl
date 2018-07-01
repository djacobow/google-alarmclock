#!/usr/bin/perl -w

use lcd;

my $lcd = new lcd;

while (1) {
 my $res = `ping 8.8.8.8 -c 1`;
 my @lines = split(/\n/,$res);
 $lcd->printxy(0,0,$lines[0]);
 $lcd->printxy(1,0,$lines[1]);
 $lcd->printxy(2,0,$lines[2]);
 $lcd->printxy(3,0,$lines[3]);
 sleep 2;
};

