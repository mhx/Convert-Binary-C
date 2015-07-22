################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/11/24 14:34:22 +0000 $
# $Revision: 7 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /t/102_misc.t $
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

BEGIN {
  $C99 = Convert::Binary::C::feature( 'c99' );
  plan tests => 108
}

ok( defined $C99 );

#===================================================================
# perform some average stuff
#===================================================================

eval {
  $p = new Convert::Binary::C PointerSize => 4,
                              EnumSize    => 4,
                              IntSize     => 4,
                              LongSize    => 4,
                              Alignment   => 2,
                              ByteOrder   => 'BigEndian',
                              EnumType    => 'String';
  $q = new Convert::Binary::C;
};
ok($@,'');

#-----------------------------------
# create some average ( ?? :-) code
#-----------------------------------

$code = <<'CCODE';
#define ONLY_ONE 1

typedef struct abc abc_type;

typedef struct never ever;

struct abc {
  abc_type *p1;
#if ONLY_ONE > 1
  abc_type *p2;
#endif
};

typedef unsigned long u32;

#define Day( which )  \
        which ## DAY

typedef enum {
  Day( MON ),
  Day( TUES ),
  Day( WEDNES ),
} day;

# \
  define  __SIX__ \
  ( sizeof( unsigned char * ) + sizeof( short ) )

   # define SIXTEEN \
     (sizeof "Hello\"\xfworld\069!")

typedef union zap {
  signed long  za[__SIX__];
  short        zb[SIXTEEN];
  char         zc[sizeof(struct never (*[2][3])[4])];
  ever        *zd[sizeof( abc_type )];
} ZAP;

CCODE

#-----------------------
# try to parse the code
#-----------------------

eval {
  $p->parse( $code );
  $q->parse( $code );
};
ok($@,'');

#------------------------
# reconfigure the parser
#------------------------

eval {
  $p->configure( Alignment => 8, EnumSize => 0 );
};
ok($@,'');

#--------------------------------
# and parse some additional code
#--------------------------------

$code = <<'CCODE';
typedef struct {
  abc_type xxx;
  u32 dusel, *fusel;
  int musel[((1<<1)+4)&0x00000002];
  union {
    char bytes[(12/2)%4][(0x10|010)>>3];
    day  today;
    long value;
  } test;
  struct ints fubar;
  union zap hello;
} husel;

#pragma pack( push, 1 )

struct packer {
  char  i;
  short am;
  char  really;
  long  packed;
};

#pragma pack( pop )

struct nopack {
  char  i;
  short am;
  char  not;
  long  packed;
};

CCODE

$c_code = <<'CCODE' . $code;
struct ints { int a, b, c; };

CCODE

$c99_code = <<'CCODE' . $code;
#define \
MYINTS( ... \
) { int __VA_ARGS__; }

struct ints MYINTS( a, b, c );

CCODE

#-----------------------
# try to parse the code
#-----------------------

$SIG{__WARN__} = sub { $warn = $_[0] };

if( $C99 ) {
  eval {
    $q->HasMacroVAARGS( 0 );
    $q->parse( $c99_code );
  };
  ok($warn,qr/invalid macro argument/);
  ok($@,qr/parse error/);

  eval { $p->parse( $c99_code ) };
  ok($@,'');
}
else {
  eval { $q->parse( $c99_code ) };
  ok($warn,qr/invalid macro argument/);
  ok($@,qr/parse error/);

  eval { $p->parse( $c_code ) };
  ok($@,'');
}

$SIG{__WARN__} = 'DEFAULT';

#------------------------
# reconfigure the parser
#------------------------

eval { $p->Alignment( 4 ) };
ok($@,'');

#------------------------
# now try some unpacking
#------------------------

# on a pack()ed struct

$data = pack( 'cnCN', -47, 0x1234, 0x55, 2000000000 );

eval { $result = $p->unpack( 'packer', $data ) };
ok($@,'');

$refres = {
  i      => -47,
  am     => 0x1234,
  really => 0x55,
  packed => 2000000000,
};

reccmp( $refres, $result );

# on a 'normal' struct

$data = pack( 'cxnCx3N', -47, 0x1234, 0x55, 2000000000 );

eval { $result = $p->unpack( 'nopack', $data ) };
ok($@,'');

$refres = {
  i      => -47,
  am     => 0x1234,
  not    => 0x55,
  packed => 2000000000,
};

reccmp( $refres, $result );

#-----------------------
# test something bigger
#-----------------------

$data = pack( "N5c8N3C48", 123, 4711, 0xDEADBEEF,
              -42, 42, 1, 0, 0, 0, -2, 3, 0, 0,
              -10000, 5000, 8000, 1..48 );

eval { $result = $p->unpack( 'husel', $data ) };
ok($@,'');

eval { undef $p };
ok($@,'');


$refres = {
  xxx   => { p1 => 123 },
  dusel => 4711,
  fusel => 0xDEADBEEF,
  musel => [ -42, 42 ],
  test  => {
             bytes => [ [ 1, 0, 0 ], [ 0, -2, 3 ] ],
             today => 'TUESDAY',
             value => 16777216,
           },
  fubar => {
             a => -10000,
             b =>   5000,
             c =>   8000,
           },
  hello => {
             za => [16909060, 84281096, 151653132, 219025168, 286397204, 353769240],
             zb => [258, 772, 1286, 1800, 2314, 2828, 3342, 3856,
                    4370, 4884, 5398, 5912, 6426, 6940, 7454, 7968],
             zc => [1..24],
             zd => [16909060, 84281096, 151653132, 219025168],
           },
};

reccmp( $refres, $result );

#------------------------------------------------
# test different cases for pack with 3 arguments
#------------------------------------------------

eval {
  $p = new Convert::Binary::C;
  $p->parse( "typedef struct { unsigned char a, b, c, d; } s;" );
  $packed = pack 'C*', 1 .. 2;
  $a = $p->pack( 's', { a => 42, d => 13 }, $packed );
  $b = $packed;
  $p->pack( 's', { b => 42, c => 13 }, $packed );
  $c = $packed;
  $packed = pack 'C*', 1 .. 6;
  $d = $p->pack( 's', { a => 42, d => 13 }, $packed );
  $e = $packed;
  $p->pack( 's', { b => 42, c => 13 }, $packed );
  $f = $packed;
};
ok($@,'',"failed during 3-arg pack test");

ok($a,pack('C*',42,2,0,13));
ok($b,pack('C*',1,2));
ok($c,pack('C*',1,42,13,0));
ok($d,pack('C*',42,2,3,13,5,6));
ok($e,pack('C*',1,2,3,4,5,6));
ok($f,pack('C*',1,42,13,4,5,6));


sub reccmp
{
  my($ref, $val) = @_;

  my $id = ref $ref;

  unless( $id ) {
    ok( $ref, $val );
    return;
  }

  if( $id eq 'ARRAY' ) {
    ok( @$ref == @$val );
    for( 0..$#$ref ) {
      reccmp( $ref->[$_], $val->[$_] );
    }
  }
  elsif( $id eq 'HASH' ) {
    ok( @{[keys %$ref]} == @{[keys %$val]} );
    for( keys %$ref ) {
      reccmp( $ref->{$_}, $val->{$_} );
    }
  }
}
