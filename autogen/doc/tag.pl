use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; #-8<-

sub rout { @_ } #-8<-

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian')->parse( <<'#-8<-' );
struct test {
  int a;
  struct {
    int x;
  } b, c;
};
#-8<-

$c->tag('int', Format => 'Binary');

#-8<-

$c->tag('test', Hooks => undef);

#-8<-

$c->tag('test.a', Format => 'Binary');

$hooks = $c->tag('test.a', 'Hooks');
$format = $c->tag('test.a', 'Format');

not defined $hooks or die;  #-8<-
$format eq 'Binary' or die; #-8<-

print Data::Dumper->Dump([$hooks, $format], [qw(hooks format)]); #-8<-
print "#-8<-\n";

#-8<-

$tags = $c->tag('test.a');

print Data::Dumper->Dump([$tags], [qw(tags)]); #-8<-

