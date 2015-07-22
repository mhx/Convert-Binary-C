use Convert::Binary::C;
use Data::Dumper;
use Data::Hexdumper;
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

print hexdump( data => $binary );

print "#-8<-\n";

#----8<------------------------------4----------------------------------

$unpacked = $c->unpack( 'test', $binary );
print Data::Dumper->Dump( [$unpacked], ['unpacked'] );

print "#-8<-\n";

#----8<------------------------------5----------------------------------

$array = $c->pack( 'test.ary', [1, 2, 3] );
print hexdump( data => $array );

$value = $c->pack( 'test.uni.word[1]', 2 );
print hexdump( data => $value );

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
print "too_short:\n", hexdump( data => $too_short );

$copy = $c->pack( 'test', { uni => { quad => 0x4711 } }, $too_long );
print "\ncopy:\n", hexdump( data => $copy );

