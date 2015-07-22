################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/01/09 07:56:04 +0000 $
# $Revision: 28 $
# $Snapshot: /Convert-Binary-C/0.07 $
# $Source: /Makefile.PL $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
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

# Where to look for includes

@INC_PATH = qw(
  ctlib
);

# All the object files that are linked with the extension

@MYEXTOBJS = qw(
  ctlib/byteorder
  ctlib/cpperr
  ctlib/ctdebug
  ctlib/ctparse
  ctlib/cttype
  ctlib/fileinfo
  ctlib/parser
  ctlib/pragma
  ctlib/util/hash
  ctlib/util/list
  ctlib/util/memalloc
  ctlib/ucpp/assert
  ctlib/ucpp/cpp
  ctlib/ucpp/eval
  ctlib/ucpp/nhash
  ctlib/ucpp/lexer
  ctlib/ucpp/macro
  ctlib/ucpp/mem
);

# Files additionally to be removed on 'make realclean'

@REALCLEAN = qw(
  ctlib/parser.output
  ctlib/pragma.output
  t/debug.out
);

# add MEM_DEBUG to @DEFINE to check for ucpp memory leaks

@DEFINE = qw(
  ABORT_IF_NO_MEM
  UCPP_CONFIG
);

# On AIX systems, this should be defined for ucpp
$^O eq 'aix' and push @DEFINE, qw( POSIX_JMP );

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
  'ctlib/arch.pl'       => 'ctlib/arch.h',
  'ctlib/t_ckeytok.pl'  => 'ctlib/t_ckeytok.c',
  'ctlib/t_keywords.pl' => 'ctlib/t_keywords.c',
  'ctlib/t_parser.pl'   => 'ctlib/t_parser.c',
  'ctlib/t_pragma.pl'   => 'ctlib/t_pragma.c',
  'ctlib/t_config.pl'   => 'ctlib/t_config.c',
);

push @REALCLEAN, values %GENERATE;

# Extract features/optimizations from the commandline arguments

@ARGV = map {
  my $myopt = 0;
  if( /^(en|dis)able-(\w+)$/ ) {
    exists $FEATURES{$2} or die "Invalid feature '$2'. Use one of [ @{[keys %FEATURES]} ].\n";
    $FEATURES{$2}{enabled} = $1 eq 'en';
    $myopt = 1;
  }
  elsif( /^help$/ ) {
    die <<ENDUSAGE;

USAGE: perl Makefile.PL enable-feature disable-feature

  Available Features: @{[keys %FEATURES]}

ENDUSAGE
  }
  $myopt ? () : $_
} @ARGV;

unless( $FEATURES{c99}{enabled} ) {
  print STDERR <<ENDWARN
!!!
!!!  The 'C99' feature is deprecated and
!!!  will be removed in the next release.
!!!
ENDWARN
}

WriteMakefile(
  'NAME'            => $MODULE,
  'VERSION'         => do { my @r = '$Snapshot: /Convert-Binary-C/0.07 $'
                                    =~ /(\d+\.\d+(?:_\d+)?)/;
                            @r ? $r[0] : '9.99' },
  'ABSTRACT'        => 'Binary Data Conversion using C Types',
  'AUTHOR'          => 'Marcus Holland-Moritz <mhx@cpan.org>',
  'MYEXTLIB'        => 'libctype$(LIB_EXT)',
  'INC'             => join( ' ', map { "-I$_" } @INC_PATH ),
  'EXE_FILES'       => [
                         'bin/ccconfig'
                       ],
  'PL_FILES'        => { %GENERATE },
  'CONFIGURE'       => \&configure,
  'clean'           => { FILES => "\$(MYEXTLIB_OBJ)" },
  'realclean'       => { FILES => "@REALCLEAN" },
);

#############################################################################

sub configure {

  # Configure and print information about features

  for( keys %FEATURES ) {
    my $f = $FEATURES{$_};
    $f->{enabled} and print "Building with feature '$_'.\n";
    push @DEFINE, @{$f->{enabled} ? $f->{e_flags} : $f->{d_flags} };
  }
  
  {
    'DEFINE' => join(' ', map("-D$_", @DEFINE)),
    'depend' => { find_depend( @INC_PATH ) },
  }
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

sub MY::installbin {
  package MY;
  my $ibin = shift->SUPER::installbin(@_);
  my @ex = values %::EXAMPLES;
  $ibin =~ s!^pure_all\s*:+\s*!$&@ex !m;
  $ibin
}

# The following routines will extract the include dependencies
# from the source files.

sub find_depend {
  my @inc_path = ('.', @_);
  my(%depend, %d);

  printf "Finding dependencies...\n";

  for( @inc_path ) {
    /\/$/ or $_ .= '/';
  }

  File::Find::find( sub {
    /\.(?:xs|[chy])$/ or return;
    $File::Find::dir =~ /^\.[\/\\]t[\/\\]/ and return; # exclude test directory
    my @incs;
    open FILE, $_ or die $!;
    while( <FILE> ) {
      /^\s*#\s*include\s*"(([^"]+)\.\w+)"/ or next;
      for my $path ( @inc_path ) {
        if( -e "$path$1" or -e "$path$2.pl" ) {
          push @incs, $File::Find::dir . "/$path" . $1;
        }
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
