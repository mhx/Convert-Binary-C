use Convert::Binary::C::Cached;
use Data::Dumper;

#------------------------
# Create a cached object
#------------------------
$c = Convert::Binary::C::Cached->new(
       Cache   => '/tmp/cache.c',
       Include => ['include']
     );

#-------------------------------------------------
# Parse 'stdio.h' and dump the definition of FILE
#-------------------------------------------------
$c->parse_file('stdio.h');

print Dumper($c->typedef('FILE'));
