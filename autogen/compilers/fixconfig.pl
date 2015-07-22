#!/usr/bin/perl -w
use Data::Dumper;
use IO::File;
use strict;
use vars qw(%config);

for my $file (@ARGV) {
  -f $file or die "$file: $!\n";
  do $file;
  unlink $file or die "$file: $!\n";
  delete $config{Include};
  IO::File->new(">$file")->print(Data::Dumper->new([\%config], ['*config'])->Indent(2)->Dump);
}
