################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/08/30 11:03:00 +0100 $
# $Revision: 10 $
# $Snapshot: /Convert-Binary-C/0.01 $
# $Source: /Makefile.PL $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

# Check which version of perl the user is running,
# and emit some warnings when appropriate.

BEGIN {
  if( $] < 5.006 ) {
    print STDERR <<ENDWARN;

--> WARNING: The version of perl you're using ($]) is very old.
-->
-->   Convert::Binary::C is intended to build cleanly on
-->   perl versions >= 5.6.0. However, there are some hacks
-->   to make the code compatible with older versions.
-->
ENDWARN
    if( $] == 5.005_03 ) {
      print STDERR "-->   Although the module should build without problems,\n",
                   "-->   you should try to update your perl installation.\n\n";
    }
    else {
      if( $] < 5.005_03 ) {
        print STDERR "-->   Chances aren't very good that the module will\n",
                     "-->   build successfully.\n";
      }
      else {
        print STDERR "-->   Chances are quite good that the module will\n",
                     "-->   build successfully.\n";
      }
      print STDERR <<ENDWARN;
-->
-->   You can try to build the module with this version of
-->   perl, but you should rather update your perl installation.

ENDWARN
    }
  }
}

# Use some standard modules

use ExtUtils::MakeMaker;
use File::Find;
use Config;

$MODULE = 'Convert::Binary::C';

# We need bison only when the source code is modified
# Actually, we need a recent version of bison ( >= 1.31 ),
# but this isn't checked here.

$BISON = $Config{bison} || 'bison';

# All the object files that are linked with the extension

@MYEXTOBJS = qw(
  ctlib/cpperr
  ctlib/ctdebug
  ctlib/ctparse
  ctlib/ctype
  ctlib/parser
  ctlib/pragma
  ctlib/util/hash
  ctlib/util/list
  ctlib/util/memalloc
  ctlib/ucpp/assert
  ctlib/ucpp/cpp
  ctlib/ucpp/eval
  ctlib/ucpp/hash
  ctlib/ucpp/lexer
  ctlib/ucpp/macro
  ctlib/ucpp/mem
);

# Files additionally to be removed on 'make realclean'

@REALCLEAN = qw(
  ctlib/parser.output
  ctlib/pragma.output
  ctlib/t_parser.c
  ctlib/t_pragma.c
  ctlib/arch.h
);

# add MEM_DEBUG to @DEFINE to check for ucpp memory leaks

@DEFINE = qw(
  ABORT_IF_NO_MEM
  __STRICT_ANSI__
  UCPP_CONFIG
);

# Supported features, and flags to set when (e)nabled or (d)isabled

%FEATURES = (
  debug   => {
               enabled => $Config{ccflags} =~ /-DDEBUGGING\b/ ? 1 : 0,
               e_flags => [qw( CTYPE_DEBUGGING DEBUG_MEMALLOC DEBUG_HASH YYDEBUG=1 )],
               d_flags => [qw( NDEBUG )],
             },
  c99     => {
               enabled => 1,
               e_flags => [qw( ANSIC99_EXTENSIONS )],
               d_flags => [qw()],
             },
  ($Config{use5005threads} || $Config{useithreads}) ? (
    threads => {
                 enabled => 1,
                 e_flags => [qw( CBC_THREAD_SAFE )],
                 d_flags => [qw()],
               },
  ) : (),
);

# Supported optimizations, and routines to call

%OPTIMIZE = (
  'gcc'      => \&opt_gcc,
  'debug'    => \&opt_debug,
  $^O eq 'linux' ? (            # Intel's icc has to be installed
    'diag'     => \&opt_diag,
  ) : (),
);

# MakeMaker arguments

@MAKER = (
  'NAME'            => $MODULE,
  'VERSION_FROM'    => do { my $pm=$MODULE; $pm=~s!::!/!g; "lib/$pm.pm" },
  'MYEXTLIB'        => 'libctype$(LIB_EXT)',
  'INC'             => '-Ictlib',
  'PL_FILES'        => {
                         'ctlib/arch.pl'     => 'ctlib/arch.h',
                         'ctlib/t_parser.pl' => 'ctlib/t_parser.c',
                         'ctlib/t_pragma.pl' => 'ctlib/t_pragma.c',
                       },
  'clean'           => { FILES => "\$(MYEXTLIB_OBJ)" },
  'realclean'       => { FILES => "@REALCLEAN" },
  'depend'          => { find_depend() },
);

# Extract features/optimizations from the commandline arguments

@ARGV = map {
  my $myopt = 0;
  if( /^(en|dis)able-(\w+)$/ ) {
    exists $FEATURES{$2} or die "Invalid feature '$2'. Use one of [ @{[keys %FEATURES]} ].\n";
    $FEATURES{$2}{enabled} = $1 eq 'en';
    $myopt = 1;
  }
  elsif( /^optimize=(\w+)$/ ) {
    exists $OPTIMIZE{$1} or die "Invalid optimization '$1'. Use one of [ @{[keys %OPTIMIZE]} ].\n";
    $optimize = $1;
    $myopt = 1;
  }
  elsif( /^help$/ ) {
    die <<ENDUSAGE;

USAGE: perl Makefile.PL optimize=opt enable-feature disable-feature

  Available Features: @{[keys %FEATURES]}
Optimization Options: @{[keys %OPTIMIZE]}

ENDUSAGE
  }
  $myopt ? () : $_
} @ARGV;

