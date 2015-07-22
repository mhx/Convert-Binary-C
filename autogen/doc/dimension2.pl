use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 0; #-8<-

sub get_count { 42 };

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian', IntSize => 4)->parse(<<'#-8<-');
struct type
{
  unsigned count;
  char array[1];
};
#-8<-

$c->tag('type.array', Dimension => '*');

#-8<-

$c->tag('type.array', Dimension => 42);

#-8<-

$c->tag('type.array', Dimension => 'count');

#-8<-

$c->tag('type.array', Dimension => \&get_count);

#-8<-

$c->tag('type.array', Dimension => [\&get_count, $c->arg('SELF'), 42]);

