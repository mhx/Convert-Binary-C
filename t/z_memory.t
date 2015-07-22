################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/08/16 21:58:46 +0100 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.01 $
# $Source: /t/z_memory.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C;

$^W = 1;

BEGIN {
  $debug = Convert::Binary::C::feature( 'debug' );
  plan tests => $debug ? 55 : 1
}

ok( defined $debug );
$dbfile = 't/debug.out';

if( $debug ) {
  my $cmd  = "$^X -w -T " . join( ' ', map qq["-I$_"], @INC );
  my @args = ( debug => "m", debugfile => $dbfile ); 

  for my $test ( grep /[b-p]_[a-z]+\.t$/i, <t/*.t> ) {
    print "# testing '$test'\n";

    -e $dbfile and unlink $dbfile;

    open TEST, "$cmd $test @args |" or die $!;
    while(<TEST>){}
    close TEST;

    my $exf = -e $dbfile;
    ok( $exf, 1, "dubious: no debug output file created" );

    my %i = $exf ? get_alloc_info( $dbfile ) : ();

    skip( !$exf, ($i{allocs} || 0) > 0, 1, "dubious: no memory allocations" );
    skip( !$exf, $i{allocs}, $i{frees}, "malloc/free mismatch" );
    skip( !$exf, $i{leakage}, 0, "memory leaks detected" );

    for( qw( multi_alloc null_free unalloc_free not_free assert_fail ) ) {
      print "# $_:\n";
      skip( !$exf, exists $i{$_} ? @{$i{$_}} == 0 : 0 );
      $i{$_} && @{$i{$_}} or next;
      for( @{$i{$_}} ) { print "# $_\n" }
    }
  }
}

sub get_alloc_info {
  my $file = shift;
  my %alloc;
  my %info = (
    allocs       => 0,
    frees        => 0,
    max_blocks   => 0,
    max_total    => 0,
    multi_alloc  => [],
    null_free    => [],
    unalloc_free => [],
    not_free     => [],
    assert_fail  => [],
  );
  my $count = 0;
  my $total = 0;
  
  open MEM, $file or die $!;
  while( <MEM> ) {
    /^(.*?):(A|F|V)=(?:(\d+)\@)?([0-9a-zA-Z]{8})$/ or next;
    if( $2 eq 'A' ) {
      exists $alloc{$4} and
        push @{$info{multi_alloc}}, "0x$4 in $1 (previously allocated in $alloc{$4}[0])";
      next if exists $alloc{$4};
      $alloc{$4} = [$1,$3];
      $count++;
      $total += $3;
      $info{allocs}++;
      $info{min_size} = $info{max_size} = $3 unless exists $info{min_size};
      $info{min_size} = $3 if $3 < $info{min_size};
      $info{max_size} = $3 if $3 > $info{max_size};
    }
    elsif( $2 eq 'F' ) {
      $4 eq '00000000' and push @{$info{null_free}}, "0x$4 in $1";
      exists $alloc{$4} or push @{$info{unalloc_free}}, "0x$4 in $1";
      next unless exists $alloc{$4};
      $count--;
      $total -= $alloc{$4}[1];
      $info{frees}++;
      delete $alloc{$4};
    }
    else { # $2 eq 'V'
      exists $alloc{$4} or push @{$info{assert_fail}}, "0x$4 in $1";
      next; # nothing needs to be updated
    }
    $info{max_blocks} = $count if $count > $info{max_blocks};
    $info{max_total}  = $total if $total > $info{max_total};
  }
  close MEM;
  
  for( sort keys %alloc ) {
    push @{$info{not_free}}, "0x$_ in $alloc{$_}[0]";
  }

  $info{leakage} = $total;
  %info;
}

