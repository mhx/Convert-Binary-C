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
# $Date: 2003/01/08 06:58:06 +0000 $
# $Revision: 8 $
# $Snapshot: /Convert-Binary-C/0.11 $
# $Source: /ctlib/arch.pl $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

use Config;

open OUT, ">".shift or die $!;

%cfg = %Config;  # because we modify some values in %cfg

%use = (
  '64bit'      => 1,
  'longlong'   => 1,
  'longdouble' => 1,
);

if( $Config{osname} eq 'hpux' and $Config{cc} eq 'cc' and
    $Config{osvers} =~ /(\d+)\.(\d+)/ and $1 < 11 ) {
  # At least some versions of HP's cc compiler have a broken
  # preprocessor/compiler implementation of 64-bit data types.
  $use{'64bit'}    = 0;
  $use{'longlong'} = 0;
}

for( qw( 64BIT LONGLONG LONGDOUBLE ) ) {
  exists $ENV{"CBC_USE$_"} and $use{lc $_} = $ENV{"CBC_USE$_"};
}

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

# make the i_8 explicitly signed
# (i8type was plain 'char' on an IPAQ system where 'char' was unsigned)
if( $cfg{i8type} eq 'char' ) {
  $cfg{i8type} = 'signed char';
}

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

ENDCFG

if( $use{longdouble} && $cfg{d_longdbl} eq 'define' ) {
config <<'ENDCFG';
#define HAVE_LONG_DOUBLE
ENDCFG
}
elsif( $use{longdouble} == 0 ) {
  print "DISABLED long double support\n";
}

if( $use{longlong} && $cfg{d_longlong} eq 'define' ) {
config <<'ENDCFG';
#define HAVE_LONG_LONG
ENDCFG
}
elsif( $use{longlong} == 0 ) {
  print "DISABLED long long support\n";
}

if( $use{'64bit'} && $cfg{d_quad} eq 'define' ) {
config <<'ENDCFG';
#define NATIVE_64_BIT_INTEGER

/* 64-bit integer data types */
typedef ${i64type} i_64;
typedef ${u64type} u_64;

ENDCFG
}
elsif( $use{'64bit'} && $cfg{d_longlong} eq 'define' and $cfg{longlongsize} == 8 ) {
config <<'ENDCFG';
#define NATIVE_64_BIT_INTEGER

/* 64-bit integer data types */
typedef signed long long i_64;
typedef unsigned long long u_64;

ENDCFG
}
else {
if( $use{'64bit'} == 0 ) {
  print "DISABLED 64-bit support\n";
}
config <<'ENDCFG';
/* no native 64-bit support */
typedef struct {
  ${u32type} h;
  ${u32type} l;
} u_64;

typedef struct {
  ${i32type} h;
  ${u32type} l;
} i_64;

ENDCFG
}

config <<'ENDCFG' if is_big_endian;
#define NATIVE_BIG_ENDIAN

ENDCFG

config <<'ENDCFG';
/* 32-bit integer data types */
typedef ${i32type} i_32;
typedef ${u32type} u_32;

/* 16-bit integer data types */
typedef ${i16type} i_16;
typedef ${u16type} u_16;

/* 8-bit integer data types */
typedef ${i8type} i_8;
typedef ${u8type} u_8;

ENDCFG

config <<'ENDCFG';
#endif
ENDCFG

close OUT;
