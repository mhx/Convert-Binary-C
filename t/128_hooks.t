################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2004/07/01 07:35:34 +0100 $
# $Revision: 5 $
# $Snapshot: /Convert-Binary-C/0.57 $
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

BEGIN { plan tests => 174 }

eval { require Scalar::Util };
my $reason = $@ ? 'Cannot load Scalar::Util' : '';

my $c = new Convert::Binary::C ByteOrder   => 'BigEndian',
                               EnumType    => 'String',
                               EnumSize    => 4,
                               IntSize     => 4,
                               PointerSize => 4;

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

struct Date {
  u_32 year;
  u_32 month;
  u_32 day;
};

struct Test {
  u_32      header;
  SetTextId id;
};

struct PtrHookTest {
  struct Test *pTest;
  struct Date *pDate;
  enum   Enum *pEnum;
  TextId      *pText;
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
  ->add_hooks(Enum   => { pack   => \&enum_pack     },
              TextId => { pack   => \&textid_pack   },
              String => { pack   => \&string_pack   })
  ->add_hooks(Enum   => { unpack => \&enum_unpack   },
              TextId => { unpack => \&textid_unpack },
              String => { unpack => \&string_unpack });

with_hooks();

$c = $c->delete_hooks('String')->delete_all_hooks->clone;

no_hooks();

test_args();

test_ptr_hooks();

#######################################################################

sub test_ptr_hooks {
  my $pack = sub { $_[0] =~ /{(0x[^}]+)}/ ? hex $1 : '' };

  $c->add_hooks(Test   => { unpack_ptr => sub { sprintf "Test{0x%X}", $_[0] },
                            pack_ptr   => [$pack, $c->arg('DATA')] },
                Date   => { unpack_ptr => [sub { sprintf "$_[1]\{0x%X}", $_[0] }, $c->arg('DATA', 'TYPE')],
                            pack_ptr   => $pack },
                Enum   => { unpack_ptr => [sub { sprintf "$_[0]\{0x%X}", $_[1] }, $c->arg('TYPE', 'DATA')],
                            pack_ptr   => [$pack, $c->arg('DATA', 'SELF'), 'foo'] },
                TextId => { unpack_ptr => [sub { sprintf "Text\{0x%X}", $_[0] }, $c->arg('DATA')],
                            pack_ptr   => $pack });

  my $str = pack('N*', 0xdeadbeef, 0x2badc0de, 0x12345678, 0xdeadc0de);

  my $u = $c->unpack('PtrHookTest', $str);

  ok($u->{pTest}, "Test{0xDEADBEEF}");
  ok($u->{pDate}, "struct Date{0x2BADC0DE}");
  ok($u->{pEnum}, "enum Enum{0x12345678}");
  ok($u->{pText}, "Text{0xDEADC0DE}");

  my $p = $c->pack('PtrHookTest', $u);

  ok($p, $str);

  $c->delete_all_hooks;
}

sub test_args {
  my(@ap, @au, $x);

  my $sub_p = sub { push @ap, @_; shift };
  my $sub_u = sub { push @au, @_; shift };

  my @t = (
    { type => 'TextId', in_p => 4711, in_u => pack("N", 0x12345678),
      arg_u => [],  res_u => [],
      arg_p => [],  res_p => []  },

    { type => 'TextId', in_p => 4711, in_u => pack("N", 0x12345678),
      arg_u => [1], res_u => [1],
      arg_p => [2], res_p => [2] },

    { type => 'TextId', in_p => 4711, in_u => pack("N", 0x12345678),
      arg_u => [$c->arg('DATA')], res_u => [0x12345678],
      arg_p => [$c->arg('DATA', 'HOOK')], res_p => [4711, 'pack'] },

    { type => 'TextId', in_p => 4711, in_u => pack("N", 0x12345678),
      arg_u => [$c->arg('DATA', 'TYPE', 'SELF'), 123], res_u => [0x12345678, 'TextId', $c, 123],
      arg_p => [$c->arg('DATA', 'TYPE', 'SELF'), 456], res_p => [4711, 'TextId', $c, 456] },

    { type => 'TextId', in_p => 4711, in_u => pack("N", 0x12345678),
      arg_u => [$c->arg('DATA', 'TYPE'), 'foo', $c->arg('SELF', 'DATA')],
      res_u => [0x12345678, 'TextId', 'foo', $c, 0x12345678],
      arg_p => [$c->arg('DATA', 'TYPE'), 'bar', $c->arg('SELF')], res_p => [4711, 'TextId', 'bar', $c] },

    { type => 'Enum', in_p => 'Seven', in_u => pack("N", 8),
      arg_u => [$c->arg('DATA', 'TYPE', 'HOOK')], res_u => ['<ENUM:8>', 'enum Enum', 'unpack'],
      arg_p => [$c->arg('DATA', 'TYPE', 'DATA')], res_p => ['Seven', 'enum Enum', 'Seven'] },

    { type => 'Date', in_p => {}, in_u => pack("N3", 4, 5, 6),
      arg_u => [$c->arg('DATA', 'TYPE')], res_u => [qr/HASH/, 'struct Date'],
      arg_p => [$c->arg('DATA', 'TYPE')], res_p => [qr/HASH/, 'struct Date'] },
  );

  for my $t (@t) {
    @ap = ();
    @au = ();

    $c->add_hooks($t->{type} => {
                    pack   => [$sub_p, @{$t->{arg_p}}],
                    unpack => [$sub_u, @{$t->{arg_u}}],
                  });

    $x = $c->pack($t->{type}, $t->{in_p});
    $x = $c->unpack($t->{type}, $t->{in_u});

    ok(scalar @ap, scalar @{$t->{res_p}});
    for (0 .. $#ap) {
      ok($ap[$_], $t->{res_p}[$_]);
    }

    ok(scalar @au, scalar @{$t->{res_u}});
    for (0 .. $#au) {
      ok($au[$_], $t->{res_u}[$_]);
    }
  }

  $c->delete_all_hooks;
}

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

