################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/01/01 09:38:15 +0000 $
# $Revision: 6 $
# $Source: /tests/120_new.t $
#
################################################################################
#
# Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN {
  plan tests => 3;
}

# This test is basically only for the 901_memory.t test

$c = eval { new Convert::Binary::C };
ok( $@, '' );

$c = eval { new Convert::Binary::C 'foo' };
ok( $@, qr/^Number of configuration arguments to new must be even/ );

$c = eval { new Convert::Binary::C foo => 42 };
ok( $@, qr/^Invalid option 'foo'/ );

