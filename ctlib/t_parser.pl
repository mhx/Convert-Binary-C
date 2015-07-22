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
# $Date: 2003/01/01 11:29:56 +0000 $
# $Revision: 3 $
# $Snapshot: /Convert-Binary-C/0.07 $
# $Source: /ctlib/t_parser.pl $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

use lib 'ctlib';
use Tokenizer;

$t = new Tokenizer tokfnc => \&tok_code;

# keywords only in C99
@C99 = qw(
  inline
  restrict
);

# keywords that cannot be disabled
@ndis = qw(
  break
  case char continue
  default do
  else
  for
  goto
  if int
  return
  sizeof struct switch
  typedef
  union
  while
);

# put them in a hash
@NDIS{@ndis} = (1) x @ndis;

# add all tokens except C99
$t->addtokens( '', qw(
  auto
  const
  double
  enum extern
  float
  long
  register
  short signed static
  unsigned
  void volatile
), @ndis );

# add C99 keywords
$t->addtokens( 'ANSIC99_EXTENSIONS', @C99 );

open OUT, ">$ARGV[0]" or die $!;
print OUT $t->makeswitch;
close OUT;

sub tok_code {
  my $token = shift;
  if( exists $NDIS{$token} ) {
    return "return \U$token\E_TOK;\n";
  }
  else {
    return "if( pState->pCPC->keywords & HAS_KEYWORD_\U$token\E )\n"
         . "  return \U$token\E_TOK;\n";
  }
};
