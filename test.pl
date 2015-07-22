#!/usr/bin/perl -w
use strict;

BEGIN {
  if ($] < 5.005) {
    print STDERR <<ENDERR;

--> WARNING: The version of perl you're using ($]) is very old.
-->
-->   The test suite cannot be run with perl < 5.005.
    
ENDERR

    exit;
  }
}

use lib './support';
use Test::Harness;
use File::Find;
use File::Spec;
use Cwd;

my @tests = @ARGV ? @ARGV : find_tests();
die "*** Can't find any test files\n" unless @tests;

my $lib = File::Spec->catfile(getcwd, 'support');
$lib = qq["$lib"] if $lib =~ /\s/;

$Test::Harness::switches = "-I $lib -w";
$ENV{PERL_DL_NONLAZY} = 1;

runtests(@tests);

sub find_tests
{
  my %t;
  find(sub { -f and /\.t$/ and $t{$File::Find::name}++; }, 'tests');
  return sort keys %t;
}
