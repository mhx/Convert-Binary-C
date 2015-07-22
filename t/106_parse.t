################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/01/01 11:30:03 +0000 $
# $Revision: 11 $
# $Snapshot: /Convert-Binary-C/0.11 $
# $Source: /t/106_parse.t $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C @ARGV;

$^W = 1;

BEGIN { plan tests => 72 }

#===================================================================
# create object (1 tests)
#===================================================================
eval { $p = new Convert::Binary::C };
ok($@,'',"failed to create Convert::Binary::C object");

#===================================================================
# try to parse empty file / empty code (2 tests)
#===================================================================
eval { $p->parse_file( 't/include/files/empty.h' ) };
ok($@,'',"failed to parse empty C-file");

eval { $p->parse( '' ) };
ok($@,'',"failed to parse empty C-code");

#===================================================================
# check that parse/parse_file return object references (4 tests)
#===================================================================

$p = eval { Convert::Binary::C->new->parse_file( 't/include/files/empty.h' ) };
ok($@,'',"failed to create Convert::Binary::C object");
ok(ref $p, 'Convert::Binary::C',
   "object reference not blessed to Convert::Binary::C");

$p = eval { Convert::Binary::C->new->parse( '' ) };
ok($@,'',"failed to create Convert::Binary::C object");
ok(ref $p, 'Convert::Binary::C',
   "object reference not blessed to Convert::Binary::C");

#===================================================================
# create object (1 tests)
#===================================================================
eval {
  $p = new Convert::Binary::C EnumSize       => 0,
                              ShortSize      => 2,
                              IntSize        => 4,
                              LongSize       => 4,
                              LongLongSize   => 8,
                              PointerSize    => 4,
                              FloatSize      => 4,
                              DoubleSize     => 8,
                              LongDoubleSize => 12,
                              Include        => ['t/include/perlinc',
                                                 't/include/include'];
};
ok($@,'',"failed to create Convert::Binary::C object");

#===================================================================
# try to parse a file with lots of includes (1 test)
#===================================================================
eval {
  $p->parse_file( 't/include/include.c' );
};
ok($@,'',"failed to parse C-file");

#===================================================================
# check if context is correctly evaluated (10 tests)
# also do a quick check if the right stuff was parsed (12 tests)
#===================================================================

@enums     = $p->enum;
@compounds = $p->compound;
@structs   = $p->struct;
@unions    = $p->union;
@typedefs  = $p->typedef;

$s1 = @enums; $s2 = $p->enum;
ok($s1,$s2,"context not evaluated correctly in 'enum'");
ok($s1,34,"incorrect number of enums");

$s1 = @compounds; $s2 = $p->compound;
ok($s1,$s2,"context not evaluated correctly in 'compound'");
ok($s1,194,"incorrect number of compounds");

map {
  push @{$_->{type} eq 'union' ? \@r_unions : \@r_structs}, $_
} @compounds;

$s1 = @structs; $s2 = $p->struct;
ok($s1,$s2,"context not evaluated correctly in 'struct'");
$s2 = @r_structs;
ok($s1,$s2,"direct/indirect counts differ in 'struct'");
ok($s1,175,"incorrect number of structs");

$s1 = @unions; $s2 = $p->union;
ok($s1,$s2,"context not evaluated correctly in 'union'");
$s2 = @r_unions;
ok($s1,$s2,"direct/indirect counts differ in 'union'");
ok($s1,19,"incorrect number of unions");

$s1 = @typedefs; $s2 = $p->typedef;
ok($s1,$s2,"context not evaluated correctly in 'typedef'");
ok($s1,303,"incorrect number of typedefs");

@enum_ids     = $p->enum_names;
@compound_ids = $p->compound_names;
@struct_ids   = $p->struct_names;
@union_ids    = $p->union_names;
@typedef_ids  = $p->typedef_names;

$s1 = @enum_ids; $s2 = $p->enum_names;
ok($s1,$s2,"context not evaluated correctly in 'enum_names'");
ok($s1,4,"incorrect number of enum identifiers");

