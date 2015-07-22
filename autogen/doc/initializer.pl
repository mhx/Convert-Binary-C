use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; $^W = 0; #-8<-

$c = Convert::Binary::C->new->parse( <<'#-8<-' );
struct date {
  unsigned year : 12;
  unsigned month:  4;
  unsigned day  :  5;
  unsigned hour :  5;
  unsigned min  :  6;
};

typedef struct {
  enum { DATE, QWORD } type;
  short number;
  union {
    struct date   date;
    unsigned long qword;
  } choice;
} data;
#-8<-

$init = $c->initializer( 'data' );
print "data x = $init;\n";

print "#-8<-\n";

#-8<-

$data = {
  type   => 'QWORD',
  choice => {
    date  => { month => 12, day => 24 },
    qword => 4711,
  },
  stuff => 'yes?',
};

$init = $c->initializer( 'data', $data );
print "data x = $init;\n";

#-8<-

$binary = 'x'x $c->sizeof( 'data' ); #-8<-
$data = $c->unpack( 'data', $binary );
$init = $c->initializer( 'data', $data );

