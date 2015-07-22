################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/01/01 11:30:03 +0000 $
# $Revision: 9 $
# $Snapshot: /Convert-Binary-C/0.10 $
# $Source: /t/001_init.t $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

use Test;

use constant SUCCEED => 1;
use constant FAIL    => 0;

$^W = 1;

BEGIN { plan tests => 17 }

#===================================================================
# try to require the modules (2 tests)
#===================================================================
eval { require Convert::Binary::C };
ok($@,'',"failed to require Convert::Binary::C");
croak() if $@;

eval { require Convert::Binary::C::Cached };
ok($@,'',"failed to require Convert::Binary::C::Cached");
croak() if $@;

#===================================================================
# check if we build the right object (4 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C;
};
ok($@,'',"failed to create a Convert::Binary::C object");
ok(ref $p, 'Convert::Binary::C',
   "object reference not blessed to Convert::Binary::C");

eval {
  $p = new Convert::Binary::C::Cached;
};
ok($@,'',"failed to create a Convert::Binary::C::Cached object");
ok(ref $p, 'Convert::Binary::C::Cached',
   "object reference not blessed to Convert::Binary::C::Cached");

#===================================================================
# check initialization during construction (4 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C PointerSize => 4,
                              EnumSize    => 4,
                              IntSize     => 4,
                              Alignment   => 2,
                              ByteOrder   => 'BigEndian',
                              EnumType    => 'Both';
};
ok($@,'',"failed to create a Convert::Binary::C object");
ok(ref $p, 'Convert::Binary::C',
   "object reference not blessed to Convert::Binary::C");

@warn = ();
eval {
  local $SIG{__WARN__} = sub { push @warn, $_[0] };
  $p = new Convert::Binary::C::Cached Cache       => 't/cache.cbc',
                                      PointerSize => 4,
                                      EnumSize    => 4,
                                      IntSize     => 4,
                                      Alignment   => 2,
                                      ByteOrder   => 'BigEndian',
                                      EnumType    => 'Both';
};
ok($@,'',"failed to create a Convert::Binary::C::Cached object");
ok(ref $p, 'Convert::Binary::C::Cached',
   "object reference not blessed to Convert::Binary::C::Cached");

if( @warn ) {
  my $ok = 1;
  printf "# %d warning(s) issued:\n", scalar @warn;
  for( @warn ) {
    /Cannot load (?:Data::Dumper|IO::File), disabling cache at $0/
      or $ok = 0;
    s/^/#   /gms;
    s/[\r\n]+$//gms;
    print "$_\n";
  }
  ok( $ok );
}
else { ok(1) }

#===================================================================
# check unknown options in constructor (2 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C FOO => 123, ByteOrder => 'BigEndian', BAR => ['abc'];
};
ok($@, qr/Invalid option 'FOO' at \Q$0/);

eval {
  $p = new Convert::Binary::C::Cached FOO => 123, ByteOrder => 'BigEndian', BAR => ['abc'];
};
ok($@, qr/Invalid option 'FOO' at \Q$0/);

#===================================================================
# check invalid construction (2 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C FOO;
};
ok($@, qr/Number of configuration arguments to new must be equal at \Q$0/);

eval {
  $p = new Convert::Binary::C::Cached FOO;
};
ok($@, qr/Number of configuration arguments to new must be equal at \Q$0/);

#===================================================================
# check invalid construction (2 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C ByteOrder => 'FOO';
};
ok($@, qr/ByteOrder must be.*not 'FOO' at \Q$0/);

eval {
  $p = new Convert::Binary::C::Cached ByteOrder => 'FOO';
};
ok($@, qr/ByteOrder must be.*not 'FOO' at \Q$0/);

