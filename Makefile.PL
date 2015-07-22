#!/usr/bin/perl
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/10/27 17:38:52 +0100 $
# $Revision: 80 $
# $Source: /Makefile.PL $
#
################################################################################
# 
# Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

# Check which version of perl the user is running,
# and emit some warnings when appropriate.

BEGIN {
  if ($] < 5.006) {
    print STDERR <<ENDWARN;

--> WARNING: The version of perl you're using ($]) is very old.
-->
-->   Convert::Binary::C is intended to build cleanly on
-->   perl versions >= 5.6.0. However, there are some hacks
-->   to make the code compatible with older versions.
-->
ENDWARN
    if ($] < 5.004) {
      print STDERR "-->   But the module will not build with perl < 5.004.\n\n";
      exit;
    }
    elsif ($] < 5.005) {
      print STDERR "-->   Chances are quite good that the module will\n",
                   "-->   build successfully, but you won't be able to\n",
                   "-->   run the test suite, as it uses features not\n",
                   "-->   available in perl < 5.005.\n";
    }
    else {
      print STDERR "-->   Chances are quite good that the module will\n",
                   "-->   build and test successfully.\n";
    }
    print STDERR <<ENDWARN;
-->
-->   You can try to build the module with this version of
-->   perl, but you should rather update your perl installation.

ENDWARN
  }
}

# Use some standard modules

use ExtUtils::MakeMaker;
use File::Find;
use Cwd;
use Config;

$MODULE = 'Convert::Binary::C';

# We need bison only when the source code is modified
# Actually, we need a recent version of bison ( >= 1.31 ),
# but this isn't checked here.

$BISON = $Config{bison} || 'bison';

# Where to look for includes

@INC_PATH = qw(
  .
);

# All object files (without extension)

@OBJECT = qw(
  cbc/basic
  cbc/hook
  cbc/idl
  cbc/init
  cbc/member
  cbc/object
  cbc/option
  cbc/pack
  cbc/sourcify
  cbc/tag
  cbc/type
  cbc/typeinfo
  cbc/util

  ctlib/bitfields
  ctlib/byteorder
  ctlib/cterror
  ctlib/ctparse
  ctlib/cttags
  ctlib/cttype
  ctlib/fileinfo
  ctlib/layout
  ctlib/parser
  ctlib/pragma

  ucpp/assert
  ucpp/cpp
  ucpp/eval
  ucpp/nhash
  ucpp/lexer
  ucpp/macro
  ucpp/mem

  util/hash
  util/list
  util/memalloc
);

@DBGOBJ = qw(
  cbc/debug
  ctlib/ctdebug
);

unshift @OBJECT, $MODULE =~ /([^:]+)$/;

# Files additionally to be removed on 'make realclean'

@REALCLEAN = qw(
  ctlib/parser.output
  ctlib/pragma.output
  t/debug.out
);

