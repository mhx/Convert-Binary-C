#!/usr/bin/perl -w
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/01/01 09:36:50 +0000 $
# $Revision: 3 $
# $Source: /test.pl $
#
################################################################################
#
# Copyright (c) 2005-2006 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

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
