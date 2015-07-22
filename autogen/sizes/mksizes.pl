use Data::Dumper;
use Convert::Binary::C;
use strict;

my $c = new Convert::Binary::C Include => ['../../tests/include/perlinc',
                                           '../../tests/include/include'];

$c->parse_file( '../../tests/include/include.c' );

my $defs = $c->sourcify;

my %skip = map { ($_ => 1) } qw( _IO_lock_t );
my %seen;

print <<ENDC;

#pragma pack(1)

$defs

int printf(const char *, ...);

int main(void)
{
ENDC

for my $t ( $c->enum_names ) {
  next unless $c->def( $t );
  print <<ENDC;
  printf("$t=%d\\n", sizeof( enum $t ));
ENDC
}

print_sizes( $_ ) for qw( struct union typedef );

print <<ENDC;
  return 0;
}
ENDC

sub print_sizes
{
  my $what = shift;
  my($meth, $prefix);

  $meth   = "${what}_names";
  $prefix = $what eq 'typedef' ? '' : "$what ";

  for my $t ( $c->$meth ) {
    next unless $c->def( $t );
    next if exists $skip{$t};
    print <<ENDC;
  {
    $prefix$t dummy;
    printf("$t=%d\\n", sizeof(dummy));
ENDC
    my @m = eval { $c->member( $t ) };
    if( $@ ) {
      $@ =~ /Cannot use member on an? (basic|scalar|pointer|enum)/ or warn $@;
    }
    else {
      for my $m ( @m ) {
        do {
          unless( $seen{"$t$m"}++ ) {
            eval { my $s = $c->sizeof( $t.$m ) };
            if( $@ ) {
              $@ =~ /Cannot use sizeof on bitfields/ or warn $@;
            }
            else {
              print <<ENDC;
    printf("$t$m=%d\\n", sizeof(dummy$m));
ENDC
            }
          }
          $m =~ s/(?:\[\d+\]|\.\w+)$//;
        } while( $m );
      }
    }
    print <<ENDC;
  }
ENDC
  }
}
