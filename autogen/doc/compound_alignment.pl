use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 0;

$c = new Convert::Binary::C Alignment => 4, CompoundAlignment => 4;

#-8<-

$c->parse( <<'#-8<-' );
struct onebyte {
  char byte;
};
#-8<-

$c->parse( <<'#-8<-' );
typedef unsigned char U8;

struct msg_head {
  U8 cmd;
  struct {
    U8 hi;
    U8 low;
  } crc16;
  U8 len;
};
#-8<-

$_ = <<'#-8<-';
0     1     2     3     4     5     6
+-----+-----+-----+-----+-----+-----+
| cmd |  *  | hi  | low | len |  *  |
+-----+-----+-----+-----+-----+-----+
#-8<-

$c->sizeof('onebyte') == 4 or die;

$c->CompoundAlignment(2);

$c->sizeof('msg_head') == 6 or die;
$c->offsetof('msg_head', 'crc16.hi') == 2 or die;
$c->offsetof('msg_head', 'len') == 4 or die;
