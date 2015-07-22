use Convert::Binary::C::Cached;
use Data::Dumper;

#------------------------
# Create a cached object
#------------------------
$c = new Convert::Binary::C::Cached
           Cache   => '/tmp/cache.c',
           Include => ['include']
         ;

#-------------------------------------------------
# Parse 'stdio.h' and dump the definition of FILE
#-------------------------------------------------
$c->parse_file( 'stdio.h' );

print Dumper( $c->typedef( 'FILE' ) );
