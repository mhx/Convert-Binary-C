################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/03/22 19:38:04 +0000 $
# $Revision: 19 $
# $Snapshot: /Convert-Binary-C/0.54 $
# $Source: /t/802_threads.t $
#
################################################################################
#
# Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;
use Config;
use Convert::Binary::C @ARGV;
use constant NUM_THREADS => 4;

$^W = 1;

BEGIN {
  plan tests => NUM_THREADS
}

#===================================================================
# load appropriate threads module and start a couple of threads
#===================================================================

my $have_threads = Convert::Binary::C::feature( 'threads' )
                   && (   ($Config{useithreads} && $] >= 5.008)
                        || $Config{use5005threads}
                      );

my $reason = $Config{useithreads} || $Config{use5005threads}
             ? (
               Convert::Binary::C::feature( 'threads' )
               ? "unsupported threads configuration"
               : "not built with threads support"
             )
             : "no threads";

my @t;

if( $have_threads ) {
  if( $Config{use5005threads} ) {
    require Thread;
    @t = map { new Thread \&task, $_ } 1 .. NUM_THREADS;
  }
  elsif( $Config{useithreads} && $] >= 5.008 ) {
    require threads;
    @t = map { new threads \&task, $_ } 1 .. NUM_THREADS;
  }
}
else {
  Convert::Binary::C->new->parse('');  # allocate/free some memory
  @t = 1 .. NUM_THREADS
}

skip( $have_threads ? '' : "skip: $reason",
      $have_threads ? $_->join : $_, '', "thread failed" ) for @t;

sub task {
  my $arg = shift;
  my $p;

  eval {
    $p = new Convert::Binary::C EnumSize       => 0,
                                ShortSize      => 2,
                                IntSize        => 4,
                                LongSize       => 4,
                                LongLongSize   => 8,
                                PointerSize    => 4,
                                FloatSize      => 4,
                                DoubleSize     => 8,
                                LongDoubleSize => 12,
                                Include        => ['t/include/perlinc',
                                                   't/include/include'];
    if( $arg % 2 ) {
      print "# parse_file ($arg) called\n";
      $p->parse_file( 't/include/include.c' );
      print "# parse_file ($arg) returned\n";
    }
    else {
      print "# parse ($arg) called\n";
      $p->parse( <<END );
#include "EXTERN.h"
#include "perl.h"
END
      print "# parse ($arg) returned\n";
    }
  };

  $@ and return $@;

  # some simplified checks from the parse test

  my @enum_ids     = $p->enum_names;
  my @compound_ids = $p->compound_names;
  my @struct_ids   = $p->struct_names;
  my @union_ids    = $p->union_names;
  my @typedef_ids  = $p->typedef_names;

  @enum_ids     ==   4 or return "incorrect number of enum identifiers";
  @compound_ids == 134 or return "incorrect number of compound identifiers";
  @struct_ids   == 129 or return "incorrect number of struct identifiers";
  @union_ids    ==   5 or return "incorrect number of union identifiers";
  @typedef_ids  == 301 or return "incorrect number of typedef identifiers";

  my @enums     = $p->enum;
  my @compounds = $p->compound;
  my @structs   = $p->struct;
  my @unions    = $p->union;
  my @typedefs  = $p->typedef;

  @enums      ==  34 or return "incorrect number of enums";
  @compounds  == 194 or return "incorrect number of compounds";
  @structs    == 175 or return "incorrect number of structs";
  @unions     ==  19 or return "incorrect number of unions";
  @typedefs   == 303 or return "incorrect number of typedefs";

  my %size = do { local (@ARGV, $/) = ('t/include/sizeof.pl'); eval <> };
  my $max_size = 0;
  my @fail = ();
  my $bitfield;

  local $SIG{__WARN__} = sub {
    if( $_[0] =~ /Bitfields are unsupported in \w+\('wait[^']*'\)/ ) {
      $bitfield = 1;
      return;
    }
    print "# unexpected warning: $_[0]";
    push @fail, $_[0];
  };

  for my $t ( keys %size ) {
    $bitfield = 0;
    my $s = eval { $p->sizeof($t) };

    if( $@ ) {
      print "# sizeof failed for '$t': $@\n";
    }
    elsif( $bitfield ) {
      next;  # cannot handle bitfields yet
    }
    elsif( $size{$t} != $s ) {
      print "# incorrect size for '$t' (expected $size{$t}, got $s)\n";
    }
    else {
      $max_size = $s if $s > $max_size;
      next;
    }

    push @fail, $t unless $s == $size{$t}
  }

  @fail == 0 or return "size test failed for [@fail]";

  # don't use random data as it may cause failures
  # for floating point values
  my $data = pack 'C*', map { $_ & 0xFF } 1 .. $max_size;
  @fail = ();

  for my $id ( @enum_ids, @compound_ids, @typedef_ids ) {

    # skip long doubles
    next if grep { $id eq $_ } qw( __convert_long_double float_t double_t );

    my $x = eval { $p->unpack( $id, $data ) };

    if( $@ ) {
      print "# ($arg) unpack failed for '$id': $@\n";
      push @fail, $id;
      next;
    }

    my $packed = eval { $p->pack( $id, $x ) };

    if( $@ ) {
      print "# ($arg) pack failed for '$id': $@\n";
      push @fail, $id;
      next;
    }

    unless( chkpack( $data, $packed ) ) {
      print "# ($arg) inconsistent pack/unpack data for '$id'\n";
      push @fail, $id;
      next;
    }
  }

  @fail == 0 or return "pack test failed for [@fail]\n";

  print "# tests ($arg) finished successfully\n";

  return '';
}

sub chkpack
{
  my($orig, $pack) = @_;

  for( my $i = 0; $i < length $pack; ++$i ) {
    my $p = ord substr $pack, $i, 1;
    if ($i < length $orig) {
      my $o = ord substr $orig, $i, 1;
      return 0 unless $p == $o or $p == 0;
    }
    else {
      return 0 unless $p == 0;
    }
  }

  return 1;
}
