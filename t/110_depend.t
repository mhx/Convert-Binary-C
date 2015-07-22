################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/03/22 19:38:02 +0000 $
# $Revision: 6 $
# $Snapshot: /Convert-Binary-C/0.55 $
# $Source: /t/110_depend.t $
#
################################################################################
#
# Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN { plan tests => 444 }

eval {
  $c1 = new Convert::Binary::C Include => ['t/include/files'];
  $c2 = new Convert::Binary::C Include => ['t/include/files'];
};
ok($@,'',"failed to create Convert::Binary::C objects");

eval {
  $c1->parse_file( 't/include/files/files.h' );
  $c2->parse( <<CODE );
#include <empty.h>
#include <ifdef.h>
#include <ifnull.h>
#include <something.h>
CODE
};
ok($@,'',"failed to parse C-code");

eval {
  $dep1 = $c1->dependencies;
  $dep2 = $c2->dependencies;
  @files1a = $c1->dependencies;
  @files2a = $c2->dependencies;
};
ok($@,'',"failed to retrieve dependencies");

@files1s = keys %$dep1;
@files2s = keys %$dep2;

@incs = qw(
  t/include/files/empty.h
  t/include/files/ifdef.h
  t/include/files/ifnull.h
  t/include/files/something.h
);

@ref1 = ( 't/include/files/files.h', @incs );
@ref2 = @incs;

s/\\/\//g for @files1a, @files2a, @files1s, @files2s;

print "# \@files1a => @files1a\n";

ok( join(',', sort @ref1), join(',', sort @files1a),
    "dependency names differ" );

print "# \@files1s => @files1s\n";

ok( join(',', sort @ref1), join(',', sort @files1s),
    "dependency names differ" );

print "# \@files2a => @files2a\n";

ok( join(',', sort @ref2), join(',', sort @files2a),
    "dependency names differ" );

print "# \@files2s => @files2s\n";

ok( join(',', sort @ref2), join(',', sort @files2s),
    "dependency names differ" );

eval {
  $c2 = new Convert::Binary::C Include => ['t/include/include', 't/include/perlinc'];
  $c2->parse_file( 't/include/include.c' );
};
ok($@,'',"failed to create object / parse file");

eval {
  $dep2 = $c2->dependencies;
};
ok($@,'',"failed to retrieve dependencies");

# check that the size, mtime and ctime entries are correct
for my $dep ( $dep1, $dep2 ) {
  for my $file ( keys %$dep ) {
    my($size, $mtime, $ctime) = (stat($file))[7,9,10];
    ok( $size,  $dep->{$file}{size},  "size mismatch for '$file'" );
    ok( $mtime, $dep->{$file}{mtime}, "mtime mismatch for '$file'" );
    ok( $ctime, $dep->{$file}{ctime}, "ctime mismatch for '$file'" );
  }
}
