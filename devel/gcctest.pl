#!/usr/bin/perl -w
use strict;
use Data::Dumper;

while( <> ) {
  my($file,$line) = /^FAILED.* in (\/.*), line (\d+)/ or next;

  print "\n$_\n\n";

  open FILE, $file or die "can't open '$file': $!\n";
  my($l1,$l2) = ($line-10, $line+10);
  $l1 = 1 if $l1 < 1;
  while( <FILE> ) {
    printf "%4d %s | %s", $., $. == $line ? '>' : ' ', $_ if $. >= $l1;
    last if $. == $l2;
  }

  close FILE;

  print "\n", '-'x150, "\n";
}
