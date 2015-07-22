################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/11/23 17:24:27 +0000 $
# $Revision: 9 $
# $Snapshot: /Convert-Binary-C/0.04 $
# $Source: /t/101_config.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C @ARGV;

use constant SUCCEED => 1;
use constant FAIL    => 0;

$^W = 1;

BEGIN {
  $C99 = Convert::Binary::C::feature( 'c99' );
  plan tests => $C99 ? 1675 : 1501
}

ok( defined $C99 );

# passing references as options is not legal, so this is
# always checked for non-list options
@refs = (
  { in =>  [12], result => FAIL },
  { in =>  \123, result => FAIL },
  { in => {1,2}, result => FAIL },
);

$thisfile = quotemeta "at $0";

sub check_config
{
  my $option = shift;
  my @warn;
  my $value;

  local $SIG{__WARN__} = sub { push @warn, shift };

  for my $config ( @_ ) {
    @warn = ();

    my $reference = $config->{out} || $config->{in};

    eval { $p = new Convert::Binary::C };
    ok($@, '', "failed to create Convert::Binary::C object");

    print "# \$p->configure( $option => $config->{in} )\n";
    eval { $p->configure( $option => $config->{in} ) };
    if( $@ ) {
      my $err = $@;
      $err =~ s/^/#   /g;
      print "# failed due to:\n$err";
    }
    ok( ($@ eq '' ? SUCCEED : FAIL), $config->{result},
        "$option => $config->{in}" );
    ok( $@, qr/$option must be.*not.*$thisfile/ ) if $config->{result} == FAIL;

    print "# \$p->$option( $config->{in} )\n";
    eval { $p->$option( $config->{in} ) };
    if( $@ ) {
      my $err = $@;
      $err =~ s/^/#   /g;
      print "# failed due to:\n$err";
    }
    ok( ($@ eq '' ? SUCCEED : FAIL), $config->{result},
        "$option => $config->{in}" );
    ok( $@, qr/$option must be.*not.*$thisfile/ ) if $config->{result} == FAIL;

    if( $config->{result} == SUCCEED ) {
      print "# \$value = \$p->configure( $option )\n";
      eval { $value = $p->configure( $option ) };
      ok( $@, '', "cannot get value for '$option' via configure" );
      ok( $value, $reference, "invalid value for '$option' via configure" );

      print "# \$value = \$p->$option\n";
      eval { $value = $p->$option() };
      ok( $@, '', "cannot get value for '$option' via $option" );
      ok( $value, $reference, "invalid value for '$option' via $option" );
    }

    ok( scalar @warn, 0, "warnings issued for option '$option'" );
  }

  @warn = ();
  print "# \$p->configure( $option )\n";
  eval { $p->configure( $option ) };
  ok( $@, '', "failed to call configure in void context" );
  if( @warn ) { print "# issued warnings:\n", map "#   $_", @warn }
  ok( scalar @warn, 1, "invalid number of warnings issued" );
  ok( $warn[0], qr/Useless use of configure in void context.*$thisfile/ );

  @warn = ();
  print "# \$p->$option\n";
  eval { $p->$option() };
  ok( $@, '', "failed to call $option in void context" );
  if( @warn ) { print "# issued warnings:\n", map "#   $_", @warn }
  ok( scalar @warn, 1, "invalid number of warnings issued" );
  ok( $warn[0], qr/Useless use of $option in void context.*$thisfile/ );
}

sub check_config_bool
{
  my $option = shift;

  my @tests = (
     { in =>     0, out => 0, result => SUCCEED },
     { in =>     1, out => 1, result => SUCCEED },
     { in =>  4711, out => 1, result => SUCCEED },
     { in =>   -42, out => 1, result => SUCCEED },
     @refs
  );

  check_config( $option, @tests );
}

