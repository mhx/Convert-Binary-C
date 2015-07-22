use Convert::Binary::C;
$c = new Convert::Binary::C Alignment => 4;

#-8<-

$c->configure( Include => ['/usr/include',
                           '/home/mhx/include'],
               Define  => [qw( NDEBUG FOO=42 )] );

#-8<-

$c->configure( Assert => ['predicate(answer)'] );

#-8<-

$c->ShortSize(2)->LongSize(4);
$c->parse_file( "pragma_pack.c" );

