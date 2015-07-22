################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/04/17 13:39:09 +0100 $
# $Revision: 3 $
# $Snapshot: /Convert-Binary-C/0.40 $
# $Source: /t/119_def.t $
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

BEGIN {
  plan tests => 58;
}

$SIG{__WARN__} = sub { push @warn, $_[0] };

eval {
  $c = new Convert::Binary::C;
};
ok($@,'',"failed to create Convert::Binary::C object");

@tests = (
  ['foo'                      => undef  ],
  ['int'                      => 'basic'],
  [' unsigned long long int ' => 'basic'],
);

run_tests( $c, @tests );

ok( scalar @warn, 0 );

@warn = ();

$c->parse( <<ENDC );

typedef int __int;
typedef int __array[10], *__ptr;

typedef struct test { int foo; } test, test2;
typedef struct undef undef, *undef2;
typedef union { int foo; } uni;
typedef enum noenu noenu;
typedef enum enu enu;

enum enu { ENU };

struct su { union uni *ptr; };
union uni2 { int foo; };
enum  enu2 { FOO };

ENDC

@tests = (
  ['foo'          => undef    ],
  ['int'          => 'basic'  ],
  [' long double' => 'basic'  ],
  ['__int'        => 'typedef'],
  ['__array'      => 'typedef'],
  ['__ptr'        => 'typedef'],
  ['__ptr.foo'    => 'typedef'],
  ['__ptr [10]'   => 'typedef'],
  ['__ptr !&'     => 'typedef'],
  ['test'         => 'typedef'],
  ['struct test'  => 'struct' ],
  ['test2'        => 'typedef'],
  ['undef'        => ''       ],
  ['undef2'       => 'typedef'],
  ['struct undef' => ''       ],
  ['uni'          => 'typedef'],
  ['noenu'        => ''       ],
  ['enu'          => 'typedef'],
  ['su'           => 'struct' ],
  ['union uni'    => ''       ],
  ['struct bar'   => undef    ],
  ['uni2'         => 'union'  ],
  ['enu2'         => 'enum'   ],
);

run_tests( $c, @tests );

ok( scalar @warn, 3 );
ok( $warn[0], qr/^\QIgnoring potential member expression ('.foo') after type name/ );
ok( $warn[1], qr/^\QIgnoring potential array expression ('[10]') after type name/ );
ok( $warn[2], qr/^\QIgnoring garbage ('!&') after type name/ );

sub run_tests
{
  my $c = shift;
  for( @_ ) {
    my $rv = eval { $c->def($_->[0]) };
    ok( $@, '' );
    unless( defined $rv and defined $_->[1] ) {
      ok( defined $rv, defined $_->[1] );
    }
    else {
      ok( $rv, $_->[1], "wrong result for '$_->[0]'" );
    }
  }
}
