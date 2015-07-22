################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/03/22 19:38:04 +0000 $
# $Revision: 5 $
# $Snapshot: /Convert-Binary-C/0.50 $
# $Source: /t/123_initializer.t $
#
################################################################################
#
# Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN { plan tests => 17 }

$c = eval { new Convert::Binary::C Include => ['t/include/perlinc',
                                               't/include/include'] };
ok($@,'',"failed to create Convert::Binary::C objects");

eval { $c->parse_file( 't/include/include.c' ) };
ok($@,'',"failed to parse C-file");

$full = $zero = $c->sourcify;

for( $c->typedef_names ) {
  next if $c->sizeof($_) == 0;
  my $pre  = "\n$_ S_$_ = ";
  my $post = ";\n";
  my $init = $c->unpack( $_, $c->pack($_) ); 
  $zero .= $pre . $c->initializer( $_ ) . $post;
  $full .= $pre . $c->initializer( $_, $init ) . $post;
}

$c = eval { new Convert::Binary::C };
ok($@,'',"failed to create Convert::Binary::C objects");

{
  my @warn;
  local $SIG{__WARN__} = sub { push @warn, $_[0] };
  
  eval { $c->clean->parse( $zero ) };
  ok($@,'',"failed to parse zero initialization code");
  
  eval { $c->clean->parse( $full ) };
  ok($@,'',"failed to parse full initialization code");

  ok( @warn == 0 );
}

for my $snip ( split /={40,}/, do { local $/; <DATA> } ) {
  my($code, @tests) = split /-{40,}/, $snip;
  eval { $c->clean->parse($code) };
  ok($@,'',"failed to parse code snippet");
  for my $test ( @tests ) {
    my($id, $ref) = $test =~ /^\s*(\S+)\s*=\s*(.*?)\s*$/;
    my $init = $c->initializer( $id );
    $init =~ s/\s+//g;
    $ref  =~ s/\s+//g;
    print "# ref : $ref\n# init: $init\n";
    ok( $init, $ref, "wrong return value" );
  }
}


__DATA__

/* check that only the first union member is initialized */

typedef union {
  int c[10];
  struct {
    char a, b;
  } d[2];
} uni;

struct xxx {
  int a;
  union {
    struct {
      int a, b;
      uni;
    } a;
    int b;
    int c[10][10];
  }   b;
  int c;
};

-------------------------------------------------------------------------------

xxx = { 0, { { 0, 0, { { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } } } }, 0 }

-------------------------------------------------------------------------------

uni = { { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } }

===============================================================================

/* just another example */

struct foo {
  int a;
  union {
    int a;
    struct {
      union {
        int  a;
        char b;
      } a;
      int b;
    } b;
    char c;
  } b;
  struct {
    int a;
    union {
      struct {
        char a;
        int b;
      } a;
      int b;
    } b;
    char c;
  } c;
  int d;
  struct {
    int xa;
    int ba;
  };
};

-------------------------------------------------------------------------------

foo = { 0, { 0 }, { 0, { { 0, 0 } }, 0 }, 0, { 0, 0 } }

===============================================================================

/* check that bitfields are working */

struct bits {
  int a:3;
  int :0;
  int c:2;
  int d:4;
};

-------------------------------------------------------------------------------

bits = { 0, 0, 0 }

===============================================================================

/* check that bitfield padding is skipped */

struct bits {
  int :7;
  int a:3;
  int c:2;
  int d:4;
};

-------------------------------------------------------------------------------

bits = { 0, 0, 0 }

===============================================================================

/* taken from the docs, this revealed a bug introduced
 * with flexible array members
 */

struct date {
  unsigned year : 12;
  unsigned month:  4;
  unsigned day  :  5;
  unsigned hour :  5;
  unsigned min  :  6;
};

typedef struct {
  enum { DATE, QWORD } type;
  short number;
  union {
    struct date   date;
    unsigned long qword;
  } choice;
} data;

-------------------------------------------------------------------------------

data = { 0, 0, { { 0, 0, 0, 0, 0 } } }

