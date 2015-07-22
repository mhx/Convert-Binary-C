################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/06/03 16:41:15 +0100 $
# $Revision: 3 $
# $Snapshot: /Convert-Binary-C/0.01 $
# $Source: /t/e_enum.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN { plan tests => 170 }

eval {
  $p = new Convert::Binary::C ByteOrder => 'BigEndian',
                              EnumSize  => 4,
                              EnumType  => 'Integer';
};
ok($@,'',"failed to create Convert::Binary::C object");

eval {
$p->parse(<<'EOF');
enum ubyte {
  ZERO, ONE, TWO, THREE,
  ANOTHER_ONE = 1,
  BIGGEST = 255
};

enum sbyte {
  MINUS_TWO = -2, MINUS_ONE, Z_E_R_O, PLUS_ONE,
  NEG = -1, NOTHING, POS,
  MIN = -128, MAX = 127
};

enum uword { W_BIGGEST = 65535 };
enum sword { W_MIN = -32768, W_MAX = 32767 };

enum ulong { WHATEVER =  65536 };
enum slong { NEGATIVE = -32769 };

EOF
};
ok($@,'',"parse() failed");

# catch all warnings for further checks

$SIG{__WARN__} = sub { push @warn, $_[0] };
sub chkwarn {
  ok( scalar @warn, scalar @_, "wrong number of warnings" );
  ok( shift @warn, $_ ) for @_;
  @warn = ();
}

#-----------------------------------------------------
# check sizeof()
#-----------------------------------------------------

ok($p->sizeof('ubyte'),4,"ubyte size");
ok($p->sizeof('sbyte'),4,"sbyte size");
ok($p->sizeof('uword'),4,"uword size");
ok($p->sizeof('sword'),4,"sword size");
ok($p->sizeof('ulong'),4,"ulong size");
ok($p->sizeof('slong'),4,"slong size");

eval { $p->EnumSize( 0 ) };
ok($@,'',"failed in configure"); chkwarn;

ok($p->sizeof('ubyte'),1,"ubyte size");
ok($p->sizeof('sbyte'),1,"sbyte size");
ok($p->sizeof('uword'),2,"uword size");
ok($p->sizeof('sword'),2,"sword size");
ok($p->sizeof('ulong'),4,"ulong size");
ok($p->sizeof('slong'),4,"slong size");

#-----------------------------------------------------
# check enum types
#-----------------------------------------------------

@ubyte = (
  [  0, 'ZERO'     ],
  [  1, 'ONE'      ],
  [  2, 'TWO'      ],
  [  3, 'THREE'    ],
  [ 42, '<ENUM:42>'],
  [255, 'BIGGEST'  ],
);

for( @ubyte ) {
  eval { $pk = $p->unpack( 'ubyte', pack('C', $_->[0]) ) };
  ok($@,'',"failed for (@$_)"); chkwarn;
  ok($_->[0] == $pk); chkwarn;
  ok($_->[1] ne $pk); chkwarn;
}

eval { $p->EnumType( 'String' ) };
ok($@,'',"failed in configure"); chkwarn;

for( @ubyte ) {
  eval { $pk = $p->unpack( 'ubyte', pack('C', $_->[0]) ) };
  ok($@,'',"failed for (@$_)"); chkwarn;
  ok($_->[0] != $pk ? 1 : $_->[0] == 0);
  chkwarn( qr/Argument "$pk" isn't numeric/ );
  ok($_->[1] eq $pk); chkwarn;
}

eval { $p->EnumType( 'Both' ) };
ok($@,'',"failed in configure"); chkwarn;

for( @ubyte ) {
  eval { $pk = $p->unpack( 'ubyte', pack('C', $_->[0]) ) };
  ok($@,'',"failed for (@$_)"); chkwarn;
  ok($_->[0] == $pk); chkwarn;
  ok($_->[1] eq $pk); chkwarn;
}

#-----------------------------------------------------
# check pack/unpack
# (some of these may issue warnings in the future)
#-----------------------------------------------------

@sbyte = (
  ['ZERO',     0, 'Z_E_R_O'  ],
  ['NOTHING',  0, 'Z_E_R_O'  ],
  [-2,        -2, 'MINUS_TWO'],
  ['-2',      -2, 'MINUS_TWO'],
  ['POS',      1, 'PLUS_ONE' ],
  ['THREE',    3, '<ENUM:3>' ],
);

for( @sbyte ) {
  eval { $pk = $p->unpack( 'sbyte', $p->pack( 'sbyte', $_->[0] ) ) };
  ok($@,'',"failed for (@$_)"); chkwarn;
  ok($_->[1] == $pk); chkwarn;
  ok($_->[2] eq $pk); chkwarn;
}

