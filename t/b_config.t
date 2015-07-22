################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/06/20 17:46:42 +0100 $
# $Revision: 3 $
# $Snapshot: /Convert-Binary-C/0.01 $
# $Source: /t/b_config.t $
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
  plan tests => $C99 ? 1315 : 1144
}

ok( defined $C99 );

# passing references as options is not legal, so this is
# always checked for non-list options
@refs = (
  { in =>  [12], result => FAIL },
  { in =>  \123, result => FAIL },
  { in => {1,2}, result => FAIL },
);

ok( defined $C99 );

$thisfile = 'at.*config\.t';

sub check_config
{
  my $option = shift;
  my @warn;
  my $value;

  $SIG{__WARN__} = sub { push @warn, shift };

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

  $SIG{__WARN__} = 'DEFAULT';
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

  $SIG{__WARN__} = sub { push @warn, shift };

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

  $SIG{__WARN__} = 'DEFAULT';
}

@tests = (
  { in => -1,  result => FAIL    },
  { in =>  0,  result => SUCCEED },
  { in =>  1,  result => SUCCEED },
  { in =>  2,  result => SUCCEED },
  { in =>  3,  result => FAIL    },
  { in =>  4,  result => SUCCEED },
  { in =>  5,  result => FAIL    },
  @refs
);

check_config( $_, @tests ) for qw( PointerSize
                                   EnumSize
                                   IntSize
                                   ShortSize
                                   LongSize );

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
  @refs
);

check_config( $_, @tests ) for qw( FloatSize
                                   DoubleSize );
                                   
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

check_config( 'HashSize',
  { in => 'Tiny',    result => SUCCEED },
  { in => 'Small',   result => SUCCEED },
  { in => 'Normal',  result => SUCCEED },
  { in => 'Large',   result => SUCCEED },
  { in => 'Huge',    result => SUCCEED },
  { in => 'Medium',  result => FAIL    },
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
# check invalid configuration (4 test)
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
# check invalid option (1 test)
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
# check invalid method (1 test)
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
  'HashSize' => 'Normal',
  'LongSize' => 4,
  'HasVOID' => 1,
  'Warnings' => 0,
  'ByteOrder' => 'LittleEndian',
  'Assert' => [],
  'IntSize' => 4,
  'PointerSize' => 4
);

$C99 or delete @config{qw(HasCPPComments HasMacroVAARGS HasC99Keywords)};

eval {
  $p = new Convert::Binary::C %config;
  $cfg = $p->configure;
};
ok( $@, '', "failed to retrieve configuration" );
ok( scalar keys %config, scalar keys %$cfg, "differing options count" );
for( keys %config ) {
  if( ref $config{$_} ) {
    ok( "@{$config{$_}}", "@{$cfg->{$_}}", "option '$_' has different values" );
  }
  else {
    ok( $config{$_}, $cfg->{$_}, "option '$_' has different values" );
  }
}

