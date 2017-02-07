#!/usr/bin/perl -w
use strict;
use Convert::Binary::C;
use Data::Dumper;
use Devel::Peek;

my $code = do { local $/; <DATA> };

my $p = Convert::Binary::C->new(
    ByteOrder   => 'BigEndian',
    IntSize     => 4,
    PointerSize => 4,
    EnumSize    => 0,
    Warnings    => 1,
    Alignment   => 4
);

$p->parse( $code );

print Data::Dumper->Dump( [[$p->enum],[$p->struct],[$p->typedef]],
                          [qw(*enum *struct *typedef)] );

print Data::Dumper->Dump( [[$p->enums],[$p->structs],[$p->typedefs]],
                          [qw(*enums *structs *typedefs)] );

my @enum   = map { $_->{identifier} || () } $p->enum;
my @struct = map { $_->{identifier} || () } $p->struct;

my %enum = map %{$_->{enumerators}||{}}, $p->enum;

print Data::Dumper->Dump( [[@enum],[@struct],{%enum}],
                          [qw(*enum *struct *enum)] );

my(@structs, @unions);

map {
  push @{$_->{type} eq 'union' ? \@unions : \@structs},
       $_->{identifier} || ()
} grep $_->{declarations}, $p->struct;

print Data::Dumper->Dump( [[@structs],[@unions]],
                          [qw(*structs *unions)] );

print $p->HasVOID, "\n";
$p->HasVOID( 0 );
print $p->HasVOID, "\n";
$p->HasVOID( 1 );
$p->HasVOID( 1 );
print $p->HasVOID, "\n";
print $p->IntSize, "\n";
print $p->ByteOrder, "\n";
print $p->HashSize, "\n";
$p->HashSize('Tiny');
print $p->HashSize, "\n";

$p->Define( 'A' );
$p->Define( 'B', 'C' );
$p->Define( ['A', 'B'] );
#$p->Define( 'C', ['D'] );

print Dumper( $p->Define );

print Dumper( $p->configure );

$p->configure;
$p->configure("Foo");
#my $b = $p->configure("Foo");
my $c = $p->configure("IntSize");

$p->HasVOID;

print $p->member( 'struct test', 100 );

print Dumper(
  $p->def( 'not' ),
  $p->def( 'ptr' ),
  $p->def( 'foo' ),
  $p->def( 'bar' ),
  $p->def( 'xxx' ),
);

__DATA__

typedef struct __not  not;
typedef struct __not *ptr;

struct foo {
  enum bar *xxx;
};

/*
#define FOO  1
#define FOO  2

#include <foo.h>

#ifdef FOO BLABLA
#endif

typedef enum test {
  foo = sizeof( "HelloWorld" ),
} test;

enum { A, B, C=4711 };

enum evil { MONDAY };

struct test {
  enum yyy *xxx;
  int (*test[2])[3];
  union ref *yyy;
}

union baro {
  enum yyy *xxx;
  union hdlbrmft { int i; } j;
  struct {
    int i;
  } k;
};
*/
