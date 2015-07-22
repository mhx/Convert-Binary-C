################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/04/18 22:33:25 +0100 $
# $Revision: 34 $
# $Snapshot: /Convert-Binary-C/0.40 $
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
  ($Config{use5005threads} || $Config{useithreads}) ? (
    threads => {
                 enabled => 1,
                 e_flags => [qw( CBC_THREAD_SAFE )],
                 d_flags => [qw()],
               },
  ) : (),
  '$format-check' => {
               enabled => 0,
               e_flags => [qw( CTYPE_FORMAT_CHECK UTIL_FORMAT_CHECK )],
               d_flags => [qw()],
             },
  '$mem-check' => {
               enabled => 0,
               e_flags => [qw( MEM_DEBUG )],
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

%TOKENIZER = (
  'ctlib/t_parser.pl' => ['ctlib/t_parser.c',
                          'ctlib/t_keywords.c',
			  'ctlib/t_ckeytok.c',
			  'ctlib/t_basic.c',
			 ],
  'ctlib/t_pragma.pl' =>  'ctlib/t_pragma.c',
  'ctlib/t_config.pl' =>  'ctlib/t_config.c',
);

%GENERATE = (
  %EXAMPLES,
  'ctlib/arch.pl' => 'ctlib/arch.h',
);

push @REALCLEAN, map { ref $_ ? @$_ : $_ } values %GENERATE;

%GENERATE = (
  %GENERATE,
  %TOKENIZER,
);

# Extract features/optimizations from the commandline arguments

@ARGV = map {
  my $myopt = 0;
  if( my($what, $feat) = /^(en|dis)able-(\S+)$/ ) {
    exists $FEATURES{$feat} or $feat = '$'.$feat;
    exists $FEATURES{$feat}
      or die "Invalid feature '$2'. Use one of [ @{[grep !/^\$/, keys %FEATURES]} ].\n";
    $FEATURES{$feat}{enabled} = $what eq 'en';
    $myopt = 1;
  }
  elsif( /^help$/ ) {
    die <<ENDUSAGE;

USAGE: $^X Makefile.PL enable-feature disable-feature

  Available Features: @{[keys %FEATURES]}

ENDUSAGE
  }
  $myopt ? () : $_
} @ARGV;

if( $Config{usemymalloc} eq 'y' and $FEATURES{threads}{enabled} ) {
  die <<ENDMSG;
-->
--> !!!!!!!!!!!!!   ------------------------------------------
--> !! S T O P !!    Unsupported Perl configuration detected!
--> !!!!!!!!!!!!!   ------------------------------------------
-->
-->   You're using multithreaded Perl binary that was configured
-->   with -Dusemymalloc=y. This configuration is very dangerous
-->   when using XS modules. Convert::Binary::C will work as long
-->   as you're not actually using threads, but there's a 100%
-->   chance that it will fail if you're using threads. Either
-->   disable threads in your binary or don't use Perl's malloc.
-->
-->   Huh? Don't understand anything of the above? Don't plan to
-->   use threads? Ok, just run
-->
-->     $^X Makefile.PL disable-threads
-->
-->   and build the module as usual.
-->
ENDMSG
}

WriteMakefile(
  'NAME'            => $MODULE,
  'VERSION_FROM'    => 'lib/Convert/Binary/C.pm',
  'ABSTRACT'        => 'Binary Data Conversion using C Types',
  'AUTHOR'          => 'Marcus Holland-Moritz <mhx@cpan.org>',
  'MYEXTLIB'        => 'libctype$(LIB_EXT)',
  'INC'             => join( ' ', map { "-I$_" } @INC_PATH ),
  'EXE_FILES'       => ['bin/ccconfig'],
  'PL_FILES'        => \%GENERATE,
  'CONFIGURE'       => \&configure,
  'clean'           => { FILES => "\$(MYEXTLIB_OBJ)" },
  'realclean'       => { FILES => "@REALCLEAN" },
);

#############################################################################

sub configure {

  # Configure and print information about features

  for( keys %FEATURES ) {
    my $f = $FEATURES{$_};
    $f->{enabled} and print /^\$/ ? "DEVELOPMENT-ONLY feature '$_' selected.\n"
                                  : "Building with feature '$_'.\n";
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
	\$(RANLIB) \$(MYEXTLIB)
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
      my($inc,$base) = /^\s*#\s*include\s*"([^"]+\.\w+)"/ or next;
      for my $path ( @inc_path ) {
        if( -e "$path$inc" ) {
          push @incs, $File::Find::dir . "/$path" . $inc;
        }
      }
      for my $gen ( keys %GENERATE ) {
        push @incs, grep /\E$inc/, ( ref $GENERATE{$gen} ? @{$GENERATE{$gen}} : $GENERATE{$gen} );
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