$s1 = @compound_ids; $s2 = $p->compound_names;
ok($s1,$s2,"context not evaluated correctly in 'compound_names'");
ok($s1,134,"incorrect number of compound identifiers");

$s1 = @struct_ids; $s2 = $p->struct_names;
ok($s1,$s2,"context not evaluated correctly in 'struct_names'");
ok($s1,129,"incorrect number of struct identifiers");

$s1 = @union_ids; $s2 = $p->union_names;
ok($s1,$s2,"context not evaluated correctly in 'union_names'");
ok($s1,5,"incorrect number of union identifiers");

$s1 = @typedef_ids; $s2 = $p->typedef_names;
ok($s1,$s2,"context not evaluated correctly in 'typedef_names'");
ok($s1,301,"incorrect number of typedef identifiers");

# catch warnings

$SIG{__WARN__} = sub {
  $_[0] =~ /Bitfields are unsupported in \w+\('wait'\)/ and return;
  print "# unexpected warning: $_[0]";
  push @fail, $_[0];
};

#===================================================================
# check if all sizes are correct (1 big test)
#===================================================================

do 't/include/sizeof.pl';
$max_size = 0;
@fail = ();

foreach( @enum_ids, @compound_ids, @typedef_ids ) {
  eval { $s = $p->sizeof($_) };

  if( $@ ) {
    print "# sizeof failed for '$_': $@\n";
  }
  elsif( not defined $s and not exists $size{$_} ) {
    next;
  }
  elsif( not exists $size{$_} ) {
    print "# can't find size for '$_'\n";
  }
  elsif( $size{$_} != $s ) {
    print "# incorrect size for '$_' (expected $size{$_}, got $s)\n";
  }
  else {
    $max_size = $s if $s > $max_size;
    next;
  }

  push @fail, $_ unless $s == $size{$_}
}

ok(@fail == 0);

#===================================================================
# check if the def method works correctly (1 big test)
#===================================================================

@names = ();
@fail = ();
push @names, map { { type => qr/^enum$/, id => $_ } }
             map { $_->{identifier} || () } $p->enum;
push @names, map { { type => qr/^(?:struct|union)$/, id => $_ } }
             map { $_->{identifier} || () } $p->compound;
push @names, map { { type => qr/^struct$/, id => $_ } }
             map { $_->{identifier} || () } $p->struct;
push @names, map { { type => qr/^union$/, id => $_ } }
             map { $_->{identifier} || () } $p->union;
push @names, map { { type => qr/^typedef$/,
                     id   => $_->{declarator} =~ /(\w+)/ } } $p->typedef;

for( @names ) {
  my $d = $p->def( $_->{id} );
  unless( defined $d ) {
    print "# def( '$_->{id}' ) = undef for existing type\n";
    push @fail, $_->{id};
    next;
  }
  if( $d xor exists $size{$_->{id}} ) {
    print "# def( '$_->{id}' ) = $d\n";
    push @fail, $_->{id};
    next;
  }
  if( $d and not $d =~ $_->{type} ) {
    unless( defined $p->$d( $_->{id} ) ) {
      print "# def( '$_->{id}' ) = $d ($_->{type})\n";
      push @fail, $_->{id};
      next;
    }
  }
}

ok(@fail == 0);

#===================================================================
# and check if we can pack and unpack everything (1 big test)
#===================================================================

sub chkpack
{
  my($orig, $pack) = @_;

  for( my $i = 0; $i < length $pack; ++$i ) {
    my $o = ord substr $orig, $i, 1;
    my $p = ord substr $pack, $i, 1;
    return 0 unless $p == $o or $p == 0;
  }

  return 1;
}

$data = pack 'C*', map rand 256, 1 .. $max_size;
@fail = ();

