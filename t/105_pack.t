################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/10/13 13:45:48 +0100 $
# $Revision: 6 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /t/105_pack.t $
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

BEGIN { plan tests => 105 }

eval { $p = new Convert::Binary::C ByteOrder => 'BigEndian' };
ok($@,'',"failed to create Convert::Binary::C object");

eval {
$p->parse(<<'EOF');
enum _enum { FOO };
struct _struct { int foo[1]; };
typedef struct _struct _typedef;
typedef int scalar;
typedef int array[1];
typedef struct { array foo; } hash;
typedef struct { int foo[1]; } hash2;
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

#===================================================================
# check errors (2 tests)
#===================================================================

eval { $packed = $p->unpack( 'foo', 0 ) };
ok( $@, qr/Type of arg 2 to unpack must be string/ ); chkwarn;

eval { $packed = $p->pack( 'foo', 0, 0 ) };
ok( $@, qr/Type of arg 3 to pack must be string/ ); chkwarn;

#===================================================================
# check scalars
#===================================================================

$val  = 1234567890;
$data = pack 'N', $val;

eval { $packed = $p->unpack( 'scalar', $data ) };
ok($@,'',"failed in unpack"); chkwarn;
ok($packed,$val);

eval { $packed = $p->unpack( 'scalar', 'foo' ) };
ok($@,'',"failed in unpack");
chkwarn( qr/Data too short/ );
ok(not defined $packed);

eval { $packed = $p->pack( 'scalar', $val ) };
ok($@,'',"failed in pack"); chkwarn;
ok($packed,$data);

eval { $packed = $p->pack( 'scalar', [4711] ) };
ok($@,'',"failed in pack");
chkwarn( qr/'scalar' should be a scalar value/ );
ok($packed,pack('N',0));

$packed = $data;
eval { $p->pack( 'scalar', undef, $packed ) };
ok($@,'',"failed in pack"); chkwarn;
ok($packed,$data);

$packed = $data;
eval { $p->pack( 'scalar', [4711], $packed ) };
ok($@,'',"failed in pack");
chkwarn( qr/'scalar' should be a scalar value/ );
ok($packed,$data);

$packed = $data;
eval { $p->pack( 'scalar', {foo=>4711}, $packed ) };
ok($@,'',"failed in pack");
chkwarn( qr/'scalar' should be a scalar value/ );
ok($packed,$data);

#===================================================================
# check arrays
#===================================================================

eval { $packed = $p->unpack( 'array', $data ) };
ok($@,'',"failed in unpack"); chkwarn;
ok(ref $packed, 'ARRAY');
ok(scalar @$packed, 1);
ok($packed->[0], $val);

eval { $packed = $p->unpack( 'array', 'foo' ) };
ok($@,'',"failed in unpack");
chkwarn( qr/Data too short/ );
ok(ref $packed, 'ARRAY');
ok(scalar @$packed, 1);
ok(not defined $packed->[0]);

eval { $packed = $p->pack( 'array', [$val] ) };
ok($@,'',"failed in pack"); chkwarn;
ok($packed,$data);

eval { $packed = $p->pack( 'array', $val ) };
ok($@,'',"failed in pack");
chkwarn( qr/'array' should be an array reference/ );
ok($packed, pack('N',0));

eval { $packed = $p->pack( 'array', {foo=>4711} ) };
ok($@,'',"failed in pack");
chkwarn( qr/'array' should be an array reference/ );
ok($packed, pack('N',0));

$packed = '12345678';
eval { $p->pack( 'array', [$val], $packed ) };
ok($@,'',"failed in pack"); chkwarn;
ok($packed,$data.'5678');

$packed = '12';
eval { $p->pack( 'array', $val, $packed ) };
ok($@,'',"failed in pack");
chkwarn( qr/'array' should be an array reference/ );
ok($packed,'12'.pack('n',0));

#===================================================================
# check hashes (structs)
#===================================================================

eval { $packed = $p->unpack( 'hash', $data ) };
ok($@,'',"failed in unpack"); chkwarn;
ok(ref $packed,'HASH');
ok(scalar keys %$packed, 1);
ok(ref $packed->{foo},'ARRAY');
ok(scalar @{$packed->{foo}},1);
ok($packed->{foo}[0],$val);

eval { $packed = $p->unpack( 'hash', 'foo' ) };
ok($@,'',"failed in unpack");
chkwarn( qr/Data too short/ );
ok(ref $packed,'HASH');
ok(scalar keys %$packed, 1);
ok(ref $packed->{foo},'ARRAY');
ok(scalar @{$packed->{foo}},1);
ok(not defined $packed->{foo}[0]);

eval { $packed = $p->pack( 'hash', {foo => [$val]} ) };
ok($@,'',"failed in pack"); chkwarn;
ok($packed,$data);

eval { $packed = $p->pack( 'hash', [4711] ) };
ok($@,'',"failed in pack");
chkwarn( qr/'hash' should be a hash reference/ );
ok($packed,pack('N',0));

eval { $packed = $p->pack( 'hash', {foo => 4711} ) };
ok($@,'',"failed in pack");
chkwarn( qr/'foo' should be an array reference/ );
ok($packed,pack('N',0));

eval { $packed = $p->pack( 'hash2', {foo => 4711} ) };
ok($@,'',"failed in pack");
chkwarn( qr/'foo' should be an array reference/ );
ok($packed,pack('N',0));

$packed = '12345678';
eval { $p->pack( 'hash', {foo => [$val]}, $packed ) };
ok($@,'',"failed in pack"); chkwarn;
ok($packed,$data.'5678');

$packed = '12';
eval { $packed = $p->pack( 'hash', [4711], $packed ) };
ok($@,'',"failed in pack");
chkwarn( qr/'hash' should be a hash reference/ );
ok($packed,'12'.pack('n',0));

$packed = '1234';
eval { $packed = $p->pack( 'hash', {foo => 4711}, $packed ) };
ok($@,'',"failed in pack");
chkwarn( qr/'foo' should be an array reference/ );
ok($packed,'1234');

$packed = '1234';
eval { $packed = $p->pack( 'hash2', {foo => 4711}, $packed ) };
ok($@,'',"failed in pack");
chkwarn( qr/'foo' should be an array reference/ );
ok($packed,'1234');

