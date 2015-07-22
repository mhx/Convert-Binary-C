use Convert::Binary::C;
use Getopt::Long;
use Data::Dumper;
use Benchmark;
use strict;

my %opt = (
  order => 0
);

GetOptions(\%opt, qw( order iterations=i time=i ));

exists $opt{iterations} and exists $opt{time}
    and die "Cannot configure both iterations and time\n";

$|++;

print <<ENDHDR;
========================================================================
          Benchmarking Convert::Binary::C release $Convert::Binary::C::VERSION
========================================================================
ENDHDR

my $iter = -10;

$opt{iterations} and $iter =  $opt{iterations};
$opt{time}       and $iter = -$opt{time};

my %config = (
  ByteOrder    => 'BigEndian',
  IntSize      => 4,
  ShortSize    => 2,
  LongSize     => 4,
  LongLongSize => 4,
  PointerSize  => 4,
  EnumSize     => 0,
  Alignment    => 8,
  OrderMembers => $opt{order},
  Include      => ['t/include/perlinc', 't/include/include'],
);

my $c = new Convert::Binary::C;

for my $k (keys %config) {
  eval { $c->configure($k => $config{$k}) };
  if ($@) {
    $@ =~ s/^/| /mg;
    warn "Option '$k' doesn't seem to be supported in release $Convert::Binary::C::VERSION:\n$@";
  }
}

$c->parse_file('t/include/include.c')->parse_file('devel/bench.h');
my $type = 'forfaulture';

my $d = 'x' x $c->sizeof( $type );
my $p = $c->unpack($type, $d);
my @o = (0 .. $c->sizeof($type)-1);
my @m = map { $c->member($type, $_) } @o;
my @a = map { $type.$_ } @m;

my %tests = (

  parse        => sub {
                    $c->clean->parse_file('t/include/include.c')->parse_file('devel/bench.h');
                  },

  parse_c      => sub {
                    $c->clean->parse_file('t/include/include.c');
                  },

  parse_pp     => sub {
                    $c->clean->parse_file('devel/bench.h');
                  },

  sourcify     => sub {
                    my $x = $c->sourcify;
                  },

  clone        => sub {
                    my $x = $c->clone;
                  },

  pack         => sub {
                    my $x = $c->pack($type, $p);
                  },

  init_zero    => sub {
                    my $x = $c->initializer("$type.fluey");
                  },

  init_full    => sub {
                    my $x = $c->initializer("$type.fluey", $p->{fiw});
                  },

  unpack       => sub {
                    my $x = $c->unpack($type, $d);
                  },

  member       => sub {
                    for my $o (@o) { my $x = $c->member($type, $o) }
                  },

  member_l     => sub {
                    for my $o (@o) { my @x = $c->member($type, $o) }
                  },

  member_a     => sub {
                    my @x = $c->member($type);
                  },

  offsetof     => sub {
                    for my $m (@m) { my $x = $c->offsetof($type, $m) }
                  },

  typeof       => sub {
                    for my $a (@a) { my $x = $c->typeof($a) }
                  },

  sizeof       => sub {
                    for my $a (@a) { my $x = $c->sizeof($a) }
                  },

);

for my $test (sort keys %tests) {
  eval { $tests{$test}->() };
  if ($@) {
    $@ =~ s/^/| /mg;
    warn "Cannot run '$test' test on release $Convert::Binary::C::VERSION:\n$@";
    delete $tests{$test};
  }
}

if (@ARGV) {
  my %only;
  @only{@ARGV} = (1)x@ARGV;
  $only{$_} or delete $tests{$_} for keys %tests;
}

my $res = timethese($iter, \%tests);

my %corr = (
  member   => scalar @o,
  member_l => scalar @o,
  offsetof => scalar @m,
  typeof   => scalar @a,
  sizeof   => scalar @a,
);

for my $k (keys %corr) {
  exists $res->{$k} and
    $res->{$k}[5] *= $corr{$k};
}

print '-'x72, "\n";
print "Corrected benchmark results:\n";

for my $k (sort {  
             $res->{$a}[5]/($res->{$a}[1]+$res->{$a}[2])
             <=>
             $res->{$b}[5]/($res->{$b}[1]+$res->{$b}[2])
           } keys %$res) {
  my $r = $res->{$k};
  my $cpu = $r->[1] + $r->[2];
  my $rate = $r->[5] / $cpu;
  if   ($rate >= 1000) { $rate = sprintf "%.0f", $rate }
  elsif($rate >=  100) { $rate = sprintf "%.1f", $rate }
  else                 { $rate = sprintf "%.2f", $rate }
  printf "%10s:%3d wallclock secs (%5.2f usr + %5.2f sys = %5.2f CPU) @ %6s/s (n=%d)\n",
          $k,  $r->[0],            $r->[1],    $r->[2],    $cpu,        $rate,   $r->[5];
}
