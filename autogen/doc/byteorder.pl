use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian',
                             OrderMembers => 1);
$c->parse(<<'ENDC');

typedef unsigned short u_16;

struct coords_3d {
  long x, y, z;
};

struct coords_msg {
  u_16 header;
  u_16 length;
  struct coords_3d coords;
};

ENDC

$co = $c->clone; #-8<-

#-8<-

$c->tag('coords_msg.coords', ByteOrder => 'LittleEndian');

#-8<-

$binary = pack "nnVVV",
               42,                       # header
               $c->sizeof('coords_3d'),  # length
               -1, 2, 42;                # coords

use Data::Hexdumper;

print hexdump(data => $binary);

print "#-8<-\n";

#-8<-

$msg = $c->unpack('coords_msg', $binary);
print Data::Dumper->Dump([$msg], [qw(msg)]); #-8<-

print "#-8<-\n";

#-8<-

$msg = $co->unpack('coords_msg', $binary);
print Data::Dumper->Dump([$msg], [qw(msg)]);

print "#-8<-\n";

#-8<-

$c->tag('coords_3d.y', ByteOrder => 'BigEndian');
$msg = $c->unpack('coords_msg', $binary);
print Data::Dumper->Dump([$msg], [qw(msg)]); #-8<-

print "#-8<-\n";

#-8<-

$le = Convert::Binary::C->new(ByteOrder => 'LittleEndian');

$le->parse(<<'ENDC');

typedef unsigned short u_16;
typedef unsigned long  u_32;

struct message {
  u_16 header;
  u_16 length;
  struct {
    u_32 a;
    u_32 b;
    u_32 c :  7;
    u_32 d :  5;
    u_32 e : 20;
  } data;
};

ENDC

$be = $le->clone->ByteOrder('BigEndian');

$le->tag('message.data', Format => 'Binary', Hooks => {
    unpack => sub { $be->unpack('message.data', @_) },
    pack   => sub { $be->pack('message.data', @_) },
  });

$binary = pack "C*", 1 .. $le->sizeof('message'); #-8<-

$msg = $le->unpack('message', $binary);

print Data::Dumper->Dump([$msg], [qw(msg)]); #-8<-

$binary eq $le->pack('message', $msg) or die; #-8<-