# Configure and print information about features/optimizations

for( keys %FEATURES ) {
  my $f = $FEATURES{$_};
  $f->{enabled} and print "Building with feature '$_'\n";
  push @DEFINE, @{$f->{enabled} ? $f->{e_flags} : $f->{d_flags} };
}

if( defined $optimize ) {
  print "Optimizing for '$optimize'\n";
  $OPTIMIZE{$optimize}->( \@MAKER );
}

# HP-UX cc/acc compilers cannot access non-aligned data by default
if( $^O eq 'hpux' and $Config{cc} eq 'cc' || $Config{cc} eq 'aCC' ) {
  push @MAKER, ('CCFLAGS' => "$Config{ccflags} +u1");
}

# On AIX systems, this should be defined for ucpp
if( $^O eq 'aix' ) {
  push @DEFINE, qw( POSIX_JMP );
}

push @MAKER, ('DEFINE' => join ' ', map( "-D$_", @DEFINE));

WriteMakefile( @MAKER );

#############################################################################

sub opt_diag { # Use ICC diagnostics
  my $maker = shift;
  push @$maker, (
    macro => {
      'CC'         => 'icc',
      'LD'         => 'icc',
      'CCCDLFLAGS' => '-Kpic',
    },
    'CCFLAGS'    => '-wd187 -wd193 -wd279 -wd171 -wd810 -w2 -D_SYS_SELECT_H',
    'OPTIMIZE'   => '-g',
  );
}

sub opt_debug { # Debug-flag
  my $maker = shift;
  push @$maker, (
    'OPTIMIZE'   => '-g',
  );
}

sub opt_gcc { # Use GCC
  my $maker = shift;
  push @$maker, (
    'OPTIMIZE'   => '-O3',
  );
}

sub MY::c_o {
  package MY;
  my $c_o = shift->SUPER::c_o(@_);
  $c_o =~ s/^\s+\$\(CCCMD\).*$/$&\n\t\$(MV) \$(\@F) t_object.tmp\n\t\$(MV) t_object.tmp \$\@/mg;
  $c_o;
}

sub MY::constants {
  package MY;
  shift->SUPER::constants(@_).<<END

# Yacc to generate parser
YACC = $::BISON

# Object files for ctlib
MYEXTLIB_OBJ = @{[join "\$(OBJ_EXT) \\\n\t\t", @::MYEXTOBJS]}\$(OBJ_EXT)
END
}

sub MY::postamble {
  package MY;
  my $self = shift;
  my $linkext = $^O eq "MSWin32" ? '/OUT:$(MYEXTLIB)' : '$(AR_STATIC_ARGS) $(MYEXTLIB)';
  my($compile) = $self->SUPER::c_o(@_) =~ /^(\s+\$\(CCCMD\).*)\$\*\.c$/m;

  $self->SUPER::postamble(@_).<<END

ctlib/parser.c: ctlib/parser.y
	\$(YACC) -v -p c_ -o \$*.c \$*.y

ctlib/pragma.c: ctlib/pragma.y
	\$(YACC) -v -p pragma_ -o \$*.c \$*.y

\$(MYEXTLIB): \$(MYEXTLIB_OBJ)
	\$(AR) $linkext \$(MYEXTLIB_OBJ)
END
}

sub MY::test {
  package MY;
  my $test = shift->SUPER::test(@_);
  $::FEATURES{debug}{enabled} and
      $test =~ s!^test\s*:.*!$&$/\t\@\$(RM_F) t/debug.out!m;
  $test
}

# The following routines will extract the include dependencies
# from the source files.

sub find_depend {
  my(%depend, %d);

  File::Find::find( sub {
    /\.(?:xs|[chy])$/ or return;
    my @incs;
    open FILE, $_ or die $!;
    while( <FILE> ) {
      /^\s*#\s*include\s*"(([^"]+)\.\w+)"/ or next;
      if( -e $1 or -e "$2.pl" ) {
        push @incs, $File::Find::dir . '/' . $1;
      }
      elsif( -e "ctlib/$1" or -e "ctlib/$2.pl" ) {
        push @incs, $File::Find::dir . '/ctlib/' . $1;
      }
    }
    close FILE;
    return unless @incs;
    my $name = $File::Find::name;
    for( @incs, $name ) {
      s/\.[\\\/]//;
      s/^\.\/|\/\.(?=\/)//g;
      s/[^\/]+\/\.\.\///g;
    }
    @{$depend{$name}}{@incs} = (1)x@incs;
  }, '.' );

  for( @MYEXTOBJS, $MODULE =~ /([^:]+)$/ ) {
    my $name = $_;
    for( qw( xs y c ) ) {
      -e "$name.$_" and $name .= ".$_" and last;
    }
    my %incs;
    rec_depend( $name, \%depend, \%incs );
    $d{"$_\$(OBJ_EXT)"} = join ' ', keys %incs;
  }

  %d;
}

sub rec_depend {
  my($f,$d,$i) = @_;
  my $h = $d->{$f};
  for( keys %$h ) {
    exists $i->{$_} and next; $i->{$_} = 1;
    exists $d->{$_} and rec_depend( $_, $d, $i );
  }
}
