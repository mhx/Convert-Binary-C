
my($succ, $fail);

sub reccmp
{
  my($ident, $ref, $val, $sparse) = @_;

  my $id = ref $ref;

  unless ($id) {
    if ($ref eq $val) { $succ++ }
    else {
      $fail++;
      print "# value mismatch for '$ident' (expected $ref, got $val)\n";
    }
    return $ref eq $val;
  }

  if ($id eq 'ARRAY') {
    if ($sparse or @$ref == @$val) {
      $succ++;
      reccmp($ident."[$_]", $ref->[$_], $val->[$_], $sparse) for 0..$#$ref;
    }
    else {
      $fail++;
      print "# different array size for '$ident' (expected ",
            scalar @$ref, ", got ", scalar @$val, ")\n";
    }
  }
  elsif ($id eq 'HASH') {
    if ($sparse or @{[keys %$ref]} == @{[keys %$val]}) {
      $succ++;
      for (keys %$ref) {
        if (exists $val->{$_}) {
          $succ++;
          reccmp($ident.".$_", $ref->{$_}, $val->{$_}, $sparse);
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
  my($packref, $init, $off) = @_;

  $off ||= 0;

  for (my $i = 0; $i < length $$packref; ++$i) {
    my $o = ord substr $data, $off+$i, 1;
    my $p = ord substr $$packref, $i, 1;

    unless ($p == $o or $p == 0 or (defined $init and $p == $init)) {
      print "# inconsistent data in chkpack\n";
      return 0;
    }
  }

  return 1;
}

sub sparsecopy
{
  my $ref = shift;

  my $id = ref $ref or return $ref;

  if ($id eq 'ARRAY') {
    return [ map { sparsecopy($ref->[$_]) } 0 .. ($#$ref/2) ];
  }
  elsif ($id eq 'HASH') {
    my $i = 0;
    return { map { ++$i%2 ? ($_ => sparsecopy($ref->{$_})) : () } sort keys %$ref };
  }
}

sub reccheck
{
  my($cont, $meth, $id) = @_;

  my $r = ref $cont or return (0, 0);

  my($ok, $rcok) = (0, 0);
  my($o, $ro);

  if ($r eq 'ARRAY') {
    for my $ix (0 .. $#$cont) {
      ($o,$ro) = $meth->("$id\[$ix\]", $cont->[$ix]);
      $ok += $o; $rcok += $ro;
      ($o,$ro) = reccheck($cont->[$ix], $meth, "$id\[$ix\]");
      $ok += $o; $rcok += $ro;
    }
  }
  elsif ($r eq 'HASH') {
    for my $mem (keys %$cont) {
      my $new = defined $id ? "$id.$mem" : $mem;
      ($o,$ro) = $meth->($new, $cont->{$mem});
      $ok += $o; $rcok += $ro;
      ($o,$ro) = reccheck($cont->{$mem}, $meth, $new);
      $ok += $o; $rcok += $ro;
    }
  }

  ($ok, $rcok);
}

sub checkrc
{
  my $rc = shift;
  while ($rc =~ /REFCNT\s*=\s*(\d+)/g) {
    if ($1 == 1) { $succ++ }
    else {
      print "# REFCNT = $1, should be 1\n";
      $fail++;
    }
  }
}

my $p = new Convert::Binary::C ByteOrder   => 'LittleEndian',
                               ShortSize   => 2,
                               IntSize     => 4,
                               LongSize    => 4,
                               PointerSize => 4,
                               FloatSize   => 4,
                               DoubleSize  => 8,
                               Alignment   => 4;

$p->parse($types);

my $first = 1;

my $debug = Convert::Binary::C::feature('debug');
my $reason = $debug ? '' : 'no debugging';

for my $align (4, sort keys %reference) {
  if ($first) { $first = 0 }
  else {
    $p->configure(Alignment => $align) if $align;
  }

  my $sizeof  = $reference{$align}{sizeof};
  my $content = $reference{$align}{content};
  my $sparse  = { map { ( $_ => sparsecopy($content->{$_}) ) } keys %$content };
  my $members = $members{$align};
  my $sizeofs = $sizeofs{$align};

  # perform a basic size check first

  for (keys %$sizeof) {
    my $size = $p->sizeof($_);
    print "# sizeof mismatch for type '$_' (expected $sizeof->{$_}, got $size)\n"
        unless $sizeof->{$_} == $size;
    ok($sizeof->{$_} == $size);
  }

  # test if the unpack method works

  for (keys %$content) {
    my $cont = $p->unpack($_, $data);
    $succ = $fail = 0;
    reccmp($_, $content->{$_}, $cont, 0);
    ok($fail == 0 && $succ > 0);

    # check reference count
    $succ = $fail = 0;
    $debug and checkrc(Convert::Binary::C::__DUMP__($cont));
    skip($reason, $fail == 0 && $succ > 0);
  }

  # test if the pack method works correctly

  for (keys %$content) {
    my $packed = $p->pack($_, $content->{$_});
    ok($sizeof->{$_} == length $packed);
    ok(chkpack(\$packed));

    my $cont = $p->unpack($_, $packed);
    $succ = $fail = 0;
    reccmp($_, $content->{$_}, $cont, 0);
    ok($fail == 0);

    # check reference count
    $succ = $fail = 0;
    $debug and checkrc(Convert::Binary::C::__DUMP__($packed));
    skip($reason, $fail == 0 && $succ > 0);
  }

  # test if pack also works for sparse data

  for (keys %$sparse) {
    my $packed = $p->pack($_, $sparse->{$_});
    ok($sizeof->{$_} == length $packed);
    ok(chkpack(\$packed));

    my $cont = $p->unpack($_, $packed);
    $succ = $fail = 0;
    reccmp($_, $sparse->{$_}, $cont, 1);
    ok($fail == 0);
  }

  # test the 3-arg version of pack

  for (keys %$sparse)
  {
    my $packed = 'x' x $sizeof->{$_};
    $p->pack($_, $sparse->{$_}, $packed);
    ok($sizeof->{$_} == length $packed);
    ok(chkpack(\$packed, ord 'x'));

    my $cont = $p->unpack($_, $packed);
    $succ = $fail = 0;
    reccmp($_, $sparse->{$_}, $cont, 1);
    ok($fail == 0);

    # check reference count
    $succ = $fail = 0;
    $debug and checkrc(Convert::Binary::C::__DUMP__($packed));
    skip($reason, $fail == 0 && $succ > 0);
  }

  # test if the member(), offsetof() and typeof() methods work correctly

  for my $id (keys %$members) {
    $fail = 0;
    my $ref = $members->{$id};

    for (0 .. $sizeof->{$id}-1) {
      my $m = $p->member($id, $_);
      my @m = $p->member($id, $_);
      my $r = $ref->[$_];

      # print "# member( '$id', $_ ) = (", join(', ', map "'$_'", @m), ")\n";

      unless ($m eq $m[0])
      {
        print "# member mismatch for different contexts ('$m' ne '$m[0]')\n";
        $fail++;
      }

      if (@m > 1) {
        my %seen;
        for (@m) {
          if ($seen{$_}++) {
            print "# duplicate member found in list context output\n";
            $fail++;
          }
        }
      }

      $r =~ /^\d+$/o and $r = "$ref->[$_-$r]+$r";
      $r =~ /^\w/o   and $r = ".$r";

      unless ($m eq $r) {
        print "# member mismatch for type '$id', offset $_ (expected $r, got $m)\n";
        $fail++;
      }

      unless ($m =~ /^\+\d+$/) {
        my $t = $p->typeof($id.$m);
        unless (defined $t) {
          print "# undefined type for member ($id.$m)\n";
          $fail++;
        }
      }

      my $o = $p->offsetof($id, $m);
      unless (defined $o and $o == $_) {
        print "# offsetof( '$id', '$m' ) == $o, expected $_\n";
        $fail++;
      }
    }
    ok($fail == 0);
  }

  # test if the sizeof() methods works for compound members

  for my $id (keys %$sizeofs) {
    $fail = 0;
    my $ref = $sizeofs->{$id};

    for my $size (keys %$ref) {
      for my $member (@{$ref->{$size}}) {
        $size == $p->sizeof("$id.$member") or $fail++;
      }
    }
    ok($fail == 0);
  }

  # test if the unpack method works for compound members

  for (keys %$content) {
    my($ok, $rcok) = reccheck($content->{$_}, \&unpackcheck, $_);
    ok($ok);
    skip($reason, $rcok);
  }

  # test if the pack method works for compound members

  for (keys %$content) {
    my($ok, $rcok) = reccheck($content->{$_}, \&packcheck, $_);
    ok($ok);
    skip($reason, $rcok);
  }

  # test Format tag (offsetof and sizeof are already validated above)

  for my $id (keys %$members) {
    my @members = $p->member($id);
    my %seen;
    for my $m (@members) {
      next if $m =~ /\[[^0]+\]/;

      $fail = $succ = 0;

      while ($m) {
        $m =~ s/(?:\[\d*\])+$//;

        last if $seen{$m}++;

        my $offs = $p->offsetof($id, $m);
        my $size = $p->sizeof($id.$m);
        my $bin = substr $data, $offs, $size;
        my($str) = $bin =~ /^([^\x00]*)/;
        my $pl = $m;
        my $rv;

        print "# --- $id$m\n";

        $pl =~ s/\.(\w+)/{$1}/g;

        $p->tag($id.$m, Format => 'Binary');

        $rv = $p->unpack($id.$m, $bin);
        $rv eq $bin or $fail++;

        $rv = $p->pack($id.$m, $bin);
        $rv eq $bin or $fail++;

        $rv = $p->unpack($id, $data);
        eval "\$rv->$pl" eq $bin or $fail++;

        $p->tag($id.$m, Format => 'String');

        $rv = $p->unpack($id.$m, $bin);
        $rv eq $str or $fail++;

        # use re 'debug';

        $rv = $p->pack($id.$m, $str);
        length($rv) == $size or $fail++;
        $rv =~ /^\Q$str\E\x00*$/ or $fail++;

        $rv = $p->unpack($id, $data);
        eval "\$rv->$pl" eq $str or $fail++;

        $p->tag($id.$m, Format => undef);

        $m =~ s/\.\w+$//;

        $succ++;
      }

      ok($fail == 0) if $succ;
    }
  }
}

sub unpackcheck
{
  my($id, $ref) = @_;
  my($type, $member) = split /\./, $id, 2;

  my $off  = defined $member ? $p->offsetof($type, $member) : 0;
  my $size = $p->sizeof($id);
  my $d    = substr $data, $off, $size;

  my $cont = $p->unpack($id, $d);
  $succ = $fail = 0;
  reccmp($id, $ref, $cont, 0);
  my $ok = $fail == 0 && $succ > 0;

  $ok or print "# check failed for unpack('$id')\n";

  $succ = $fail = 0;
  $debug and checkrc(Convert::Binary::C::__DUMP__($cont));
  my $rcok = $fail == 0 && $succ > 0;

  $rcok or $reason or print "# refcount check failed for unpack('$id')\n";

  ($ok, $rcok);
}

sub packcheck
{
  my($id, $ref) = @_;
  my($type, $member) = split /\./, $id, 2;

  my $off  = defined $member ? $p->offsetof($type, $member) : 0;
  my $size = $p->sizeof($id);
  my $d    = substr($data, $off, $size);

  my $packed = $p->pack($id, $ref);
  my $ok = 1;

  $size == length $packed
    or $ok = 0, print "# size check failed for pack('$id')\n";
  chkpack( \$packed, 0, $off )
    or $ok = 0, print "# chkpack check failed for pack('$id')\n";

  my $cont = $p->unpack($id, $packed);
  $succ = $fail = 0;
  reccmp($id, $ref, $cont, 0);
  $fail == 0 && $succ > 0
    or $ok = 0, print "# check failed for pack('$id')\n";

  $succ = $fail = 0;
  $debug and checkrc(Convert::Binary::C::__DUMP__($cont));
  my $rcok = $fail == 0 && $succ > 0;

  $rcok or $reason or print "# refcount check failed for unpack('$id')\n";

  ($ok, $rcok);
}



