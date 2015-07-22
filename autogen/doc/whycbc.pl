use Convert::Binary::C;

$c = Convert::Binary::C->new( ByteOrder => 'LittleEndian' )->parse_file( 'header.h' );

#-8<-

@ary = (1, 2, 3);
$baz = 40000;
$bar = -4711;
$binary = pack 'c3 S i', @ary, $baz, $bar;

#-8<-

$ref = $c->Alignment(1)->pack( 'foo', { ary => \@ary, baz => $baz, bar => $bar } );
$ref eq $binary or die;

#-8<-

$binary = pack 'c3 x S x2 i', @ary, $baz, $bar;

#-8<-

$ref = $c->Alignment(4)->pack( 'foo', { ary => \@ary, baz => $baz, bar => $bar } );
$ref eq $binary or die;

#-8<-

$binary = pack 'c3 x n x2 N', @ary, $baz, $bar;

#-8<-

$ref = $c->ByteOrder('BigEndian')->pack( 'foo', { ary => \@ary, baz => $baz, bar => $bar } );
$ref eq $binary or die;

