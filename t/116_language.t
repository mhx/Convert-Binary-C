################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/12/11 14:28:24 +0000 $
# $Revision: 2 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /t/116_language.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN {
  plan tests => 12;
}

$C99 = Convert::Binary::C::feature( 'c99' );
$skip_c99 = $C99 ? '' : 'skip: not built with C99 feature';

eval {
  $c = new Convert::Binary::C;
};
ok($@,'',"failed to create Convert::Binary::C::Cached object");

#------------------------
# check the void keyword
#------------------------

eval {
  $c->clean->DisabledKeywords( [] );
  $c->parse( "typedef int void;" );
};
ok($@, qr/parse error/);

eval {
  $c->clean->DisabledKeywords( ['void'] );
  $c->parse( "typedef int void;" );
  @td = $c->typedef_names;
};
ok($@,'');
ok( scalar @td, 1 );
ok( $td[0], 'void' );

#------------------------
# check the C99 keywords
#------------------------

eval {
  $c->clean->DisabledKeywords( [] );
  $c->parse( "struct inline { int restrict; };" );
};
ok($@, $C99 ? qr/parse error/ : '');

eval {
  $c->clean->DisabledKeywords( [qw( inline restrict )] );
  $c->parse( "struct inline { int restrict; };" );
  @st = $c->struct_names;
};
ok($@, $C99 ? '' : qr/Cannot disable unknown keyword/);
skip( $skip_c99, scalar @st, 1 );
skip( $skip_c99, $st[0], 'inline' );

#--------------------
# check C++ comments
#--------------------

eval {
  $c->clean->DisabledKeywords( [] );
  $c->parse( "struct foo { int a[8//*comment*/4]; };\n" )
};
ok($@, $C99 ? qr/parse error/ : '');

eval {
  $c->clean->HasCPPComments( 0 );
  $c->parse( "struct foo { char a[8//*comment*/4]; };\n" );
  $s = $c->sizeof('foo');
};
ok($@, $C99 ? '' : qr/Invalid option 'HasCPPComments'/);
skip( $skip_c99, $s, 2 );

