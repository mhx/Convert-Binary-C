################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/08/21 15:30:24 +0100 $
# $Revision: 5 $
# $Snapshot: /Convert-Binary-C/0.01 $
# $Source: /t/w_threads.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Config;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN {
  $have_threads = Convert::Binary::C::feature( 'threads' )
                  && (   ($Config{useithreads} && $] >= 5.008)
                       || $Config{use5005threads}
                     );
  $num = 8;
  plan tests => $have_threads ? $num : 1 ;
}

unless( $have_threads ) {
  my $reason = $Config{useithreads} || $Config{use5005threads}
               ? (
                 Convert::Binary::C::feature( 'threads' )
                 ? "unsupported threads configuration"
                 : "not built with threads support"
               )
               : "no threads";
  skip( "skip: $reason", 1 );
  exit;
}

#===================================================================
# load appropriate threads module and start a couple of threads
#===================================================================

if( $Config{use5005threads} ) {
  require Thread;
  @t = map { new Thread \&task, $_ } 1 .. $num;
}
elsif( $Config{useithreads} && $] >= 5.008 ) {
  require threads;
  @t = map { new threads \&task, $_ } 1 .. $num;
}

ok( $_->join, '', "thread failed" ) for @t;

sub task {
  my $arg = shift;
  my $p;

  eval {
    $p = new Convert::Binary::C EnumSize => 0,
                                Include  => ['t/include/perlinc',
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

  local $SIG{__WARN__} = sub {};

  my %size = do { local (@ARGV, $/) = ('t/include/sizeof.pl'); eval <> };
  my $max_size = 0;
  my @fail = ();
  
  foreach( @enum_ids, @compound_ids, @typedef_ids ) {
    eval { $s = $p->sizeof($_) };
  
    if( $@ ) {
      print "# ($arg) sizeof failed for '$_': $@\n";
    }
    elsif( not defined $s and not exists $size{$_} ) {
      next;
    }
    elsif( not exists $size{$_} ) {
      print "# ($arg) can't find size for '$_'\n";
    }
    elsif( $size{$_} != $s ) {
      print "# ($arg) incorrect size for '$_' (expected $size{$_}, got $s)\n";
    }
    else {
      $max_size = $s if $s > $max_size;
      next;
    }
  
    push @fail, $_ unless $s == $size{$_}
  }
  
  @fail == 0 or return "size test failed for [@fail]";

  $data = pack 'C*', map rand 256, 1 .. $max_size;
  @fail = ();
  
  foreach( @enum_ids, @compound_ids, @typedef_ids ) {
    eval { $x = $p->unpack( $_, $data ) };
  
    if( $@ ) {
      print "# ($arg) unpack failed for '$_': $@\n";
      push @fail, $_;
      next;
    }
  
    eval { $packed = $p->pack( $_, $x ) };
  
    if( $@ ) {
      print "# ($arg) pack failed for '$_': $@\n";
      push @fail, $_;
      next;
    }
  
    unless( chkpack( $data, $packed ) ) {
      print "# ($arg) inconsistent pack/unpack data for '$_'\n";
      push @fail, $_;
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
    my $o = ord substr $orig, $i, 1;
    my $p = ord substr $pack, $i, 1;
    return 0 unless $p == $o or $p == 0;
  }

  return 1;
}
