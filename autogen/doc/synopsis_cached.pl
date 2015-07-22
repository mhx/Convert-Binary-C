use Convert::Binary::C::Cached;
use Data::Dumper;

#------------------------
# Create a cached object
#------------------------
$c = Convert::Binary::C::Cached->new(
       Cache   => '/tmp/cache.c',
       Include => [
         '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.6/include',
         '/usr/include',
       ],
     );

#----------------------------------------------------
# Parse 'time.h' and dump the definition of timespec
#----------------------------------------------------
$c->parse_file('time.h');

print Dumper($c->struct('timespec'));
