################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/11/23 19:23:32 +0000 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.57 $
# $Source: /t/132_native.t $
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

$^W = 1;

BEGIN { plan tests => 59 }

eval {
  $s = Convert::Binary::C::native('IntSize');
};
ok($@, '');
ok($s > 0);

eval {
  $s = Convert::Binary::C::native('foobar');
};
ok($@, qr/^Invalid property 'foobar'/);

eval {
  $s = Convert::Binary::C::native('EnumType');
};
ok($@, qr/^Invalid property 'EnumType'/);

$c = new Convert::Binary::C;
eval {
  $s2 = $c->native('IntSize');
};
ok($@, '');
ok($s2 > 0);
ok($s == $s2);

for (qw( PointerSize IntSize CharSize ShortSize LongSize LongLongSize
         FloatSize DoubleSize LongDoubleSize Alignment CompoundAlignment )) {
  my $nat = $c->native($_);
  ok($nat, Convert::Binary::C::native($_));
  print "# native($_) = $nat\n";
  if (exists $Config{lc $_}) {
    print "#   found \$Config{\L$_\E}\n";
    ok($Config{lc $_}, $c->native($_));
  }
  else {
    ok($c->native($_), qr/^(?:1|2|4|8|12|16)$/);
  }
}

ok($c->native('EnumSize'), qr/^(?:-1|0|1|2|4|8)$/);

ok($c->native('ByteOrder'), qr/^(?:Big|Little)Endian$/);
ok($c->native('ByteOrder'), byte_order());

$nh1 = $c->native;
$nh2 = Convert::Binary::C::native();

ok(join(':', sort keys %$nh1), join(':', sort keys %$nh2));

for (keys %$nh1) {
  ok($nh1->{$_}, $nh2->{$_});
  ok($nh1->{$_}, $c->native($_));
}

sub byte_order
{
  my $byteorder = $Config{byteorder} || unpack( "a*", pack "L", 0x34333231 );
  $byteorder eq '4321' || $byteorder eq '87654321' ? 'BigEndian' : 'LittleEndian';
}

