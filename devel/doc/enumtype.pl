use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1;

$c = Convert::Binary::C->new->parse_file( 'enumtype.c' );

my $binary = $c->pack( 'Date', { year => 2002, month => 0, day => 7, weekday => 1 } );

$c->EnumType( 'Integer' );
print Data::Dumper->Dump( [$c->unpack('Date', $binary)], ['date'] );
print "#-8<-\n";

$c->EnumType( 'String' );
print Data::Dumper->Dump( [$c->unpack('Date', $binary)], ['date'] );
print "#-8<-\n";

#-8<-

$date = $c->EnumType('Both')->unpack('Date', $binary);

printf "Weekday = %s (%d)\n\n", $date->{weekday},
                                $date->{weekday};

if( $date->{month} == 0 ) {
  print "It's $date->{month}, happy new year!\n\n";
}

print Dumper( $date );

