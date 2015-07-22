################################################################################
#
# PROGRAM: ppdir.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for C preprocessor directives
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2008/04/15 14:37:43 +0100 $
# $Revision: 4 $
# $Source: /ucpp/ppdir.pl $
#
################################################################################
#
# Copyright (c) 2004-2008 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Devel::Tokenizer::C;
use strict;

my @PP = qw(
  define
  undef
  if
  ifdef
  ifndef
  else
  elif
  endif
  include
  include_next
  pragma
  error
  line
  assert
  unassert
  ident
);

my $file = shift;
my $enums  = join "\n", map "  PPDIR_\U$_\E,", @PP;
my $switch = Devel::Tokenizer::C->new(TokenFunc => sub { "return PPDIR_\U$_[0]\E;\n" },
                                      TokenString => 'ppdir')
                                ->add_tokens(@PP)->generate;

open OUT, ">$file" or die $!;

print OUT <<END;
static enum {
$enums
  PPDIR_UNKNOWN
}
scan_pp_directive(const char *ppdir)
{
$switch
unknown:
  return PPDIR_UNKNOWN;
}
END

close OUT;

