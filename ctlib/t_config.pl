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
# $Date: 2003/01/23 18:43:50 +0000 $
# $Revision: 5 $
# $Snapshot: /Convert-Binary-C/0.11 $
# $Source: /ctlib/t_config.pl $
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

@OPT = qw(
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
  KeywordMap
  ByteOrder
  EnumType
  HasCPPComments
  HasMacroVAARGS
);

$enums  = join "\n", map "  OPTION_$_,", @OPT;
$switch = Tokenizer->new( tokfnc => \&tok_code, tokstr => 'option' )
                   ->addtokens( '', @OPT )->makeswitch;

open OUT, ">$ARGV[0]" or die $!;
print OUT <<END;
typedef enum {
$enums
  INVALID_OPTION
} ConfigOption;

static ConfigOption GetConfigOption( const char *option )
{
$switch
unknown:
  return INVALID_OPTION;
}
END
close OUT;

sub tok_code {
  my $token = shift;
  return "return OPTION_$token;\n";
};
