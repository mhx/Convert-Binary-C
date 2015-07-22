################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/04/17 13:39:11 +0100 $
# $Revision: 5 $
# $Snapshot: /Convert-Binary-C/0.43 $
# $Source: /t/806_env.t $
#
################################################################################
#
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Test;

$^W = 1;

BEGIN {
  plan tests => 5;
}

$ENV{CBC_DISABLE_PARSER} = 1;

@WARN = ();
$SIG{__WARN__} = sub { push @WARN, $_[0] };

eval { require Convert::Binary::C };

ok( $@, '', "could not require Convert::Binary::C" );
ok( scalar @WARN, 0, "unexpected warning" );

eval { my $c = new Convert::Binary::C };

ok( $@, '', "could not create Convert::Binary::C object" );
ok( scalar @WARN, 1, "wrong number of warnings" );
ok( $WARN[0], qr/Convert::Binary::C parser is DISABLED/, "wrong warning" );

