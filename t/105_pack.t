################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/09/09 19:44:13 +0100 $
# $Revision: 13 $
# $Snapshot: /Convert-Binary-C/0.47 $
# $Source: /t/105_pack.t $
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

BEGIN { plan tests => 184 }

eval {
  $p = new Convert::Binary::C ByteOrder     => 'BigEndian'
                            , UnsignedChars => 0
};
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
typedef char c_8;
typedef unsigned char u_8;
typedef signed char i_8;
typedef long double ldbl;
typedef struct { char a; int b[3][3]; } undef_test[3];
struct zero { int :0; };
EOF
};
ok($@,'',"parse() failed");

# catch all warnings for further checks

$SIG{__WARN__} = sub { push @warn, $_[0] };
sub chkwarn {
  my $fail = 0;
  if( @warn != @_ ) {
    print "# wrong number of warnings (got ", scalar @warn,
                               ", expected ", scalar @_, ")\n";
    $fail++;
  }
  for my $ix ( 0 .. $#_ ) {
    my $e = $_[$ix];
    my $w = $warn[$ix];
    unless( $w =~ ref($e) ? $e : qr/\Q$e\E/ ) {
      print "# wrong warning, expected $e, got $w\n";
      $fail++;
    }
  }
  if( $fail ) { print "# $_" for @warn }
  ok( $fail, 0, "warnings check failed" );
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

#===================================================================
# check unsigned chars (72 tests)
#===================================================================

my %tests = (
  c_8             => {
                       pack   => { in => 255, out => pack('C', 255) },
                       unpack => { in => pack('C', 255), out => -1 },
                     },
  i_8             => {
                       pack   => { in => 255, out => pack('C', 255) },
                       unpack => { in => pack('C', 255), out => -1 },
                     },
  u_8             => {
                       pack   => { in => 255, out => pack('C', 255) },
                       unpack => { in => pack('C', 255), out => 255 },
                     },
  'char'          => {
                       pack   => { in => 255, out => pack('C', 255) },
                       unpack => { in => pack('C', 255), out => -1 },
                     },
  'signed char'   => {
                       pack   => { in => 255, out => pack('C', 255) },
                       unpack => { in => pack('C', 255), out => -1 },
                     },
  'unsigned char' => {
                       pack   => { in => 255, out => pack('C', 255) },
                       unpack => { in => pack('C', 255), out => 255 },
                     },
);

uchar_test( %tests );
$p->UnsignedChars(1);
$tests{$_}{unpack}{out} = 255 for qw( c_8 char );
uchar_test( %tests );


sub uchar_test
{
  my %tests = @_;
  for my $t ( keys %tests ) {
    for my $m ( keys %{$tests{$t}} ) {
      my $res = eval { $p->$m( $t, $tests{$t}{$m}{in} ) };
      ok($@,'',"failed in $m"); chkwarn;
      ok($res, $tests{$t}{$m}{out}, "$m( '$t', $tests{$t}{$m}{in} ) != $tests{$t}{$m}{out}");
    }
  }
}

#===================================================================
# check long doubles (2 tests)
#===================================================================

eval { $packed = $p->pack('ldbl', 3.14159) };
ok($@,'',"failed in pack");
my $null = pack 'C*', (0) x length($packed);
if( $packed eq $null ) {
  chkwarn( qr/Cannot pack long doubles/ );
  eval { $packed = $p->unpack('ldbl', $packed) };
  ok($@,'',"failed in unpack");
  chkwarn( qr/Cannot unpack long doubles/ );
  ok($packed,0.0);
}
else {
  chkwarn();
  eval { $packed = $p->unpack('ldbl', $packed) };
  ok($@,'',"failed in unpack");
  chkwarn();
  ok( $packed-3.14159 < 0.0001 );
}

#===================================================================
# check for warnings when explicitly passing undef (1 test)
#===================================================================

$val = [ undef, { b => [undef, [undef, 2]] } ];  # undef_test[1].b[1][1] = 2
eval { $packed = $p->pack('undef_test', $val) };
ok($@,'',"failed in pack");
chkwarn;

#===================================================================
# check for existence of members with undef values
#===================================================================

$val = $p->sizeof( 'undef_test[0]' );
chkwarn();

$packed = 'x' x $val;
eval { $val = $p->unpack( 'undef_test', $packed ) };
ok($@,'',"failed in unpack");
chkwarn( qr/Data too short/ );

ok(reccmp_keys($val->[0], $val->[1]), '', 'deep compare failed');
ok(reccmp_keys($val->[0], $val->[2]), '', 'deep compare failed');
ok(reccmp_keys($val->[1], $val->[2]), '', 'deep compare failed');
chkwarn();

ok(rec_write($val->[0]), '', 'write check failed');
ok(rec_write($val->[1]), '', 'write check failed');
ok(rec_write($val->[2]), '', 'write check failed');
chkwarn();

#===================================================================
# bug #3753 - pack() on zero size type caused segfault / bus error
#===================================================================

ok($p->pack('zero', {}), '', 'pack on zero size type (bug #3753)');
chkwarn( qr/Bitfields are unsupported in pack\('zero'\)/,
         qr/Zero-sized type 'zero' used in pack/ );

ok(reccmp_keys({}, $p->unpack('zero', '')), '', 'unpack on zero size type');
chkwarn( qr/Bitfields are unsupported in pack\('zero'\)/,
         qr/Zero-sized type 'zero' used in unpack/ );


sub rec_write
{
  my $ref = shift;
  my $r = ref $ref;
  if( $r eq 'HASH' ) {
    for my $k ( keys %$ref ) {
      if( ref $ref->{$k} ) {
        $r = rec_write( $ref->{$k} );
        $r and return $r;
      }
      else {
        eval { $ref->{$k} = 42 };
        $@ and return $@;
      }
    }
  }
  elsif( $r eq 'ARRAY' ) {
    for my $i ( 0 .. $#$ref ) {
      if( ref $ref->[$i] ) {
        $r = rec_write( $ref->[$i] );
        $r and return $r;
      }
      else {
        eval { $ref->[$i] = 42 };
        $@ and return $@;
      }
    }
  }
  return '';
}

sub reccmp_keys
{
  my($ref,$chk) = @_;
  my $r = ref $ref;
  if( $r eq 'HASH' ) {
    defined $chk or return "undefined hash reference";
    keys(%$ref) == keys(%$chk) or return "key counts differ";
    for my $k ( keys %$ref ) {
      exists $chk->{$k} or return "reference key '$k' not found";
      $r = reccmp_keys( $ref->{$k}, $chk->{$k} );
      $r and return $r;
    }
  }
  elsif( $r eq 'ARRAY' ) {
    defined $chk or return "undefined array reference";
    @$ref == @$chk or return "array lengths differ";
    for my $i ( 0 .. $#$ref ) {
      $r = reccmp_keys( $ref->[$i], $chk->[$i] );
      $r and return $r;
    }
  }
  return '';
}
