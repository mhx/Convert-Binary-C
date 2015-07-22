use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian')->parse( <<'#-8<-' );
typedef unsigned long u_32;
typedef u_32 ProtoId;
typedef ProtoId MyProtoId;

struct MsgHeader {
  MyProtoId id;
  u_32      len;
};
#-8<-

$c->parse( <<'#-8<-' );
struct String {
  u_32 len;
  char buf[];
};
#-8<-

$data = pack "NN", 42, 13; #-8<-
$msg_header = $c->unpack('MsgHeader', $data);
print Data::Dumper->Dump([$msg_header], [qw(msg_header)]); #-8<-
print "#-8<-\n";

#-8<-

%proto = (
  CATS      =>    1,
  DOGS      =>   42,
  HEDGEHOGS => 4711,
);

%rproto = reverse %proto;

sub ProtoId_unpack {
  $rproto{$_[0]} || 'unknown protocol'
}

sub ProtoId_pack {
  $proto{$_[0]} or die 'unknown protocol'
}

#-8<-

$c->tag('ProtoId', Hooks => { pack   => \&ProtoId_pack,
                              unpack => \&ProtoId_unpack });

#-8<-

$msg_header = $c->unpack('MsgHeader', $data);
print Data::Dumper->Dump([$msg_header], [qw(msg_header)]); #-8<-
print "#-8<-\n";

#-8<-

use Scalar::Util qw(dualvar);

sub ProtoId_unpack2 {
  dualvar $_[0], $rproto{$_[0]} || 'unknown protocol'
}

$c->tag('ProtoId', Hooks => { pack => undef }); #-8<-
$c->tag('ProtoId', Hooks => { unpack => \&ProtoId_unpack2 });

$msg_header = $c->unpack('MsgHeader', $data);
print Data::Dumper->Dump([$msg_header], [qw(msg_header)]); #-8<-
print "#-8<-\n";

#-8<-

$c->tag('ProtoId', Hooks => { pack => undef });

#-8<-

$c->tag('ProtoId', Hooks => undef);

#-8<-

sub string_unpack {
  my $s = shift;
  pack "c$s->{len}", @{$s->{buf}};
}

sub string_pack {
  my $s = shift;
  return {
    len => length $s,
    buf => [ unpack 'c*', $s ],
  }
}

$data = pack("N", 12) . 'Hello World!'; #-8<-
$string = $c->unpack('String', $data); #-8<-
print Data::Dumper->Dump([$string], [qw(string)]); #-8<-
print "#-8<-\n";

#-8<-

$c->tag('String', Hooks => { pack   => \&string_pack,
                             unpack => \&string_unpack });

$string = $c->unpack('String', $data); #-8<-
print Data::Dumper->Dump([$string], [qw(string)]); #-8<-
print "#-8<-\n";

#-8<-

use Data::Hexdumper;

$data = $c->pack('String', 'Just another Perl hacker,');

print hexdump(data => $data);
print "#-8<-\n";

#-8<-

$hooks = $c->tag('String', 'Hooks');

$dump = Data::Dumper->new([$hooks], [qw(hooks)]); #-8<-
$dump->Seen({ '*string_pack' => \&string_pack, '*string_unpack' => \&string_unpack }); #-8<-
print $dump->Dump; #-8<-
print "#-8<-\n";

#-8<-

$c->tag('String.buf', Format => 'Binary');

#-8<-

sub string_unpack2 {
  my $s = shift;
  substr $s->{buf}, 0, $s->{len};
}

sub string_pack2 {
  my $s = shift;
  return {
    len => length $s,
    buf => $s,
  }
}

$c->tag('String', Hooks => { pack   => \&string_pack2,
                             unpack => \&string_unpack2 });

$data2 = pack("N", 12) . 'Hello World!'; #-8<-
$string = $c->unpack('String', $data2); #-8<-
$string eq 'Hello World!' or die; #-8<-
$data2 = $c->pack('String', 'Just another Perl hacker,'); #-8<-
$data eq $data2 or die; #-8<-
