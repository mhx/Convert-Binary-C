#!/usr/bin/perl -w
use strict;
use Convert::Binary::C;
# use Convert::Binary::C debug => 'all', dbfile => './debug.out';
use Data::Dumper;

my $code = do { local $/; <DATA> };

my $p = new Convert::Binary::C;
$p->parse( $code );

print Data::Dumper->Dump( [[$p->enum],[$p->struct],[$p->typedef]],
                          [qw(*enum *struct *typedef)] );

# print Data::Dumper->Dump( [[$p->enums],[$p->structs],[$p->typedefs]],
#                           [qw(*enums *structs *typedefs)] );

# my $x = $p->pack( 'foo', { a => 2 } );
# $p->pack( 'foo', { b => 3 }, $x );
# my $r = $p->unpack( 'foo', $p->pack( 'foo', { c => 4 }, $x ) );
# print Dumper( $p->unpack( 'foo', $x ) );
# print Dumper( $r );
# 
# $p->sizeof( 'foo' );
# 
# my $y = 'x'x4;
# print Dumper( $p->pack( 'foo', { c => 3 }, $y ) );
# print $p->sizeof( 'array' ), "\n";
# 
# 
# my $s = $p->unpack( 'foo', '' );
# print Dumper( $s );
# 
# my $d = pack 'C*', 1 .. $p->sizeof( 'foo' );
# print Dumper( $p->unpack( 'foo', $d ) );
# print Dumper( $p->unpack( 'foo', $p->pack( 'foo', $s ) ) );
# print Dumper( $p->unpack( 'foo', $p->pack( 'foo', $s, $d ) ) );
 
__DATA__

struct bitfield {
  int seven:7;
  int :1;
  int four:4, :0;
  int integer;
};

/*
struct foo {
  int a, b, c;
  struct {
    int d, e;
  }   f[2];
};

typedef int array[10];
*/
