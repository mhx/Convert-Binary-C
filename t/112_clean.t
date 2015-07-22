################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/04/17 13:39:08 +0100 $
# $Revision: 5 $
# $Snapshot: /Convert-Binary-C/0.48 $
# $Source: /t/112_clean.t $
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

BEGIN { plan tests => 6 }

eval {
  $c = new Convert::Binary::C;
};
ok($@,'',"failed to create Convert::Binary::C object");

eval {
  $c->clean;
};
ok($@,'',"failed to clean object");

eval {
  $c->parse( 'typedef struct foo { enum bar { ZERO } baz; } mytype;' );
};
ok($@,'',"failed to parse code");

eval {
  $copy = $c->clean;
};
ok($@,'',"failed to clean object");
ok($copy, $c, "clean does not return an object reference");

eval {
  my $foo = $c->struct;
};
ok( $@, qr/without parse data/, "parse data check failed" );

