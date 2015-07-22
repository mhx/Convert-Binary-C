#!/bin/perl -w
################################################################################
#
# PROGRAM: check_alloc.pl
#
################################################################################
#
# DESCRIPTION: Check for memory leaks and print memory usage statistics
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/08/31 09:12:10 +0100 $
# $Revision: 2 $
# $Snapshot: /Convert-Binary-C/0.02 $
# $Source: /ctlib/util/tool/check_alloc.pl $
#
################################################################################
#
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of either the Artistic License or the
# GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
################################################################################

use strict;

my %alloc;
my %info = (
  allocs     => 0,
  frees      => 0,
  max_blocks => 0,
  max_total  => 0,
);
my $count = 0;
my $total = 0;

while( <> ) {
  next unless /^(.*?):(A|F|V)=(?:(\d+)\@)?([[:xdigit:]]{8})$/;
  if( $2 eq 'A' ) {
    print "Previously allocated in $alloc{$4}[0]: 0x$4 in $1\n" if exists $alloc{$4};
    next if exists $alloc{$4};
    $alloc{$4} = [$1,$3];
    $count++;
    $total += $3;
    $info{allocs}++;
    $info{min_size} = $info{max_size} = $3 unless exists $info{min_size};
    $info{min_size} = $3 if $3 < $info{min_size};
    $info{max_size} = $3 if $3 > $info{max_size};
  }
  elsif( $2 eq 'F' ) {
    print "Freeing NULL pointer in $1\n" if $4 eq '00000000';
    print "Freeing block not previously allocated: 0x$4 in $1\n" unless exists $alloc{$4};
    next unless exists $alloc{$4};
    $count--;
    $total -= $alloc{$4}[1];
    $info{frees}++;
    delete $alloc{$4};
  }
  else { # $2 eq 'V'
    print "Valid pointer assertion (0x$4) failed in $1\n" unless exists $alloc{$4};
    next; # nothing needs to be updated
  }
  $info{max_blocks} = $count if $count > $info{max_blocks};
  $info{max_total}  = $total if $total > $info{max_total};
}

foreach( sort keys %alloc ) {
  print "Not freed: 0x$_ allocated in $alloc{$_}[0]\n";
}

print <<ENDSTATS;

Summary Statistics:

  Total allocs       : $info{allocs}
  Total frees        : $info{frees}
  Max. memory blocks : $info{max_blocks}
  Max. memory usage  : $info{max_total} bytes

  Smallest block     : $info{min_size} bytes
  Largest block      : $info{max_size} bytes

  Memory leakage     : $total bytes

ENDSTATS
