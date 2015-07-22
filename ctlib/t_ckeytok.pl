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
# $Date: 2003/01/01 11:29:55 +0000 $
# $Revision: 2 $
# $Snapshot: /Convert-Binary-C/0.07 $
# $Source: /ctlib/t_ckeytok.pl $
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

$t = new Tokenizer tokfnc => \&tok_code, tokstr => 'name';

# keywords only in C99
@C99 = qw(
  inline
  restrict
);

# add all tokens except C99
$t->addtokens( '', qw(
  auto
  break
  case char continue const
  default do double
  else enum extern
  float for
  goto
  if int
  long
  register return
  sizeof struct switch short signed static
  typedef
  union unsigned
  void volatile
  while
), @ndis );

# add C99 keywords
$t->addtokens( 'ANSIC99_EXTENSIONS', @C99 );

open OUT, ">$ARGV[0]" or die $!;
print OUT $t->makeswitch;
close OUT;

sub tok_code {
  my $token = shift;
  return <<END
static const CKeywordToken ckt = { \U$token\E_TOK, "$token" };
return &ckt;
END
};