@CLEAN = qw(
  $(OBJECT)
  t/*.vgo
  t/cache.cbc
);

@DEFINE = qw(
  UCPP_CONFIG
  UCPP_REENTRANT
  UTIL_HAVE_CONFIG_H
);

# On AIX systems, this should be defined for ucpp
$^O eq 'aix' and push @DEFINE, qw( POSIX_JMP );

# Supported features, and flags to set when (e)nabled or (d)isabled

%FEATURES = (
  debug   => {
               enabled => $Config{ccflags} =~ /-DDEBUGGING\b/ ? 1 : 0,
               e_flags => [qw( CBC_DEBUGGING CTLIB_DEBUGGING DEBUG_MEMALLOC DEBUG_HASH YYDEBUG=1 )],
               d_flags => [qw( NDEBUG )],
             },
  ieeefp  => {
               enabled => undef,
               e_flags => [qw( CBC_HAVE_IEEE_FP )],
               d_flags => [qw()],
             },
  ($Config{usethreads} || $Config{use5005threads} || $Config{useithreads}) ? (
    threads => {
                 enabled => 1,
                 e_flags => [qw( CBC_THREAD_SAFE )],
                 d_flags => [qw()],
               }
  ) : (),
  $Config{gccversion} ? (
  '$format-check' => {
               enabled => 0,
               e_flags => [qw( CTLIB_FORMAT_CHECK UTIL_FORMAT_CHECK )],
               d_flags => [qw()],
             },
  '$coverage' => {
               enabled => 0,
               e_flags => [qw()],
               d_flags => [qw()],
             }
  ) : (),
  '$mem-check' => {
               enabled => 0,
               e_flags => [qw( MEM_DEBUG DEBUG_MEMALLOC TRACE_MEMALLOC AUTOPURGE_MEMALLOC )],
               d_flags => [qw()],
             },
);

# Automatically generated files

%EXAMPLES = (
  map {
    my $x=$_;
    s/^bin/examples/;
    s/PL$/pl/;
    ($x => $_)
  } glob "bin/*.PL"
);

%GENERATE = (
  %EXAMPLES,
  'ctlib/arch.pl' => 'ctlib/arch.h',
);

push @REALCLEAN, map { ref $_ ? @$_ : $_ } values %GENERATE;

# Extract features/optimizations from the commandline arguments

@ARGV = map {
  my $myopt = 0;
  if( my($what, $feat) = /^(en|dis)able-(\S+)$/ ) {
    exists $FEATURES{$feat} or $feat = '$'.$feat;
    exists $FEATURES{$feat}
      or die "Invalid feature '$2'. Use one of [ @{[keys %FEATURES]} ].\n";
    $FEATURES{$feat}{enabled} = $what eq 'en';
    $myopt = 1;
  }
  elsif( /^help$/ ) {
    die <<ENDUSAGE;

USAGE: $^X Makefile.PL enable-feature disable-feature

  Available Features: @{[sort grep !/^\$/, keys %FEATURES]}
    development only: @{[sort grep /^\$/, keys %FEATURES]}

ENDUSAGE
  }
  $myopt ? () : $_
} @ARGV;

if ($FEATURES{debug}{enabled}) {
  push @OBJECT, @DBGOBJ;
}

if ($FEATURES{'$coverage'}{enabled}) {
  push @CLEAN, qw( *.gcov *.gcda *.gcno *.da *.bb *.bbg );
}

# run the IEEE check anyway
@ieee_fail = &check_ieee_fp;

if (defined $FEATURES{'ieeefp'}{enabled}) {
  if ($FEATURES{'ieeefp'}{enabled} and @ieee_fail) {
    print <<ENDMSG;
-----------------------------------------------------------------------
  My tests indicate that your machine does not store floating point
  values in IEEE format. However, you explicitly turned IEEE floating
  point support on. So I will trust you. You have been warned!
-----------------------------------------------------------------------
ENDMSG
  }
}
else {
  $FEATURES{'ieeefp'}{enabled} = !@ieee_fail;
  if (@ieee_fail) {
    print <<ENDMSG;

--> !!!!!!!!!!   --------------------------------------------------
--> !! WHOA !!    You did not pass the IEEE floating point check!
--> !!!!!!!!!!   --------------------------------------------------
--> 
--> This means I've done a couple of very simple tests to see if your machine
--> is storing floating point numbers in IEEE format or not. From the results
--> I concluded that your machine does _NOT_ store floating point values in
--> IEEE format.
--> 
--> These are the values for which the IEEE test failed:
--> 
--> value            format   expected                  got
--> ---------------------------------------------------------------------------
ENDMSG

  my $hex = sub { join ' ', map { sprintf "%02X", $_ } unpack "C*", $_[0] };

  for my $t (@ieee_fail) {
    printf "--> %-15s  %-7s  %-24s  %-24s\n", $t->{value}, $t->{check},
           $hex->( $t->{expected} ), $hex->( $t->{got} );
  }

  print <<ENDMSG;
--> ---------------------------------------------------------------------------
--> 
--> If you're aware of the fact that your machine does not support IEEE
--> floating point, please ignore the junk above. You can suppress this
--> message by explicitly disabling the 'ieeefp' feature:
--> 
-->   $^X Makefile.PL disable-ieeefp
--> 
--> If you're sure that your machine has IEEE floating point support and the
--> tests are just complete crap, you can force IEEE support by explicitly
--> enabling the 'ieeefp' feature:
--> 
-->   $^X Makefile.PL enable-ieeefp

ENDMSG
  }
}

WriteMakefile(
  'NAME'         => $MODULE,
  'VERSION_FROM' => 'lib/Convert/Binary/C.pm',
  'ABSTRACT'     => 'Binary Data Conversion using C Types',
  'AUTHOR'       => 'Marcus Holland-Moritz <mhx@cpan.org>',
  'OBJECT'       => join( ' ', map { "$_\$(OBJ_EXT)" } sort @OBJECT ),
  'INC'          => join( ' ', map { "-I$_" } @INC_PATH ),
  'EXE_FILES'    => ['bin/ccconfig'],
  'PL_FILES'     => \%GENERATE,
  'CONFIGURE'    => \&configure,
  'clean'        => { FILES => "@CLEAN" },
  'realclean'    => { FILES => "@REALCLEAN" },
);

#############################################################################

sub configure
{
  # Configure and print information about features

  for( keys %FEATURES ) {
    my $f = $FEATURES{$_};
    $f->{enabled} and print /^\$/ ? "DEVELOPMENT-ONLY feature '$_' selected\n"
                                  : "Building with feature '$_'\n";
    push @DEFINE, @{$f->{enabled} ? $f->{e_flags} : $f->{d_flags} };
  }
 
  my $config = {
    'DEFINE' => join(' ', map("-D$_", @DEFINE)),
    'depend' => { find_depend( @INC_PATH ) },
  };

  if ($FEATURES{'$coverage'}{enabled}) {
    $config->{'OPTIMIZE'} = '-g -fprofile-arcs -ftest-coverage';
    if ($Config{gccversion} =~ /(\d+)\.(\d+)\.(\d+)/ && ($1+1e-3*$2+1e-6*$3) >= 3.004) {
      $config->{'LDLOADLIBS'} = '-lgcov';  # not a valid parameter, but works...
    }
  }

  if (eval $ExtUtils::MakeMaker::VERSION >= 6.30_01) {
    print "Setting license tag...\n";
    $config->{'LICENSE'} = 'perl';
    $config->{'EXTRA_META'} = <<'META';
no_index:
    dir:
        - support
META
  }

  $config;
}

sub MY::c_o
{
  package MY;
  my $c_o = shift->SUPER::c_o(@_);
  $c_o =~ s/^\s+\$\(CCCMD\).*$/$&\n\t\$(MV) \$(\@F) t_object.tmp\n\t\$(MV) t_object.tmp \$\@/mg;
  $c_o;
}

sub MY::constants
{
  package MY;
  shift->SUPER::constants(@_).<<END

# Yacc to generate parser
YACC = $::BISON

# Options for valgrind
VALGRIND_OPTIONS = --tool=memcheck \\
		   --leak-check=yes \\
		   --leak-resolution=high \\
		   --show-reachable=yes \\
		   --num-callers=50
END
}

sub MY::postamble
{
  package MY;

  my @spec = (
    {
      cmd => '$(YACC) -v -p c_ -o {dst} {src}',
      src => 'ctlib/parser.y',
      dst => ['ctlib/parser.c'],
    },
    {
      cmd => '$(YACC) -v -p pragma_ -o {dst} {src}',
      src => 'ctlib/pragma.y',
      dst => ['ctlib/pragma.c'],
    },
    {
      cmd => '$(PERL) {src} {dst}',
      src => 'token/parser.pl',
      dst => ['token/t_parser.c',
              'token/t_keywords.c',
              'token/t_ckeytok.c',
              'token/t_basic.c'],
    },
    {
      cmd => '$(PERL) {src} {dst}',
      src => 'token/pragma.pl',
      dst => ['token/t_pragma.c'],
    },
    {
      cmd => '$(PERL) {src} {dst}',
      src => 'token/config.pl',
      dst => ['token/t_config.c',
              'token/t_sourcify.c'],
    },
    {
      cmd => '$(PERL) {src} {dst}',
      src => 'token/tag.pl',
      dst => ['token/t_tag.h',
              'token/t_tag.c'],
    },
    {
      cmd => '$(PERL) {src} {dst}',
      src => 'token/hook.pl',
      dst => ['token/t_hookid.h',
              'token/t_hookid.c'],
    },
    {
      cmd => '$(PERL) {src} {dst}',
      src => 'token/blproperty.pl',
      dst => ['token/t_blproperty.h',
              'token/t_blproperty.c'],
    },
  );

  my(@gen, @old_dst, @old_src, @missing);

  for my $s (@spec) {
    for my $dst (@{$s->{dst}}) {
      my $cmd = $s->{cmd};
      $cmd =~ s/\{dst\}/$dst/g;
      $cmd =~ s/\{(\w+)\}/$s->{$1}/g;
      push @gen, $cmd;
      if (-f $dst) {
        if (-M $s->{src} < -M $dst) {
          push @old_dst, $dst;
          push @old_src, $s->{src};
        }
      }
      else {
        push @missing, $dst;
      }
    }
  }

  @old_src = do { my %s; grep !$s{$_}++, @old_src };

  my $make = $Config{'make'} || 'make';

  if (@missing) {
    print STDERR <<ENDWARN;

--> WARNING: The following autogenerated files are missing:
--> 
-->   @missing
--> 
--> Please run:
--> 
-->   $make regen
--> 
--> If you just extracted the source distribution and did
--> not modify or delete any files, something is seriously
--> wrong.

ENDWARN
  }
  elsif (@old_dst) {
    print STDERR <<ENDWARN;

--> WARNING: The following generated files are out of date with
--> respect to their source files:
--> 
-->   @old_dst
--> 
--> Either you've used a nasty program to extract the files in
--> this distribution, or you've modified these source files
--> 
-->   @old_src
--> 
--> intentionally and forgot to run
--> 
-->   $make regen
--> 
--> afterwards.
--> 
--> If you don't understand anything of the above, you're most
--> probably safe if you just run
--> 
-->   $make
--> 
--> now.

ENDWARN
  }

  my $postamble = shift->SUPER::postamble(@_);
  $postamble .= "\nregen:\n\t" . join("\n\t", @gen) . "\n";

  $postamble .= <<END;

ctags:
	\@ctags -f tags --totals=yes */*.[chy]
END

  if( $::Config{ccflags} =~ /-DDEBUGGING\b/ ) {
    my $sym = $::MODULE;
    $sym =~ s/::/.*/g;
    $postamble .= <<END;

valgrind: pure_all
	\@export PERL_DESTRUCT_LEVEL=2; \\
	echo PERL_DESTRUCT_LEVEL=\$\$PERL_DESTRUCT_LEVEL; \\
	for file in t/*.t; do \\
	  echo checking \$\$file with valgrind...; \\
	  valgrind \$(VALGRIND_OPTIONS) \$(PERL) -Mblib \$\$file >\$\$file.vgo 2>&1; \\
	  grep "==.*==.*$sym" \$\$file.vgo; \\
	done
END
  }
  else {
    $postamble .= <<END;

valgrind:
	\@echo Sorry, I need a debugging version of perl for valgrind.
END
  }

  $::FEATURES{'$coverage'}{enabled} and $postamble .= <<END;

coverage:
	\@for file in *.bb *.gcda; do gcov \$\$file; done
END

  $postamble;
}

sub MY::test
{
  package MY;
  my $test = shift->SUPER::test(@_);
  $::FEATURES{debug}{enabled} and
      $test =~ s!^test\s*:.*!$&$/\t\@\$(RM_F) t/debug.out!m;
  $test
}

sub MY::installbin
{
  package MY;
  my $ibin = shift->SUPER::installbin(@_);
  my @ex = values %::EXAMPLES;
  $ibin =~ s!^pure_all\s*:+\s*!$&@ex !m;
  $ibin
}

sub MY::perldepend
{
  package MY;
  my $dep = shift->SUPER::perldepend(@_);
  my @deps;

  open FILE, "C.xs" or die "C.xs: $!";
  while (<FILE>) {
    /^INCLUDE:\s*(\S+)/ or next;
    push @deps, $1;
  }
  close FILE;

  $dep =~ s/^(C\.c\s*:)/$1 @deps /m;

  $dep
}

# The following routines will extract the include dependencies
# from the source files.

sub find_depend
{
  my @inc_path = ('.', @_);
  my(%depend, %d);
  my $cwd = getcwd;

  printf "Finding dependencies...\n";

  for (@inc_path) {
    /\/$/ or $_ .= '/';
  }

  File::Find::find(sub {
    /\.(?:(xs)|[chy])$/ or return;
    $File::Find::dir =~ /^\.[\/\\]t[\/\\]/ and return; # exclude test directory
    my @incs;
    open FILE, $_ or die "$_: $!";
    my $olddir = getcwd;
    chdir $cwd;
    while (<FILE>) {
      my($inc,$base) = /^\s*#\s*include\s*"([^"]+\.\w+)"/ or next;
      for my $path (@inc_path, "$File::Find::dir/") {
        if (-e "$path$inc") {
          push @incs, $path . $inc;
        }
      }
      for my $gen (keys %GENERATE) {
        push @incs, grep /\E$inc/, (ref $GENERATE{$gen} ? @{$GENERATE{$gen}} : $GENERATE{$gen});
      }
    }
    close FILE;
    chdir $olddir;
    return unless @incs;
    my $name = $File::Find::name;
    for (@incs, $name) {
      s/\.[\\\/]//;
      s/^\.\/|\/\.(?=\/)//g;
      s/[^\/]+\/\.\.\///g;
    }
    @{$depend{$name}}{@incs} = (1)x@incs;
  }, '.');

  for my $o (@OBJECT) {
    my $name = $o;

    for my $ext (qw( xs y c )) {
      -e "$name.$ext" and $name .= ".$ext" and last;
    }

    my %incs;
    rec_depend($name, \%depend, \%incs);
    $d{"$o\$(OBJ_EXT)"} = join ' ', sort keys %incs;
  }

  %d;
}

sub rec_depend
{
  my($f,$d,$i) = @_;
  my $h = $d->{$f};
  for (keys %$h) {
    exists $i->{$_} and next; $i->{$_} = 1;
    exists $d->{$_} and rec_depend($_, $d, $i);
  }
}

sub is_big_endian
{
  my $byteorder = $Config{byteorder}
               || unpack( "a*", pack "L", 0x34333231 );

  die "Native byte order ($byteorder) not supported!\n"
      if   $byteorder ne '1234'     and $byteorder ne '4321'
       and $byteorder ne '12345678' and $byteorder ne '87654321';

  $byteorder eq '4321' or $byteorder eq '87654321';
}

sub check_ieee_fp
{
  my @test = (
    {
      value  => '-1.0',
      double => pack( 'C*', 0xBF, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ),
      single => pack( 'C*', 0xBF, 0x80, 0x00, 0x00 ),
    },
    {
      value  => '0.0',
      double => pack( 'C*', 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ),
      single => pack( 'C*', 0x00, 0x00, 0x00, 0x00 ),
    },
    {
      value  => '0.4',
      double => pack( 'C*', 0x3F, 0xD9, 0x99, 0x99, 0x99, 0x99, 0x99, 0x9A ),
      single => pack( 'C*', 0x3E, 0xCC, 0xCC, 0xCD ),
    },
    {
      value  => '1.0',
      double => pack( 'C*', 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ),
      single => pack( 'C*', 0x3F, 0x80, 0x00, 0x00 ),
    },
    {
      value  => '3.1415926535',
      double => pack( 'C*', 0x40, 0x09, 0x21, 0xFB, 0x54, 0x41, 0x17, 0x44 ),
      single => pack( 'C*', 0x40, 0x49, 0x0F, 0xDB ),
    },
    {
      value  => '1.220703125e-4',
      double => pack( 'C*', 0x3F, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ),
      single => pack( 'C*', 0x39, 0x00, 0x00, 0x00 ),
    },
  );

  my @fail;

  for my $t ( @test ) {
    my $s = pack 'f', $t->{value};
    my $d = pack 'd', $t->{value};
    unless( &is_big_endian ) { for( $s, $d ) { $_ = reverse $_ } }

    $s eq $t->{single} or push @fail,
        { value => $t->{value}, check => 'single', expected => $t->{single}, got => $s }; 

    $d eq $t->{double} or push @fail,
        { value => $t->{value}, check => 'double', expected => $t->{double}, got => $d }; 
  }

  return @fail;
}

