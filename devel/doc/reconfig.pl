use Convert::Binary::C;

$c = new Convert::Binary::C Alignment => 4, IntSize => 4;

#-8<-
$c->parse( <<'#-8<-' );

typedef struct {
  char abc;
  int  day;
} foo;

struct bar {
  foo  zap[2*sizeof(foo)];
};

#-8<-

$c->sizeof( 'bar' ) == 128 or die;
$c->Alignment( 1 );
$c->sizeof( 'bar' ) == 80 or die;   # should be 50
