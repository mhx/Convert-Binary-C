use Convert::Binary::C;
use Data::Dumper;
use vars qw( $size );  #-8<-
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new( ByteOrder => 'BigEndian'
                            , LongSize  => 4
                            , ShortSize => 2
                            )
                       ->parse( <<'ENDC' );
struct test {
  char    ary[3];
  union {
    short word[2];
    long *quad;
  }       uni;
};
ENDC

# Generate some binary dummy data
$binary = pack "C*", 1 .. $c->sizeof('test');

#----8<------------------------------2----------------------------------

$unpacked = $c->unpack('test', $binary);
print Dumper($unpacked);

print "#-8<-\n";

#----8<------------------------------3----------------------------------

$binary2 = substr $binary, $c->offsetof('test', 'uni.word');

$unpack1 = $unpacked->{uni}{word};
$unpack2 = $c->unpack('test.uni.word', $binary2);

print Data::Dumper->Dump([$unpack1, $unpack2], [qw(unpack1 unpack2)]);

#----8<------------------------------4----------------------------------

$size = $c->sizeof('test.uni.word[1]');
$size == 2 or die;   #-8<-

