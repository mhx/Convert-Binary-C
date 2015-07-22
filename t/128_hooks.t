################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/03/23 21:00:43 +0000 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.52 $
# $Source: /t/128_hooks.t $
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

BEGIN { plan tests => 123 }

eval { require Scalar::Util };
my $reason = $@ ? 'Cannot load Scalar::Util' : '';

my $c = new Convert::Binary::C ByteOrder => 'BigEndian',
                               EnumType  => 'String',
                               EnumSize  => 4,
                               IntSize   => 4;

$c->parse(<<'ENDC');

enum Enum {
  Zero, One, Two, Three, Four, Five, Six, Seven
};

typedef unsigned int u_32;

typedef u_32   TextId;
typedef TextId SetTextId;

struct String {
  u_32 len;
  char buf[];
};

struct Test {
  u_32      header;
  SetTextId id;
};

ENDC

my %TEXTID  = (          4 => 'perl',
                1179602721 => 'rules' );
my %RTEXTID = reverse %TEXTID;

my $d = pack("N", 4) . "FOO!";

no_hooks();

$c->add_hooks(Enum   => { pack   => \&enum_pack,
                          unpack => \&enum_unpack },
              TextId => { pack   => \&textid_pack,
                          unpack => \&textid_unpack });

$c->add_hooks(String => { pack   => \&string_pack,
                          unpack => \&string_unpack });

with_hooks();
$c = $c->clone;
with_hooks();

$c->delete_hooks(qw(Enum String));

{
  my $hook = $reason
           ? sub { $_[0] }  # identity
           : sub { Scalar::Util::dualvar($_[0], $TEXTID{$_[0]}) };
  
  $c->add_hooks(TextId => { unpack => $hook,
                            pack   => undef });
}

with_single_hook();
$c = $c->clone;
with_single_hook();

# This should completely remove the 'TextId' hooks
$c->add_hooks(TextId => { unpack => undef });

no_hooks();
$c = $c->clone;
no_hooks();

$c->delete_all_hooks
  ->add_hooks(Enum   => { pack => \&enum_pack   },
              TextId => { pack => \&textid_pack },
              String => { pack => \&string_pack })
  ->add_hooks(Enum   => { unpack => \&enum_unpack   },
              TextId => { unpack => \&textid_unpack },
              String => { unpack => \&string_unpack });

with_hooks();

$c = $c->delete_hooks('String')->delete_all_hooks->clone;

no_hooks();

sub no_hooks {
  my($u, $p);

  $u = $c->unpack('Enum', $d);
  ok($u, 'Four');
  $p = $c->pack('Enum', $u);
  ok($p, substr($d, 0, $c->sizeof('Enum')));

  $u = $c->unpack('u_32', $d);
  ok($u, 4);
  $p = $c->pack('u_32', $u);
  ok($p, substr($d, 0, $c->sizeof('u_32')));

  $u = $c->unpack('TextId', $d);
  ok($u, 4);
  $p = $c->pack('TextId', $u);
  ok($p, substr($d, 0, $c->sizeof('TextId')));

  $u = $c->unpack('SetTextId', $d);
  ok($u, 4);
  $p = $c->pack('SetTextId', $u);
  ok($p, substr($d, 0, $c->sizeof('SetTextId')));

  $u = $c->unpack('String', $d);
  ok($u->{len}, 4);
  ok("@{$u->{buf}}", "@{[unpack 'c*', 'FOO!']}");
  $p = $c->pack('String', $u);
  ok($p, $d);

  $u = $c->unpack('Test', $d);
  ok($u->{header}, 4);
  ok($u->{id}, unpack('N', 'FOO!'));
  $p = $c->pack('Test', $u);
  ok($p, substr($d, 0, $c->sizeof('Test')));
}

sub with_hooks {
  my($u, $p);

  $u = $c->unpack('Enum', $d);
  ok($u, 'FOUR');
  $p = $c->pack('Enum', $u);
  ok($p, substr($d, 0, $c->sizeof('Enum')));

  $u = $c->unpack('u_32', $d);
  ok($u, 4);
  $p = $c->pack('u_32', $u);
  ok($p, substr($d, 0, $c->sizeof('u_32')));

  $u = $c->unpack('TextId', $d);
  ok($u, 'perl');
  $p = $c->pack('TextId', $u);
  ok($p, substr($d, 0, $c->sizeof('TextId')));

  $u = $c->unpack('SetTextId', $d);
  ok($u, 'perl');
  $p = $c->pack('SetTextId', $u);
  ok($p, substr($d, 0, $c->sizeof('SetTextId')));

  $u = $c->unpack('String', $d);
  ok($u, 'FOO!');
  $p = $c->pack('String', $u);
  ok($p, $d);

  $u = $c->unpack('Test', $d);
  ok($u->{header}, 4);
  ok($u->{id}, 'rules');
  $p = $c->pack('Test', $u);
  ok($p, substr($d, 0, $c->sizeof('Test')));
}

sub with_single_hook {
  my($u, $p);

  $u = $c->unpack('Enum', $d);
  ok($u, 'Four');
  $p = $c->pack('Enum', $u);
  ok($p, substr($d, 0, $c->sizeof('Enum')));

  $u = $c->unpack('u_32', $d);
  ok($u, 4);
  $p = $c->pack('u_32', $u);
  ok($p, substr($d, 0, $c->sizeof('u_32')));

  $u = $c->unpack('TextId', $d);
  skip($reason, $u, 'perl');
  $p = $c->pack('TextId', $u);
  ok($p, substr($d, 0, $c->sizeof('TextId')));

  $u = $c->unpack('SetTextId', $d);
  skip($reason, $u, 'perl');
  $p = $c->pack('SetTextId', $u);
  ok($p, substr($d, 0, $c->sizeof('SetTextId')));

  $u = $c->unpack('String', $d);
  ok($u->{len}, 4);
  ok("@{$u->{buf}}", "@{[unpack 'c*', 'FOO!']}");
  $p = $c->pack('String', $u);
  ok($p, $d);

  $u = $c->unpack('Test', $d);
  ok($u->{header}, 4);
  skip($reason, $u->{id}, 'rules');
  $p = $c->pack('Test', $u);
  ok($p, substr($d, 0, $c->sizeof('Test')));
}

# the hooks
sub enum_pack   { ucfirst lc $_[0] }
sub enum_unpack { uc $_[0] }

sub textid_pack   { $RTEXTID{$_[0]} }
sub textid_unpack { $TEXTID{$_[0]} }

sub string_pack {
  { len => length $_[0], buf => [unpack 'c*', $_[0]] }
}
sub string_unpack {
  pack "c$_[0]->{len}", @{$_[0]->{buf}}
}

