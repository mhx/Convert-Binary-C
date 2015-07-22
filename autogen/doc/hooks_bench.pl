use Convert::Binary::C;
use Benchmark;

sub identity { $_[0] }

$c = Convert::Binary::C->new(LongSize => 4)->parse(<<'END');

typedef unsigned long u_32;
typedef u_32 hook;

struct test1 {
  hook a[10];
  u_32 b[90];
};

struct test2 {
  hook a[90];
  u_32 b[10];
};

END

$d = $c->clone;
$d->add_hooks(hook => { pack   => \&identity,
                        unpack => \&identity });

$string = 'x' x 400;
$test1 = { a => [1 .. 10], b => [11 .. 100] };
$test2 = { a => [1 .. 90], b => [91 .. 100] };

timethese(-1, {
  NoHP => sub { my $x = $c->pack('test1', $test1)    },
  NoHU => sub { my $x = $c->unpack('test1', $string) },
  WH1P => sub { my $x = $d->pack('test1', $test1)    },
  WH1U => sub { my $x = $d->unpack('test1', $string) },
  WH2P => sub { my $x = $d->pack('test2', $test2)    },
  WH2U => sub { my $x = $d->unpack('test2', $string) },
});