sub check_option_strlist
{
  my $option = shift;
  my @warn;
  my @tests = (
    { in => \4711,                 result => FAIL, error => qr/$option wants an array reference/ },
    { in => [],                    result => SUCCEED },
    { in => { key => 'val' },      result => FAIL, error => qr/$option wants an array reference/ },
    { in => ['inc', 'usr', 'lib'], result => SUCCEED },
  );

  local $SIG{__WARN__} = sub { push @warn, shift };

  for my $config ( @tests ) {
    @warn = ();

    eval { $p = new Convert::Binary::C };
    ok($@, '', "failed to create Convert::Binary::C object");

    print "# \$p->configure( $option => $config->{in} )\n";
    eval { $p->configure( $option => $config->{in} ) };
    if( $@ ) {
      my $err = $@;
      $err =~ s/^/#   /g;
      print "# failed due to:\n$err";
    }
    ok( ($@ eq '' ? SUCCEED : FAIL), $config->{result},
        "$option => $config->{in}" );
    ok( $@, $config->{error} ) if $config->{result} == FAIL;

    print "# \$p->$option( $config->{in} )\n";
    eval { $p->$option( $config->{in} ) };
    if( $@ ) {
      my $err = $@;
      $err =~ s/^/#   /g;
      print "# failed due to:\n$err";
    }
    ok( ($@ eq '' ? SUCCEED : FAIL), $config->{result},
        "$option => $config->{in}" );
    ok( $@, $config->{error} ) if $config->{result} == FAIL;

    if( $config->{result} == SUCCEED ) {
      print "# \$value = \$p->configure( $option )\n";
      eval { $value = $p->configure( $option ) };
      ok( $@, '', "cannot get value for '$option' via configure" );
      ok( "@$value", "@{$config->{in}}", "invalid value for '$option' via configure" );

      print "# \$value = \$p->$option\n";
      eval { $value = $p->$option() };
      ok( $@, '', "cannot get value for '$option' via $option" );
      ok( "@$value", "@{$config->{in}}", "invalid value for '$option' via $option" );
    }

    ok( scalar @warn, 0, "warnings issued for option '$option'" );
  }

  @warn = ();
  print "# \$p->configure( $option )\n";
  eval { $p->configure( $option ) };
  ok( $@, '', "failed to call configure in void context" );
  if( @warn ) { print "# issued warnings:\n", map "#   $_", @warn }
  ok( scalar @warn, 1, "invalid number of warnings issued" );
  ok( $warn[0], qr/Useless use of configure in void context.*$thisfile/ );

  @warn = ();
  print "# \$p->$option\n";
  eval { $p->$option() };
  ok( $@, '', "failed to call $option in void context" );
  if( @warn ) { print "# issued warnings:\n", map "#   $_", @warn }
  ok( scalar @warn, 1, "invalid number of warnings issued" );
  ok( $warn[0], qr/Useless use of $option in void context.*$thisfile/ );

  @warn = ();
  eval {
    $p->$option( [qw(foo bar)] );
    $p->$option( 'include' );
    $p->$option( qw(a b c) );
    $value = $p->$option();
  };
  ok( $@, '', "failed to call $option with various arguments" );
  if( @warn ) { print "# issued warnings:\n", map "#   $_", @warn }
  ok( scalar @warn, 0, "invalid number of warnings issued" );
  ok( "@$value", "@{[qw(foo bar include a b c)]}", "invalid value for '$option'" );
}

sub compare_config
{
  my($cfg1, $cfg2) = @_;
  ok( scalar keys %$cfg1, scalar keys %$cfg2, "differing options count" );
  for( keys %$cfg1 ) {
    if( ref $cfg1->{$_} ) {
      ok( "@{$cfg1->{$_}}", "@{$cfg2->{$_}}", "option '$_' has different values" );
    }
    else {
      ok( $cfg1->{$_}, $cfg2->{$_}, "option '$_' has different values" );
    }
  }
}

