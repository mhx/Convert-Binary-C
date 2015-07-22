use Convert::Binary::C;
use Data::Dumper;
my $p;

$SIG{__WARN__} = sub {};

sub run($$) {
  my($count,$sub) = @_;
  for( my $i = 0; $i < $count; ++$i ) {
    $sub->();
  }
}

run 1, \&_parse;

# print Data::Dumper->Dump( [[$p->enum], [$p->struct], [$p->typedef]],
#                            [qw(*enum *struct *typedef)] );

my $ndata = 0;
for( $p->typedefs, $p->structs ) {
  my $s = $p->sizeof( $_ );
  $ndata = $s if $s > $ndata;
}

my $data = pack 'C*', map rand 256, 1 .. $ndata;

run 25, \&_pack;

run 1, \&_member;

run 15, \&_typedef;
run 10, \&_struct;
run 200, \&_enum;

sub _parse {
  $p = new Convert::Binary::C ByteOrder   => 'BigEndian',
                              IntSize     => 4,
                              PointerSize => 4,
                              EnumSize    => 0,
                              Alignment   => 8,
                              Include     => ['t/include/perlinc',
                                              't/include/include'];

  $p->parsefile( 't/include/include.c' );
}

sub _pack {
  for( $p->typedefs, $p->structs ) {
    my $r = $p->unpack( $_, $data );
    my $d = $p->pack( $_, $r );
  }
}

sub _member {
  for( $p->typedefs, $p->structs ) {
    my($s, $i);
    for( $i = 0; $i < 25; ++$i ) {
      $s = $p->sizeof( $_ );
    }
    for( $i = 0; $i < $s; ++$i ) {
      $p->member( $_, $i );
    }
  }
}

sub _typedef {
  for( my $i = 0; $i < 100; ++$i ) {
    $p->typedefs;
  }
  $p->typedef( $_ ) for $p->typedefs;
  $p->typedef( $p->typedefs );
  $p->typedef;
}

sub _struct {
  for( my $i = 0; $i < 300; ++$i ) {
    $p->structs;
  }
  $p->struct( $_ ) for $p->structs;
  $p->struct( $p->structs );
  $p->struct;
}

sub _enum {
  for( my $i = 0; $i < 300; ++$i ) {
    $p->enums;
  }
  $p->enum( $_ ) for $p->enums;
  $p->enum( $p->enums );
  $p->enum;
}
