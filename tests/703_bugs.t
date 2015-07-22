################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/01/01 09:38:21 +0000 $
# $Revision: 2 $
# $Source: /tests/703_bugs.t $
#
################################################################################
#
# Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test::More tests => 8;
use Convert::Binary::C @ARGV;

my $code = <<ENDC;

struct test {
  unsigned a:2;
  unsigned b:2;
  unsigned c:28;
};

ENDC

my $c1 = Convert::Binary::C->new(ByteOrder => 'LittleEndian');

eval {
  $c1->parse($code);
  $c1->ByteOrder('BigEndian');
};

is($@, '', 'parse/configure');

my $c2 = Convert::Binary::C->new(ByteOrder => 'LittleEndian');

eval {
  $c2->ByteOrder('BigEndian');
  $c2->parse($code);
};

is($@, '', 'configure/parse');

my $data = pack "N", 0x60000003;

for my $c ($c1, $c2) {
  my $t = $c->unpack('test', $data);
  is($t->{a}, 1, 'a');
  is($t->{b}, 2, 'b');
  is($t->{c}, 3, 'c');
}
