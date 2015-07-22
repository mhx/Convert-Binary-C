use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian')->parse( <<'#-8<-' );
typedef char str_type[40];
#-8<-

$c->tag('str_type', Format => 'String');

#-8<-

$binary = "Hello World!\n\0 this is just some dummy data";
$hello = $c->unpack('str_type', $binary);
print $hello;

$hello eq "Hello World!\n" or die; #-8<-
print "#-8<-\n";

#-8<-

use Data::Hexdumper;

$binary = $c->pack('str_type', "Just another C::B::C hacker");
print hexdump(data => $binary);

print "#-8<-\n";

#-8<-

$c->parse(<<ENDC);
struct packet {
  unsigned short header;
  unsigned short flags;
  unsigned char  payload[28];
};
ENDC

$c->tag('packet.payload', Format => 'Binary');

#-8<-

open FILE, 'yes no |' or die "yes: $!"; #-8<-

read FILE, $payload, $c->sizeof('packet.payload');

$packet = {
            header  => 4711,
            flags   => 0xf00f,
            payload => $payload,
          };

$binary = $c->pack('packet', $packet);

print hexdump(data => $binary);

close FILE; #-8<-
