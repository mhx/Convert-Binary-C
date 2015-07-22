use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new( ByteOrder => 'BigEndian',
                              LongSize  => 4,
                              ShortSize => 2 )
                       ->parse( <<'ENDC' );
struct test {
  char    ary[3];
  union {
    short word[2];
    long  quad;
  }       uni;
};
ENDC

#----8<------------------------------2----------------------------------

$binary = $c->pack( 'test', { ary => [1, 2], uni => { quad => 42 } } );

#----8<------------------------------3----------------------------------

print unpack('H*', $binary), "\n";

print "#-8<-\n";

#----8<------------------------------4----------------------------------

$unpacked = $c->unpack( 'test', $binary );
print Data::Dumper->Dump( [$unpacked], ['unpacked'] );

print "#-8<-\n";

#----8<------------------------------5----------------------------------

$array = $c->pack( 'test.ary', [1, 2, 3] );
print unpack('H*', $array), "\n";

$value = $c->pack( 'test.uni.word[1]', 2 );
print unpack('H*', $value), "\n";

print "#-8<-\n";

#----8<------------------------------6----------------------------------

$test = $c->unpack( 'test', $binary );
$test->{uni}{quad} = 4711;
$new = $c->pack( 'test', $test );

#----8<------------------------------7----------------------------------

$new = $c->pack( 'test', { uni => { quad => 4711 } }, $binary );

#----8<------------------------------8----------------------------------

$c->pack( 'test', { uni => { quad => 4711 } }, $binary );

#----8<------------------------------9----------------------------------

$too_short = pack "C*", (1 .. 4);
$too_long  = pack "C*", (1 .. 20);

$c->pack( 'test', { uni => { quad => 0x4711 } }, $too_short );
print "too_short: ", unpack('H*', $too_short), "\n";

$copy = $c->pack( 'test', { uni => { quad => 0x4711 } }, $too_long );
print "copy     : ", unpack('H*', $copy), "\n";

