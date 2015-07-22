use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; $^W = 0; #-8<-

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian', LongSize => 4)->parse( <<'#-8<-' );
struct message {
  long header;
  char data[];
};
#-8<-

$msg1 = $c->unpack('message', 'abcdefg');
$msg2 = $c->unpack('message', 'abcdefghijkl');
print Data::Dumper->Dump([$msg1, $msg2], [qw(msg1 msg2)]); #-8<-
print "#-8<-\n";

#-8<-

use Data::Hexdumper;

$msg = {
  header => 4711,
  data   => [0x10, 0x20, 0x30, 0x40, 0x77..0x88],
};

$data = $c->pack('message', $msg);

print hexdump(data => $data);
print "#-8<-\n";

#-8<-

$c->parse( <<'#-8<-' );
typedef unsigned long array[];
#-8<-

$array = $c->unpack('array', '?'x20);

print Data::Dumper->Dump([$array], [qw(array)]); #-8<-

