use Convert::Binary::C::Cached;
use Data::Dumper;

#------------------------
# Create a cached object
#------------------------
$c = Convert::Binary::C::Cached->new(
       Cache   => '/tmp/cache.c',
       Include => [
         '/usr/lib/gcc/x86_64-pc-linux-gnu/10.2.0/include',
         '/usr/lib/gcc/x86_64-pc-linux-gnu/10.2.0/include-fixed',
         '/usr/include',
       ],
     );

#----------------------------------------------------
# Parse 'time.h' and dump the definition of timespec
#----------------------------------------------------
$c->parse_file('time.h');

print Dumper($c->struct('timespec'));
