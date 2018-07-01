#!/usr/bin/perl -w

use strict;
use warnings qw(all);
use Data::Dumper;

my $lfile = "tracklog.log";

my $ofh = undef;
open($ofh,'>>',$lfile);

while (1) {

 my $rest = `top -b -n 1`;
 my @lines = split(/\n/,$rest);

 my @olines = splice(@lines,0,5);

 my @llines = grep {/LCDd/} @lines;
 my @clines = grep {/clock\.pl/} @lines;

 push(@olines,@llines);
 push(@olines,@clines);

 my $s = scalar localtime time;
 print $ofh "=== $s ========================\n";
 print $ofh join("\n",@olines);
 print $ofh "\n";
 sleep 600;
};

