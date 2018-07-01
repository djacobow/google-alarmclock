package ghelp;

use strict;
use warnings qw(all);
use JSON;
use Exporter qw(import);

our @EXPORT = qw(get_or_restore_token store_token);


sub get_or_restore_token {
 my $file = shift;
 my $auth_driver = shift;
 my $access_token;
 if (-f $file) {
  open my $fh, '<', $file;
  if ($fh) {
   local $/;
   #require JSON;
   $access_token = JSON->new->decode(<$fh>);
   close $fh;
  }
  $auth_driver->token_obj($access_token);
 } else {
  my $auth_url = $auth_driver->authorize_uri;
  print "Go to the following link in your browser:\n";
  print "$auth_url\n";
    
  print "Enter verification code\n";
  my $code = <STDIN>;
  chomp $code;
  $access_token = $auth_driver->exchange($code);
 }
 return $access_token;
}

my $last_access_token = {};

sub store_token {
 my ($file, $auth_driver) = @_;
 my $access_token = $auth_driver->token_obj;

 my $change = 0;
 foreach my $k (keys %$access_token) {
  if (!defined($last_access_token->{$k}) ||
      ($last_access_token->{$k} != $access_token->{$k})) {
   $change++;
  }
 }
 if ($change) { 
  open my $fh, '>', $file;
  if ($fh) {
   #require JSON;
   print $fh JSON->new->encode($access_token);
   close $fh;
  }
 }
}

1;

