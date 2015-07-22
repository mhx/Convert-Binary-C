################################################################################
#
# PROGRAM: t_parser.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for C parser
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/04/15 22:26:46 +0100 $
# $Revision: 1 $
# $Snapshot: /Convert-Binary-C/0.05 $
# $Source: /ctlib/t_parser.pl $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use lib 'ctlib';
use Tokenizer;

$t = new Tokenizer tokfnc => \&tok_code;

@C99 = qw(
  inline
  restrict
);

$t->addtokens( '', qw(
  auto
  break
  case char const continue
  default do double
  else enum extern
  float for
  goto
  if int
  long
  register return
  short signed sizeof static struct switch
  typedef
  union unsigned
  void volatile
  while
));

# new keywords in 1999 ANSI C

$t->addtokens( 'ANSIC99_EXTENSIONS', @C99 );

open OUT, ">".shift or die $!;
print OUT $t->makeswitch;
close OUT;

sub tok_code {
  my $token = shift;
  if( $token eq 'void' ) {
    return "if( pState->pCPC->flags & HAS_VOID_KEYWORD )\n"
         . "  return \U$token\E_TOK;\n";
  }
  elsif( grep { $_ eq $token } @C99 ) {
    return "if( pState->pCPC->flags & HAS_C99_KEYWORDS )\n"
         . "  return \U$token\E_TOK;\n";
  }
  else {
    return "return \U$token\E_TOK;\n";
  }
};
