################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/11/24 14:27:57 +0000 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /t/107_typedef.t $
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

BEGIN { plan tests => 7 }

eval { $p = new Convert::Binary::C; };
ok($@,'',"failed to create Convert::Binary::C object");

eval {
$p->parse(<<'EOF');
/* just some C stuff */
typedef struct car truck, mobile[3], *vehicle;
typedef enum { MONDAY, JANUARY, Y2K } day, month[4][5], *year;
struct car {
  int wheel;
  int gear;
};
/* the only way to execute the default_declaring_list */
/* rule is some strange construct like this...        */
typedef const foo, *bar, baz[2][3];
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
# check what has been parsed...
#-----------------------------------------------------

@names   = $p->typedef_names;
$n_names = $p->typedef_names;

@defs    = $p->typedef;
$n_defs  = $p->typedef;

ok( $n_names, 9, "wrong number of typedefs has been parsed" );
ok( $n_names, $n_defs, "typedef_names/typedef mismatch" );
ok( scalar @names, $n_names, "typedef_names array/scalar mismatch" );
ok( scalar @defs,  $n_defs,  "typedef array/scalar mismatch" );

ok( scalar @warn, 0, "unexpected warnings" );

