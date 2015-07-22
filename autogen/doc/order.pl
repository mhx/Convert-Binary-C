use Convert::Binary::C;
use Data::Dumper;
use vars qw( $size );  #-8<-
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new->parse( <<'ENDC' );
struct test {
  char one;
  char two;
  struct {
    char never;
    char change;
    char this;
    char order;
  } three;
  char four;
};
ENDC

$data = "Convert";

$u1 = $c->unpack( 'test', $data );
$c->OrderMembers(1);
$u2 = $c->unpack( 'test', $data );

print Data::Dumper->Dump( [$u1, $u2], [qw(u1 u2)] );

