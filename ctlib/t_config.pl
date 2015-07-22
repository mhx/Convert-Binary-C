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
# $Date: 2003/01/01 11:29:55 +0000 $
# $Revision: 3 $
# $Snapshot: /Convert-Binary-C/0.07 $
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

$t = new Tokenizer tokfnc => \&tok_code, tokstr => 'option';

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
);

@C99 = qw(
  HasCPPComments
  HasMacroVAARGS
);

$t->addtokens( '', @OPT );
$t->addtokens( 'ANSIC99_EXTENSIONS', @C99 );

$enums     = join "\n", map "  OPTION_$_,", @OPT;
$enums_c99 = join "\n", map "  OPTION_$_,", @C99;
$switch    = $t->makeswitch;

open OUT, ">$ARGV[0]" or die $!;
print OUT <<END;
typedef enum {
$enums
#ifdef ANSIC99_EXTENSIONS
$enums_c99
#endif
  INVALID_OPTION
} ConfigOption;

ConfigOption GetConfigOption( const char *option )
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
