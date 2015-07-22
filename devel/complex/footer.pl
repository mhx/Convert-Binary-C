
my($succ, $fail);

sub reccmp
{
  my($ident, $ref, $val, $sparse) = @_;

  unless( ref $ref ) {
    if( $ref == $val ) { $succ++ }
    else {
      $fail++;
      print "# value mismatch for '$ident' (expected $ref, got $val)\n";
    }
    return $ref == $val;
  }

  my $id = substr $ref, 0, 1;

  if( $id eq 'A' ) {
    if( $sparse or @$ref == @$val ) {
      $succ++;
      reccmp( $ident."[$_]", $ref->[$_], $val->[$_], $sparse ) for 0..$#$ref;
    }
    else {
      $fail++;
      print "# different array size for '$ident' (expected ",
            scalar @$ref, ", got ", scalar @$val, ")\n";
    }
  }
  elsif( $id eq 'H' ) {
    if( $sparse or @{[keys %$ref]} == @{[keys %$val]} ) {
      $succ++;
      for( keys %$ref ) {
        if( exists $val->{$_} ) {
          $succ++;
          reccmp( $ident.".$_", $ref->{$_}, $val->{$_}, $sparse );
        }
        else {
          $fail++;
          print "# member '$_' not found in '$ident'\n";
        }
      }
    }
    else {
      $fail++;
      print "# different struct member count for '$ident' (expected ",
            scalar @{[keys %$ref]}, ", got ", scalar @{[keys %$val]}, ")\n";
    }
  }
}

sub chkpack
{
  my($packref, $init) = @_;

  for( my $i = 0; $i < length $$packref; ++$i ) {
    my $o = ord substr $data, $i, 1;
    my $p = ord substr $$packref, $i, 1;

    unless( $p == $o or $p == 0 or (defined $init and $p == $init) ) {
      print "# inconsistent data in chkpack\n";
      return 0;
    }
  }

  return 1;
}

sub sparsecopy
{
  my $ref = shift;

  return $ref unless ref $ref;

  my $id = substr $ref, 0, 1;

  if( $id eq 'A' ) {
    return [ map { sparsecopy( $ref->[$_] ) } 0 .. ($#$ref/2) ];
  }
  elsif( $id eq 'H' ) {
    my $i = 0;
    return { map { ++$i%2 ? ($_ => sparsecopy( $ref->{$_} )) : () } sort keys %$ref };
  }
}

sub checkrc
{
  my $rc = shift;
  while( $rc =~ /REFCNT\s*=\s*(\d+)/g ) {
    if( $1 == 1 ) { $succ++ }
    else {
      print "# REFCNT = $1, should be 1\n";
      $fail++;
    }
  }
}

my $p = new Convert::Binary::C ByteOrder => 'LittleEndian',
                               IntSize   => 4,
                               Alignment => 4;

$p->parse( $types );

my $first = 1;

for my $align ( 4, sort keys %reference ) {
  if( $first ) { $first = 0 }
  else {
    $p->configure( Alignment => $align ) if $align;
  }

  my $sizeof  = $reference{$align}{sizeof};
  my $content = $reference{$align}{content};
  my $sparse  = { map { ( $_ => sparsecopy( $content->{$_} ) ) } keys %$content };
  my $members = $members{$align};

  # perform a basic size check first

  for( keys %$sizeof ) {
    my $size = $p->sizeof( $_ );
    print "# sizeof mismatch for type '$_' (expected $sizeof->{$_}, got $size)\n"
        unless $sizeof->{$_} == $size;
    ok( $sizeof->{$_} == $size );
  }

  # test if the unpack method works

  for( keys %$content ) {
    my $cont = $p->unpack( $_, $data );
    $succ = $fail = 0;
    reccmp( $_, $content->{$_}, $cont, 0 );
    ok( $fail == 0 && $succ > 0 );

    # check reference count
    $succ = $fail = 0;
    checkrc( Convert::Binary::C::__DUMP__( $cont ) );
    ok( $fail == 0 && $succ > 0 );
  }

  # test if the pack method works correctly

  for( keys %$content ) {
    my $packed = $p->pack( $_, $content->{$_} );
    ok( $sizeof->{$_} == length $packed );
    ok( chkpack( \$packed ) );

    my $cont = $p->unpack( $_, $packed );
    $succ = $fail = 0;
    reccmp( $_, $content->{$_}, $cont, 0 );
    ok( $fail == 0 );

    # check reference count
    $succ = $fail = 0;
    checkrc( Convert::Binary::C::__DUMP__( $packed ) );
    ok( $fail == 0 && $succ > 0 );
  }

  # test if pack also works for sparse data

  for( keys %$sparse ) {
    my $packed = $p->pack( $_, $sparse->{$_} );
    ok( $sizeof->{$_} == length $packed );
    ok( chkpack( \$packed ) );

    my $cont = $p->unpack( $_, $packed );
    $succ = $fail = 0;
    reccmp( $_, $sparse->{$_}, $cont, 1 );
    ok( $fail == 0 );
  }

  # test the 3-arg version of pack

  for( keys %$sparse ) {
    my $packed = 'x' x $sizeof->{$_};
    $p->pack( $_, $sparse->{$_}, $packed );
    ok( $sizeof->{$_} == length $packed );
    ok( chkpack( \$packed, ord 'x' ) );

    my $cont = $p->unpack( $_, $packed );
    $succ = $fail = 0;
    reccmp( $_, $sparse->{$_}, $cont, 1 );
    ok( $fail == 0 );

    # check reference count
    $succ = $fail = 0;
    checkrc( Convert::Binary::C::__DUMP__( $packed ) );
    ok( $fail == 0 && $succ > 0 );
  }

  # test if the member() and offsetof() methods work correctly

  for my $id ( keys %$members ) {
    $fail = 0;
    for( 0 .. $sizeof->{$id}-1 ) {
      my $m = $p->member( $id, $_ );
      my $r = $members->{$id}[$_];
      $r = "$members->{$id}[$_-$r]+$r" if $r =~ /^\d+$/;
      unless( $m eq $r ) {
        print "# member mismatch for type '$_' (expected $r, got $m)\n";
        $fail++;
      }
      if( $r !~ /\+\d+$/ ) {
        my $o = $p->offsetof( $id, $r );
        unless( defined $o and $o == $_ ) {
          print "# offsetof( '$id', '$r' ) == $o, expected $_\n";
          $fail++;
        }
      }
    }
    ok( $fail == 0 );
  }
}
