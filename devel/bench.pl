use Convert::Binary::C;
use Data::Dumper;
use Benchmark;
use strict;

my $c = new Convert::Binary::C ByteOrder    => 'BigEndian',
                               IntSize      => 4,
                               ShortSize    => 2,
                               LongSize     => 4,
                               LongLongSize => 4,
                               PointerSize  => 4,
                               EnumSize     => 0,
                               Alignment    => 8,
                               Include      => ['t/include/perlinc',
                                                't/include/include'];

$c->parse_file( 't/include/include.c' )->parse_file( 'devel/bench.h' );

my $d = 'x' x $c->sizeof( 'aaa' );
my $p = $c->unpack( 'aaa', $d );
my @o = (0 .. $c->sizeof('aaa')-1);
my @m = map { $c->member( 'aaa', $_ ) } @o;
my @a = map { 'aaa'.$_ } @m;

my $res = timethese( -10, {

  parse        => sub {
                    $c->clean->parse_file( 't/include/include.c' )->parse_file( 'devel/bench.h' );
                  },

  sourcify     => sub {
                    my $x = $c->sourcify;
                  },

  clone        => sub {
                    my $x = $c->clone;
                  },

  pack         => sub {
                    my $x = $c->pack( 'aaa', $p );
                  },

  unpack       => sub {
                    my $x = $c->unpack( 'aaa', $d );
                  },

  member       => sub {
                    for my $o ( @o ) { my $x = $c->member( 'aaa', $o ) }
                  },

  member_l     => sub {
                    for my $o ( @o ) { my @x = $c->member( 'aaa', $o ) }
                  },

  offsetof     => sub {
                    for my $m ( @m ) { my $x = $c->offsetof( 'aaa', $m ) }
                  },

  typeof       => sub {
                    for my $a ( @a ) { my $x = $c->typeof( $a ) }
                  },

  sizeof       => sub {
                    for my $a ( @a ) { my $x = $c->sizeof( $a ) }
                  },

} );

my %corr = (
  member   => scalar @o,
  member_l => scalar @o,
  offsetof => scalar @m,
  typeof   => scalar @a,
  sizeof   => scalar @a,
);

for my $k ( keys %corr ) {
  exists $res->{$k} and
    $res->{$k}[5] *= $corr{$k};
}

print '-'x72, "\n";
print "Corrected benchmark results:\n";

for my $k ( sort {  
              $res->{$a}[5]/($res->{$a}[1]+$res->{$a}[2])
              <=>
              $res->{$b}[5]/($res->{$b}[1]+$res->{$b}[2])
            } keys %$res ) {
  my $r = $res->{$k};
  my $cpu = $r->[1]+$r->[2];
  my $rate = $r->[5] / $cpu;
  if   ( $rate >= 1000 ) { $rate = sprintf "%.0f", $rate }
  elsif( $rate >=  100 ) { $rate = sprintf "%.1f", $rate }
  else                   { $rate = sprintf "%.2f", $rate }
  printf "%10s:%3d wallclock secs (%5.2f usr + %5.2f sys = %5.2f CPU) @ %6s/s (n=%d)\n",
          $k,  $r->[0],            $r->[1],    $r->[2],    $cpu,        $rate,   $r->[5];
}
