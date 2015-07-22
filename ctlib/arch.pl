################################################################################
#
# PROGRAM: arch.pl
#
################################################################################
#
# DESCRIPTION: Generate header file for architecture specific definitions
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/06/20 17:46:42 +0100 $
# $Revision: 2 $
# $Snapshot: /Convert-Binary-C/0.02 $
# $Source: /ctlib/arch.pl $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Config;

open OUT, ">".shift or die $!;

%cfg = %Config;

# <HACK> required to support perl < 5.6.0

unless( exists $cfg{i8type} ) {
  $b8 = 'char';

  for( qw( int short long ) ) {
    if( not defined $b16 and $cfg{"${_}size"} == 2 ) { $b16 = $_ }
    if( not defined $b32 and $cfg{"${_}size"} == 4 ) { $b32 = $_ }
  }

  defined $b16 and defined $b32 or die "cannot determine integer sizes";

  $cfg{i8type}  = "signed $b8";
  $cfg{u8type}  = "unsigned $b8";
  $cfg{i16type} = "signed $b16";
  $cfg{u16type} = "unsigned $b16";
  $cfg{i32type} = "signed $b32";
  $cfg{u32type} = "unsigned $b32";
}

# </HACK>

sub is_big_endian
{
  my $byteorder = $cfg{byteorder}
               || unpack( "a*", pack "L", 0x34333231 );

  die "Native byte order ($byteorder) not supported!\n"
      if   $byteorder ne '1234'     and $byteorder ne '4321'
       and $byteorder ne '12345678' and $byteorder ne '87654321';

  $byteorder eq '4321' or $byteorder eq '87654321';
}

sub config ($) {
  local $_ = shift;
  s/\${([^}]+)}/$cfg{$1}/g;
  print OUT;
}

config <<'ENDCFG';
#ifndef _ARCH_H
#define _ARCH_H

/* 8-bit integer data types */
typedef ${i8type} i_8;
typedef ${u8type} u_8;

/* 16-bit integer data types */
typedef ${i16type} i_16;
typedef ${u16type} u_16;

/* 32-bit integer data types */
typedef ${i32type} i_32;
typedef ${u32type} u_32;

ENDCFG

if( $cfg{d_quad} eq 'define' ) {
config <<'ENDCFG';
#define NATIVE_64_BIT_INTEGER

/* 64-bit integer data types */
typedef ${i64type} i_64;
typedef ${u64type} u_64;

ENDCFG
}
else {
config <<'ENDCFG';
/* no native 64-bit support */
typedef struct {
  ${u32type} h;
  ${u32type} l;
} i_64, u_64;

ENDCFG
}

config <<'ENDCFG' if is_big_endian;
#define NATIVE_BIG_ENDIAN

ENDCFG

config <<'ENDCFG';
#endif
ENDCFG

close OUT;
