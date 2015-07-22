#!/usr/bin/perl -w
use strict;
use Convert::Binary::C;
use Data::Dumper;
use Devel::Peek;

my $code = do { local $/; <DATA> };

my $p = new Convert::Binary::C ByteOrder   => 'BigEndian',
                               IntSize     => 4,
                               PointerSize => 4,
                               EnumSize    => 0,
                               Alignment   => 4;

$p->parse( $code );

print Data::Dumper->Dump( [[$p->enum],[$p->struct],[$p->typedef]],
                          [qw(*enum *struct *typedef)] );

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

typedef unsigned long U32;

struct STRUCT_SV {
  void *sv_any;
  U32	sv_refcnt;
  U32	sv_flags;
};

typedef union {
  int abc[2];
  struct xxx {
    int a;
    int b;
  }   ab[3][4];
} test;
