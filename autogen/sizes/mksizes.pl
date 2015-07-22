use Data::Dumper;
use Convert::Binary::C;
use strict;

my $c = new Convert::Binary::C Include => ['../../t/include/perlinc',
                                           '../../t/include/include'];

$c->parse_file( '../../t/include/include.c' );

my $defs = $c->sourcify;

print <<ENDC;

#pragma pack(1)

$defs

int main( void ) {
ENDC

for( $c->enum_names ) {
  next unless $c->def( $_ );
  print <<ENDC;
  printf("$_=%d\\n", sizeof( enum $_ ));
ENDC
}

for( $c->struct_names ) {
  next unless $c->def( $_ );
  print <<ENDC;
  printf("$_=%d\\n", sizeof( struct $_ ));
ENDC
}

for( $c->union_names ) {
  next unless $c->def( $_ );
  print <<ENDC;
  printf("$_=%d\\n", sizeof( union $_ ));
ENDC
}

for( $c->typedef_names ) {
  next unless $c->def( $_ );
  print <<ENDC;
  printf("$_=%d\\n", sizeof( $_ ));
ENDC
}

print <<ENDC;
  return 0;
}
ENDC
