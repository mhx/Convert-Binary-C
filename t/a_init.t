################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/06/03 16:41:10 +0100 $
# $Revision: 2 $
# $Snapshot: /Convert-Binary-C/0.02 $
# $Source: /t/a_init.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;

use constant SUCCEED => 1;
use constant FAIL    => 0;

$^W = 1;

BEGIN { plan tests => 8 }

#===================================================================
# try to require the module (1 test)
#===================================================================
eval { require Convert::Binary::C };
ok($@,'',"failed to require Convert::Binary::C");
croak() if $@;

#===================================================================
# check if we build the right object (2 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C;
};
ok($@,'',"failed to create a Convert::Binary::C object");
ok(ref $p, 'Convert::Binary::C',
   "object reference not blessed to Convert::Binary::C");

#===================================================================
# check initialization during construction (2 tests)
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

#===================================================================
# check unknown options in constructor (1 test)
#===================================================================
eval {
  $p = new Convert::Binary::C FOO => 123, HashSize => 'Normal', BAR => ['abc'];
};
ok($@, qr/Invalid option 'FOO'/);

#===================================================================
# check invalid construction (1 test)
#===================================================================
eval {
  $p = new Convert::Binary::C FOO;
};
ok($@, qr/Number of configuration arguments to new must be equal/);

#===================================================================
# check invalid construction (1 test)
#===================================================================
eval {
  $p = new Convert::Binary::C HashSize => 'FOO';
};
ok($@, qr/HashSize must be.*not 'FOO'/);