@tests = (
  { in => -1,  result => FAIL    },
  { in =>  0,  result => SUCCEED },
  { in =>  1,  result => SUCCEED },
  { in =>  2,  result => SUCCEED },
  { in =>  3,  result => FAIL    },
  { in =>  4,  result => SUCCEED },
  { in =>  5,  result => FAIL    },
  { in =>  6,  result => FAIL    },
  { in =>  7,  result => FAIL    },
  { in =>  8,  result => SUCCEED },
  { in =>  9,  result => FAIL    },
  @refs
);

check_config( $_, @tests ) for qw( PointerSize
                                   IntSize
                                   ShortSize
                                   LongSize
                                   LongLongSize );

@tests = (
  { in => -1,  result => FAIL    },
  { in =>  0,  result => SUCCEED },
  { in =>  1,  result => SUCCEED },
  { in =>  2,  result => SUCCEED },
  { in =>  3,  result => FAIL    },
  { in =>  4,  result => SUCCEED },
  { in =>  5,  result => FAIL    },
  { in =>  6,  result => FAIL    },
  { in =>  7,  result => FAIL    },
  { in =>  8,  result => FAIL    },
  { in =>  9,  result => FAIL    },
  @refs
);

check_config( $_, @tests ) for qw( EnumSize );

@tests = (
  { in => -1, result => FAIL    },
  { in =>  0, result => SUCCEED },
  { in =>  1, result => SUCCEED },
  { in =>  2, result => SUCCEED },
  { in =>  3, result => FAIL    },
  { in =>  4, result => SUCCEED },
  { in =>  5, result => FAIL    },
  { in =>  6, result => FAIL    },
  { in =>  7, result => FAIL    },
  { in =>  8, result => SUCCEED },
  { in =>  9, result => FAIL    },
  { in => 10, result => FAIL    },
  { in => 11, result => FAIL    },
  { in => 12, result => SUCCEED },
  { in => 13, result => FAIL    },
  @refs
);

check_config( $_, @tests ) for qw( FloatSize
                                   DoubleSize
                                   LongDoubleSize );
                                   
@tests = (
  { in => -1, result => FAIL    },
  { in =>  0, result => FAIL    },
  { in =>  1, result => SUCCEED },
  { in =>  2, result => SUCCEED },
  { in =>  3, result => FAIL    },
  { in =>  4, result => SUCCEED },
  { in =>  5, result => FAIL    },
  { in =>  6, result => FAIL    },
  { in =>  7, result => FAIL    },
  { in =>  8, result => SUCCEED },
  { in =>  9, result => FAIL    },
  @refs
);

check_config( $_, @tests ) for qw( Alignment );

check_config( 'ByteOrder',
  { in => 'BigEndian',    result => SUCCEED },
  { in => 'LittleEndian', result => SUCCEED },
  { in => 'NoEndian',     result => FAIL    },
  @refs
);

check_config( 'EnumType',
  { in => 'Integer', result => SUCCEED },
  { in => 'String',  result => SUCCEED },
  { in => 'Both',    result => SUCCEED },
  { in => 'None',    result => FAIL    },
  @refs
);

check_config_bool( $_ ) for qw( HasVOID
                                UnsignedChars
                                Warnings );

if( $C99 ) {
  check_config_bool( $_ ) for qw( HasC99Keywords
                                  HasCPPComments
                                  HasMacroVAARGS );
}

check_option_strlist( $_ ) for qw( Include
                                   Define
                                   Assert );

#===================================================================
# check invalid configuration
#===================================================================
@tests = (
  { value => [1, 2, 3], result => FAIL, error => qr/Invalid number of arguments to configure.*$thisfile/ },
  { value => [[1], 2],  result => FAIL, error => qr/Option name must be a string, not a reference.*$thisfile/ },
);
foreach $config ( @tests )
{
  eval {
    $p = new Convert::Binary::C;
    $p->configure( @{$config->{value}} );
  };
  ok( ($@ eq '' ? SUCCEED : FAIL), $config->{result},
      "invalid configuration: " . join(', ', @{$config->{value}}) );
  ok( $@, $config->{error} ) if exists $config->{error};
}

