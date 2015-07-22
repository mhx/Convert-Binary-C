################################################################################
#
# PROGRAM: t_config.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for config options
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/12/11 14:01:43 +0000 $
# $Revision: 1 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /ctlib/t_config.pl $
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

$t = new Tokenizer tokfnc => \&tok_code, tokstr => 'option';

@C99 = qw(
  HasCPPComments
  HasMacroVAARGS
);

$t->addtokens( '', qw(
  UnsignedChars
  Warnings
  PointerSize
  EnumSize
  IntSize
  ShortSize
  LongSize
  LongLongSize
  FloatSize
  DoubleSize
  LongDoubleSize
  Alignment
  Include
  Define
  Assert
  DisabledKeywords
  ByteOrder
  EnumType
));

# options only with ANSI C99

$t->addtokens( 'ANSIC99_EXTENSIONS', @C99 );

open OUT, ">$ARGV[0]" or die $!;
print OUT $t->makeswitch;
close OUT;

sub tok_code {
  my $token = shift;
  return "return OPTION_$token;\n";
};
