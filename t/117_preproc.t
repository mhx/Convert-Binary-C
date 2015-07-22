################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/11/20 06:43:33 +0000 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.49 $
# $Source: /t/117_preproc.t $
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
  plan tests => 2;
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
  $c->parse( <<'END' );
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

