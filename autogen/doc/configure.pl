use Convert::Binary::C;
use Data::Dumper;
use vars qw( $order ); #-8<-
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new(Define  => ['DEBUGGING', 'FOO=123'],
                             Include => ['/usr/include']);

print Dumper($c->configure);

print "#-8<-\n";

#-8<- 2

$c->configure(ByteOrder => 'BigEndian', IntSize => 2);

#-8<- 3

$order = $c->configure('ByteOrder');

#-8<- 4

$c->ByteOrder('LittleEndian') if $c->IntSize < 4;

#-8<- 5

$c->configure(Define => ['foo', 'bar=123']);
$c->Define(['foo', 'bar=123']);

#-8<- 6

$c = Convert::Binary::C->new(Include => ['/include']);
$c->Include('/usr/include', '/usr/local/include');
print Dumper($c->Include);

$c->Include(['/usr/local/include']);
print Dumper($c->Include);

#-8<- 7

$c = Convert::Binary::C->new(IntSize => 4)
       ->Define(qw( __DEBUG__ DB_LEVEL=3 ))
       ->ByteOrder('BigEndian');

$c->configure(EnumType => 'Both', Alignment => 4)
  ->Include('/usr/include', '/usr/local/include');

#-8<- 8

$c->configure(Define => [qw( FOO BAR=12345 )]);

#-8<- 9

$c->configure(Assert => ['foo(bar)']);

#-8<- 10

$c->configure(Bitfields => { Engine => 'Generic' });

