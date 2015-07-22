################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/12/26 11:28:06 +0000 $
# $Revision: 11 $
# $Source: /tests/117_preproc.t $
#
################################################################################
#
# Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test::More tests => 17;
use Convert::Binary::C @ARGV;

eval {
  $c = new Convert::Binary::C Define  => ['b=a'],
                              Include => ['tests/include/files', 'include/files'];
};
is($@, '', "create Convert::Binary::C::Cached object");

#--------------------
# check of ucpp bugs
#--------------------

eval {
  $c->parse(<<'END');
#define a int
b x;
END
};
is($@, '', "parse code");

# eval {
#   $c->parse( <<'END' );
# #include "ifnonl.h"
# typedef int foo;
# END
# };
# is($@, '', "failed to parse code");


#----------------------------
# check if #ident is ignored
#----------------------------

my $s = eval {
  $c->parse(<<'END');
#ident "bla bla"
typedef int xxx;
END
  $c->sizeof('xxx');
};
is($@, '', "parse code with #ident correctly");
is($s, $c->sizeof('int'));

#----------------
# various checks
#----------------

$c->clean;

eval {
  $c->parse(<<'END');
#include "unmatched.h"
END
};

like($@, qr/unterminated #if construction/);
like($@, qr/included from \[buffer\]:1/);

$c->clean->CharSize(1)->Warnings(1);

my @warn;
$s = eval {
  local $SIG{__WARN__} = sub { push @warn, @_ };
  $c->parse(<<'END');
??=include "trigraph.h"
END
  $c->sizeof('array');
};

is($@, '');
is($s, 42);
is(scalar @warn, 5);
like($warn[0], qr/^\[buffer\], line 1: \(warning\) trigraph \?\?= encountered/);
like($warn[1], qr/trigraph\.h, line 1: \(warning\) trigraph \?\?= encountered/);
like($warn[1], qr/included from \[buffer\]:1/);
like($warn[2], qr/trigraph\.h, line 3: \(warning\) trigraph \?\?\( encountered/);
like($warn[2], qr/included from \[buffer\]:1/);
like($warn[3], qr/trigraph\.h, line 3: \(warning\) trigraph \?\?\) encountered/);
like($warn[3], qr/included from \[buffer\]:1/);
like($warn[4], qr/^\[buffer\]: \(warning\) 4 trigraph\(s\) encountered/);

