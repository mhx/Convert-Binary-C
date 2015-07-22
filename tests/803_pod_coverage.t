################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/03/04 19:54:30 +0000 $
# $Revision: 3 $
# $Source: /tests/803_pod_coverage.t $
#
################################################################################
#
# Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test::More;

eval 'use Pod::Coverage 0.10';
plan skip_all => "testing pod coverage requires Pod::Coverage 0.10" if $@;

eval 'use Test::Pod::Coverage 1.08';
plan skip_all => "testing pod coverage requires Test::Pod::Coverage 1.08" if $@;

plan tests => 2;

my $trust_parents = { coverage_class => 'Pod::Coverage::CountParents' };

pod_coverage_ok("Convert::Binary::C");
pod_coverage_ok("Convert::Binary::C::Cached", $trust_parents);

# Convert::Binary::C::Cached simply inherits Convert::Binary::C documentation
