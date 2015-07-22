################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/06 21:47:44 +0000 $
# $Revision: 9 $
# $Source: /t/117_preproc.t $
#
################################################################################
#
# Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN {
  plan tests => 17;
}

eval {
  $c = new Convert::Binary::C Define  => ['b=a'],
                              Include => ['t/include/files', 'include/files'];
};
ok($@,'',"failed to create Convert::Binary::C::Cached object");

#--------------------
# check of ucpp bugs
#--------------------

eval {
  $c->parse(<<'END');
#define a int
b x;
END
};
ok($@,'',"failed to parse code");

# eval {
#   $c->parse( <<'END' );
# #include "ifnonl.h"
# typedef int foo;
# END
# };
# ok($@,'',"failed to parse code");


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
ok($@,'',"failed to parse code with #ident correctly");
ok($s, $c->sizeof('int'));

#----------------
# various checks
#----------------

$c->clean;

eval {
  $c->parse(<<'END');
#include "unmatched.h"
END
};

ok($@, qr/unterminated #if construction/);
ok($@, qr/included from \[buffer\]:1/);

$c->clean->CharSize(1)->Warnings(1);

my @warn;
$s = eval {
  local $SIG{__WARN__} = sub { push @warn, @_ };
  $c->parse(<<'END');
??=include "trigraph.h"
END
  $c->sizeof('array');
};

ok($@, '');
ok($s, 42);
ok(scalar @warn, 5);
ok($warn[0], qr/^\[buffer\], line 1: \(warning\) trigraph \?\?= encountered/);
ok($warn[1], qr/trigraph\.h, line 1: \(warning\) trigraph \?\?= encountered/);
ok($warn[1], qr/included from \[buffer\]:1/);
ok($warn[2], qr/trigraph\.h, line 3: \(warning\) trigraph \?\?\( encountered/);
ok($warn[2], qr/included from \[buffer\]:1/);
ok($warn[3], qr/trigraph\.h, line 3: \(warning\) trigraph \?\?\) encountered/);
ok($warn[3], qr/included from \[buffer\]:1/);
ok($warn[4], qr/^\[buffer\]: \(warning\) 4 trigraph\(s\) encountered/);

