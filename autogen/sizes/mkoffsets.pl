use Data::Dumper;
use Convert::Binary::C;
use strict;

my $cfg = require '../../tests/include/config.pl';
s!^tests!../../tests! for @{$cfg->{Include}};

my $c = new Convert::Binary::C %$cfg;

$c->parse_file( '../../tests/include/include.c' );

my $defs = $c->sourcify;

my %skip = map { ($_ => 1) } qw( _IO_lock_t );

print <<ENDC;

#pragma pack(1)

$defs

int main( void ) {
ENDC

print_offsets( $_ ) for qw( struct union typedef );

print <<ENDC;
  return 0;
}
ENDC


sub print_offsets
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
ENDC
    my @m = eval { $c->member( $t ) };
    if( $@ ) {
      $@ =~ /Cannot use member on an? (basic|pointer|enum)/ or warn $@;
    }
    else {
      for my $m ( @m ) {
        do {
          eval { my $s = $c->sizeof( $t.$m ) };
          if( $@ ) {
            $@ =~ /Cannot use sizeof on bitfields/ or warn $@;
          }
          else {
            my $type   = $m;
            my $member = '';
            do {
              $type =~ s/(\[\d+\]|\.\w+)$//;
              $member = $1 . $member;

              print <<ENDC;
    printf("$t$type,$member=%d\\n", ((char *)&dummy$type$member) - ((char *)&dummy$type));
ENDC
            } while( $type );
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
