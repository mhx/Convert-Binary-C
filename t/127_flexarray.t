################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/03/17 21:06:22 +0000 $
# $Revision: 1 $
# $Snapshot: /Convert-Binary-C/0.50 $
# $Source: /t/127_flexarray.t $
#
################################################################################
#
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN { plan tests => 30 }

my $c = new Convert::Binary::C IntSize => 4, ShortSize => 2, Alignment => 4;

$c->parse(<<ENDC);

struct flex1 {

  int   a;
  char  b;

  struct {
    char  a;
    short b;
    char  c;
    int   d[][4];
  }     c;

  char  d[5];

  struct {
    char  a;
    short b[][4];
  }     e[];

};

struct flex2 {

  int  a;
  struct {
    char  a[2];
    short b;
  } b[];

};

typedef int incomplete[];
typedef int incomplete2[1];

ENDC

ok($c->sizeof('flex1'), 24);
ok($c->offsetof('flex1', 'e[1].a'), 24);
ok($c->offsetof('flex1', 'e[0].b[0][0]'), 24);

ok($c->sizeof('flex2'), 4);
ok($c->offsetof('flex2', 'b[0].b'), 6);

ok($c->sizeof('incomplete'), 0);
ok($c->offsetof('incomplete', '[10]'), 40);

my $u;

my $d = pack 'C*', 1 .. 4;
$u = $c->unpack('flex2', $d);
ok(scalar @{$u->{b}}, 0);

$d .= pack 'C', 5;
$u = $c->unpack('flex2', $d);
ok(scalar @{$u->{b}}, 1);
ok(scalar @{$u->{b}[0]{a}}, 2);
ok($u->{b}[0]{a}[0], 5);
ok(not defined $u->{b}[0]{b});

$d .= pack 'C', 6;
$u = $c->unpack('flex2', $d);
ok(scalar @{$u->{b}}, 1);
ok(scalar @{$u->{b}[0]{a}}, 2);
ok($u->{b}[0]{a}[0], 5);
ok($u->{b}[0]{a}[1], 6);
ok(not defined $u->{b}[0]{b});

$d .= pack 'C', 7;
$u = $c->unpack('flex2', $d);
ok(scalar @{$u->{b}}, 1);
ok(scalar @{$u->{b}[0]{a}}, 2);
ok($u->{b}[0]{a}[0], 5);
ok($u->{b}[0]{a}[1], 6);
ok(exists $u->{b}[0]{b});
ok(not defined $u->{b}[0]{b});

$d .= pack 'C', 8;
$u = $c->unpack('flex2', $d);
ok(scalar @{$u->{b}}, 1);
ok(scalar @{$u->{b}[0]{a}}, 2);
ok($u->{b}[0]{a}[0], 5);
ok($u->{b}[0]{a}[1], 6);
ok(exists $u->{b}[0]{b});
ok(defined $u->{b}[0]{b});

$d .= pack 'C', 9;
$u = $c->unpack('flex2', $d);
ok(scalar @{$u->{b}}, 2);
