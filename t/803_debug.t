################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/11/21 21:00:25 +0000 $
# $Revision: 9 $
# $Snapshot: /Convert-Binary-C/0.05 $
# $Source: /t/803_debug.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C;

$^W = 1;

BEGIN {
  $debug = Convert::Binary::C::feature( 'debug' );
  plan tests => $debug ? 10 : 11
}

ok( defined $debug );
$dbfile = 't/debug.out';

-e $dbfile and unlink $dbfile;

$SIG{__WARN__} = sub { push @warnings, $_[0] };

eval qq{
  use Convert::Binary::C debug => 'all', debugfile => '$dbfile';
};

ok( $@, '' );

if( $debug ) {
  ok( scalar @warnings, 0, "unexpected warning(s)" );
}
else {
  ok( scalar @warnings, 1, "wrong number of warnings" );
  ok( $warnings[0], qr/Convert::Binary::C not compiled with debugging support/ );
}

ok( -e $dbfile xor not $debug );
ok( -z $dbfile xor not $debug );

eval { $p = new Convert::Binary::C };

ok( $@, '' );
ok( ref $p, 'Convert::Binary::C' );

undef $p;

@warnings = ();

eval q{
  use Convert::Binary::C debugfile => '';
};

ok( scalar @warnings, 1, "wrong number of warnings" );
ok( $warnings[0], $debug ? qr/Cannot open '', defaulting to stderr/
                         : qr/Convert::Binary::C not compiled with debugging support/ );

ok( -s $dbfile xor not $debug );