for my $id ( @enum_ids, @compound_ids, @typedef_ids ) {

  # skip long doubles
  next if grep { $id eq $_ } qw( __convert_long_double float_t double_t );

  eval { $x = $p->unpack( $id, $data ) };

  if( $@ ) {
    print "# unpack failed for '$id': $@\n";
    push @fail, $id;
    next;
  }

  eval { $packed = $p->pack( $id, $x ) };

  if( $@ ) {
    print "# pack failed for '$id': $@\n";
    push @fail, $id;
    next;
  }

  unless( chkpack( $data, $packed ) ) {
    print "# inconsistent pack/unpack data for '$id'\n";
    print "# \$data   => @{[map { sprintf '%02X', $_ } unpack 'C*', substr $data, 0, $p->sizeof($id)]}\n";
    print "# \$x      => $x\n";
    print "# \$packed => @{[map { sprintf '%02X', $_ } unpack 'C*', $packed]}\n";
    push @fail, $id;
  }
}

ok(@fail == 0);

#===================================================================
# check member and offsetof (1 big test)
#===================================================================

@fail = ();

foreach $type ( @compound_ids ) {
  next unless exists $size{$type};
  foreach( 0 .. $size{$type}-1 ) {
    eval { $x = $p->member( $type, $_ ) };
    if( $@ ) {
      print "# member failed for '$type', offset $_: $@\n";
      push @fail, $_;
    }
    if( $x !~ /\+\d+$/ ) {
      eval { $o = $p->offsetof( $type, $x ) };
      if( $@ ) {
        print "# offsetof failed for '$type', member '$x': $@\n";
        push @fail, $_;
      }
      if( $o != $_ ) {
        print "# offsetof( '$type', '$x' ) = $o, expected $_\n";
        push @fail, $_;
      }
    }
  }
}

ok(@fail == 0);

#===================================================================
# check reference counts (36 tests)
#===================================================================

eval {
  %rc = (
    configure   => $p->configure,
    include     => $p->Include,

    enums_s     => scalar $p->enum_names,
    enums_a     => [$p->enum_names],
    compounds_s => scalar $p->compound_names,
    compounds_a => [$p->compound_names],
    structs_s   => scalar $p->struct_names,
    structs_a   => [$p->struct_names],
    unions_s    => scalar $p->union_names,
    unions_a    => [$p->union_names],
    typedefs_s  => scalar $p->typedef_names,
    typedefs_a  => [$p->typedef_names],

    enum_s      => scalar $p->enum,
    enum_a      => [$p->enum],
    compound_s  => scalar $p->compound,
    compound_a  => [$p->compound],
    struct_s    => scalar $p->struct,
    struct_a    => [$p->struct],
    union_s     => scalar $p->union,
    union_a     => [$p->union],
    typedef_s   => scalar $p->typedef,
    typedef_a   => [$p->typedef],

    enum_sx     => scalar $p->enum( $p->enum_names ),
    enum_ax     => [$p->enum( $p->enum_names )],
    compound_sx => scalar $p->compound( $p->compound_names ),
    compound_ax => [$p->compound( $p->compound_names )],
    struct_sx   => scalar $p->struct( $p->struct_names ),
    struct_ax   => [$p->struct( $p->struct_names )],
    union_sx    => scalar $p->union( $p->union_names ),
    union_ax    => [$p->union( $p->union_names )],
    typedef_sx  => scalar $p->typedef( $p->typedef_names ),
    typedef_ax  => [$p->typedef( $p->typedef_names )],

    sizeof      => $p->sizeof( 'AMT' ),
    offsetof    => $p->offsetof( 'AMT', 'table[2]' ),
    member_sx   => scalar $p->member( 'AMT', 100 ),
    member_ax   => [$p->member( 'AMT', 100 )],
  );
};
ok($@,'',"method call failed");

$debug = Convert::Binary::C::feature( 'debug' );

for( keys %rc ) {
  $fail = $succ = 0;
  if( $debug ) {
    my $r = Convert::Binary::C::__DUMP__( $rc{$_} );
    while( $r =~ /REFCNT\s*=\s*(\d+)/g ) {
      if( $1 == 1 ) { $succ++ }
      else {
        print "# REFCNT = $1, should be 1\n";
        $fail++;
      }
    }
    print "# $_ (succ = $succ, fail = $fail)\n";
  }
  skip( $debug ? '' : 'skip: no debugging', $fail == 0 && $succ > 0 );
}

