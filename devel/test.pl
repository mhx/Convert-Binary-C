#!/usr/bin/perl -w
use strict;
use Convert::Binary::C debug => '';
use Data::Dumper;
use Devel::Peek;

my $code = do { local $/; <DATA> };

my $p = new Convert::Binary::C ByteOrder   => 'BigEndian',
                               IntSize     => 4,
                               PointerSize => 4,
                               EnumSize    => 0,
                               Alignment   => 4;

$p->parse( $code );

print Dumper( $p->member( 'test', $p->offsetof( 'test', 'ab[1][1].b' ) ) );

# print Dumper( $p->spec( qw( foobar test test.ab test.ab[1] test.ab[1][1]
#                             test.ab[1][1].a test.ab[1][1].b test.ab[1][1].c ) ) );

# print Dumper( $p->unpack( 'test.ab[2]', pack("N*", (1e7, 314159)x2) ) );

# print Data::Dumper->Dump( [[$p->enum],[$p->struct],[$p->typedef]],
#                           [qw(*enum *struct *typedef)] );

__DATA__

enum __socket_type
{
  SOCK_STREAM    = 1,
  SOCK_DGRAM     = 2,
  SOCK_RAW       = 3,
  SOCK_RDM       = 4,
  SOCK_SEQPACKET = 5,
  SOCK_PACKET    = 10
};

typedef unsigned long __u32__;
typedef __u32__ U32;

struct STRUCT_SV {
  void *sv_any;
  U32	sv_refcnt;
  U32	sv_flags;
};

typedef union {
  int abc[2];
  struct xxx {
    int a;
    U32 b;
    U32 *c;
  }   ab[3][4];
} test;
