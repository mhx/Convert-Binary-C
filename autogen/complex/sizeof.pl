#!/usr/bin/perl -w
use strict;

my $align = shift;
my %member = %{eval do {local $/; <>}};
my $first = 1;

srand 0;

print "$align => {\n";
for my $type ( keys %member ) {
  if( $first ) { $first = 0 }
  else {
    print ",\n"
  }
  print "$type=>{\n";

  my %members;

  for( @{$member{$type}} ) {
    $_->[0] or next;
    push @{$members{$_->[1]}}, $_->[0];
  }

  print join ",\n", map {
    my @m = @{$members{$_}};
    splice @m, rand(@m), 1 while @m > 10;
    "$_ => [qw(@m)]"
  } sort { $a <=> $b } keys %members;

  print "}";
}
print "},\n";

