################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/08/07 07:34:30 +0100 $
# $Revision: 1 $
# $Source: /tests/243_parser.t $
#
################################################################################
#
# Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test::More tests => 1;
use Convert::Binary::C @ARGV;
use strict;

$^W = 1;

my $c = new Convert::Binary::C;

eval { $c->parse_file('tests/parser/context.c') };

is($@, '', 'parse context.c');
