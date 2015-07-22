################################################################################
#
# PROGRAM: t_keywords.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for disabled keywords parser
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/12/11 14:02:20 +0000 $
# $Revision: 1 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /ctlib/t_keywords.pl $
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

$t = new Tokenizer tokfnc => \&tok_code, tokstr => 'str';

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
) );

$t->addtokens( 'ANSIC99_EXTENSIONS', qw(
  inline
  restrict
) );

open OUT, ">$ARGV[0]" or die $!;
print OUT $t->makeswitch;
close OUT;

sub tok_code {
  my $token = shift;
  return "keywords &= ~HAS_KEYWORD_\U$token\E;\n"
        ."goto success;\n";
};