#===================================================================
# check invalid option
#===================================================================
eval {
  $p = new Convert::Binary::C;
  $p->configure(
    Something => 'xxx',
    ByteOrder => 'BigEndian',
    EnumSize  => 0,
  );
};
ok( $@, qr/Invalid option 'Something'.*$thisfile/ );

#===================================================================
# check invalid method
#===================================================================
eval {
  $p = new Convert::Binary::C;
  $p->some_method( 1, 2, 3 );
};
ok( $@, qr/Invalid method some_method called.*$thisfile/ );

#===================================================================
# check configure returning the whole configuration
#===================================================================

%config = (
  'UnsignedChars' => 0,
  'ShortSize' => 2,
  'EnumType' => 'Integer',
  'EnumSize' => 4,
  'Include' => [ '/usr/include' ],
  'DoubleSize' => 4,
  'FloatSize' => 4,
  'HasCPPComments' => 1,
  'Alignment' => 1,
  'Define' => [ 'DEBUGGING', 'FOO=123' ],
  'HasC99Keywords' => 1,
  'HasMacroVAARGS' => 1,
  'LongSize' => 4,
  'HasVOID' => 1,
  'Warnings' => 0,
  'ByteOrder' => 'LittleEndian',
  'Assert' => [],
  'IntSize' => 4,
  'PointerSize' => 4,
  'LongLongSize' => 8,
  'LongDoubleSize' => 12
);

$C99 or delete @config{qw(HasCPPComments HasMacroVAARGS HasC99Keywords)};

eval {
  $p = new Convert::Binary::C %config;
  $cfg = $p->configure;
};
ok( $@, '', "failed to retrieve configuration" );

compare_config( \%config, $cfg );

#===================================================================
# check option chaining
#===================================================================

%newcfg = (
  'UnsignedChars' => 1,
  'ShortSize' => 4,
  'EnumType' => 'Both',
  'EnumSize' => 0,
  'Include' => [ '/usr/local/include', '/usr/include', '/include' ],
  'DoubleSize' => 8,
  'FloatSize' => 8,
  'HasCPPComments' => 1,
  'Alignment' => 2,
  'Define' => [ 'DEBUGGING', 'FOO=123', 'BAR=456' ],
  'HasC99Keywords' => 1,
  'HasMacroVAARGS' => 1,
  'LongSize' => 4,
  'HasVOID' => 0,
  'Warnings' => 1,
  'ByteOrder' => 'BigEndian',
  'Assert' => [],
  'IntSize' => 4,
  'PointerSize' => 2,
  'LongLongSize' => 8,
  'LongDoubleSize' => 12
);

$C99 or delete @newcfg{qw(HasCPPComments HasMacroVAARGS HasC99Keywords)};

@warn = ();

eval {
  local $SIG{__WARN__} = sub { push @warn, shift };

  $p = new Convert::Binary::C %config;
  
  $p->UnsignedChars( 1 )->configure( ShortSize => 4, EnumType => 'Both', EnumSize => 0 )
    ->Include( ['/usr/local/include'] )->DoubleSize( 8 );

  $p->FloatSize( 8 )->Include( qw( /usr/include /include ) )->HasVOID( 0 )
    ->Alignment( 2 )->Define( qw( BAR=456 ) )->configure( ByteOrder => 'BigEndian' );

  $p->configure( PointerSize => 2 )->Warnings( 1 );

  $cfg = $p->configure;
};
ok( $@, '', "failed to configure object" );

if( @warn ) { print "# issued warnings:\n", map "#   $_", @warn }
ok( scalar @warn, 0, "invalid number of warnings issued" );

compare_config( \%newcfg, $cfg );

