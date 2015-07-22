################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/10/25 17:42:36 +0100 $
# $Revision: 5 $
# $Source: /tests/802_pod.t $
#
################################################################################
#
# Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

# find all potential pod files
if( open F, "MANIFEST" ) {
  chomp( @files = <F> );
  close F;
  for my $f ( @files ) {
    $f =~ m!^tests/include! and next;
    if( open F, $f ) {
      while( <F> ) {
        if( /^=\w+/ ) {
          push @pods, $f;
          last;
        }
      }
      close F;
    }
  }
}

# load Test::Pod if possible, otherwise load Test
eval {
  require Test::Pod;
  $Test::Pod::VERSION >= 0.95
      or die "Test::Pod version only $Test::Pod::VERSION";
  import Test::Pod tests => scalar @pods;
};
$TP = $@ eq '';
unless( $TP ) {
  require Test;
  import Test;
  plan( tests => scalar @pods );
}

for my $pod ( @pods ) {
  print "# checking $pod\n";
  if( $TP ) {
    pod_file_ok( $pod );
  }
  else {
    skip( "skip: testing pod requires Test::Pod", 0 );
  }
}
