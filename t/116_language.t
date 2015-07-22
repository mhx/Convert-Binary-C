################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/04/17 13:39:09 +0100 $
# $Revision: 8 $
# $Snapshot: /Convert-Binary-C/0.47 $
# $Source: /t/116_language.t $
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

BEGIN { plan tests => 19 }

eval {
  $c = new Convert::Binary::C;
};
ok($@,'',"failed to create Convert::Binary::C object");

#------------------------
# check the void keyword
#------------------------

eval {
  $c->clean->DisabledKeywords( [] );
  $c->parse( "typedef int void;" );
};
ok($@, qr/(parse|syntax) error/);

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
ok($@, qr/(parse|syntax) error/);

eval {
  $c->clean->DisabledKeywords( [qw( inline restrict )] );
  $c->parse( "struct inline { int restrict; };" );
  @st = $c->struct_names;
};
ok($@, '');
ok( scalar @st, 1 );
ok( $st[0], 'inline' );

#--------------------
# check C++ comments
#--------------------

eval {
  $c->clean->DisabledKeywords( [] );
  $c->parse( "struct foo { int a[8//*comment*/4]; };\n" )
};
ok($@, qr/(parse|syntax) error/);

eval {
  $c->clean->HasCPPComments( 0 );
  $c->parse( "struct foo { char a[8//*comment*/4]; };\n" );
  $s = $c->sizeof('foo');
};
ok($@, '');
ok( $s, 2 );

#-----------------------------
# check (some) GNU extensions
#-----------------------------

eval {
  $c->clean->parse( "typedef __signed __extension__ long long _signed;" );
};
ok($@, qr/(parse|syntax) error/);

eval {
  $c->clean->Define( qw( __signed=signed __extension__= ) );
  $c->parse( "typedef __signed __extension__ long long _signed;" );
};
ok($@, '');

eval {
  $c->clean->parse( <<END );
#undef __signed
typedef __signed __extension__ long long _signed;
END
};
ok($@, qr/(parse|syntax) error/);

eval {
  $c->clean->KeywordMap( { __signed => 'signed', __extension__ => undef } );
  $c->parse( <<END );
#undef __signed
typedef __signed __extension__ long long _signed;
END
};
ok($@, '');

eval {
  $c->clean->Define( [] );
  $c->parse( <<END );
typedef __signed __extension__ long long _signed;
END
};
ok($@, '');

eval {
  $c->clean->parse( <<END );
typedef __signed __extension__ long long signed;
END
};
ok($@, qr/(parse|syntax) error/);

eval {
  $c->clean->DisabledKeywords( ['signed'] );
  $c->parse( <<END );
typedef __signed __extension__ long long signed;
END
};
ok($@, '');

