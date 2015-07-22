#!/usr/bin/perl -w
use strict;

my $align = shift;
my %member = %{eval do {local $/; <>}};
my $first = 1;

print "$align => {\n";
for my $type ( keys %member ) {
  my $last;
  my $size;
  my @members;
  if( $first ) { $first = 0 }
  else {
    print ",\n"
  }
  print "$type=>[\n";
  for( 0 .. ($member{$type}[-1][1] - 1) ) {
    my $m = find_member( $_, $member{$type} );
    if( defined $last && $m =~ /^\Q$last\E\+(\d+)$/ ) {
      $size = $1;
    }
    else {
      defined $size and push @members, $size+1;
      print join( ',', @members ), ",\n" if @members;
      $last = $m =~ /\+\d+$/ ? undef : $m;
      $size = undef;
      @members = ("'$m'");
    }
  }
  defined $size and push @members, $size+1;
  print join( ',', @members ), "\n";
  print "]";
}
print "},\n";

sub find_member
{
  my( $off, $ary ) = @_;

  for( @$ary ) {
    if( $_->[2] <= $off && $off < $_->[2]+$_->[1] ) {
      return $_->[0] if $_->[2] == $off;
      $off -= $_->[2];
      return $_->[0] . "+$off";
    }
  }

  return "+$off";
}
