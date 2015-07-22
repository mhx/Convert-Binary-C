use strict;

my @PERLS = @ARGV ? @ARGV : ('perl');
my $MAKE = $^O eq 'MSWin32' ? 'nmake' : 'make';

for my $perl ( @PERLS ) {
  my @perl_ver = `$perl -V`;
  print STDERR "Using Perl Binary: $perl\n";
  print <<END;
===============================================================================
Using Perl: $perl

@perl_ver;
===============================================================================
END

  my(undef,undef,$usage) = exec_cmd( "$perl Makefile.PL help" );
  
  my @OPT  = split ' ', ($usage =~ /Options:\s*(.*)/)[0];
  my @FEAT = split ' ', ($usage =~ /Features:\s*(.*)/)[0];

  for my $opt ( undef, map { "optimize=$_" } @OPT ) {
    make_features( $perl, [@FEAT], ($opt || ()) );
  }
}

sub make_features {
  my($perl, $feat) = splice @_, 0, 2;
  if( @$feat ) {
    my $f = shift @$feat;
    make_features( $perl, [@$feat], @_, "enable-$f" );
    make_features( $perl, [@$feat], @_, "disable-$f" );
  }
  else {
    make_mod( $perl, @_ );
  }
}

sub make_mod {
  my $perl   = shift;
  my $tested = 0;
  my($pout,$perr,$mout,$merr,$tout,$terr);

  print <<END;
-------------------------------------------------------------------------------
Configuration: [@_]
-------------------------------------------------------------------------------
END
  print STDERR "Configuration: [@_] ...";

  eval {
    my $r;
    print STDERR " Makefile.PL ...";
    ($r,$pout,$perr) = exec_cmd( "$perl Makefile.PL @_" );
    if( $r == 0 ) {
      print STDERR " making ...";
      ($r,$mout,$merr) = exec_cmd( "$MAKE" );
      if( $r == 0 ) {
        print STDERR " testing ...";
        ($r,$tout,$terr) = exec_cmd( "$MAKE test" );
        if( $r == 0 ) { $tested = 1 }
        else { print STDERR " FAILED ($r)" }
      }
      else { print STDERR " FAILED ($r)" }

      print STDERR " cleaning up";
      exec_cmd( "$MAKE realclean" );
    }
    else { print STDERR " FAILED ($r)" }
  };
  print STDERR "\n";
  $@ and die $@;

  print $pout, $perr, $mout, $merr, $tout, $terr;

  $perr and print "  => output on STDERR during generation of Makefile.PL\n";
  $merr and print "  => output on STDERR during compilation\n";
  $terr and print "  => output on STDERR during test\n";

  $perr and print STDERR "  => output on STDERR during generation of Makefile.PL\n";
  $merr and print STDERR "  => output on STDERR during compilation\n";
  $terr and print STDERR "  => output on STDERR during test\n";

  if( $tested ) {
    my %tests;

    @tests{<t/*.t>} = 1;

    my $failed = 0;
    for( split $/, $tout ) {
      my($t,$r) = /^(t[\\\/]\w+)\.+(\w+)/ or next;
      $t =~ tr[\\][/];
      delete $tests{"$t.t"};
      next if $r eq 'ok';
      print STDERR "  => test failed: $t ($r)\n";
      $failed++;
    }

    if( keys %tests ) {
      print STDERR "  => '$_' did not run\n" for keys %tests;
    }
    else {
      $failed or print STDERR "  => all tests passed\n";
    }
  }
  else {
    print "Configuration [@_] FAILED\n";
    print STDERR "  => FAILED\n";
  }
}

sub exec_cmd {
  my $cmd = shift;
  my($ret,$out,$err);
  print "$cmd\n";
  $ret = system( $cmd . " 1>_out_ 2>_err_" );
  open OUT, '_out_' or die $!;
  $out = do { local $/; <OUT> };
  close OUT;
  open ERR, '_err_' or die $!;
  $err = do { local $/; <ERR> };
  close ERR;
  unlink '_out_', '_err_';
  ($ret,$out,$err);
}
