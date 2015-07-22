################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/02/26 21:57:24 +0000 $
# $Revision: 2 $
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

eval "use Test::Pod::Coverage";
plan skip_all => "testing pod coverage requires Test::Pod::Coverage" if $@;

plan tests => 2;

my $trust_parents = { coverage_class => 'Pod::Coverage::CountParents' };

pod_coverage_ok("Convert::Binary::C");
pod_coverage_ok("Convert::Binary::C::Cached", $trust_parents);

# Convert::Binary::C::Cached simply inherits Convert::Binary::C documentation
