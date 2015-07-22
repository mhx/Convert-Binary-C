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
# $Date: 2003/08/18 10:19:20 +0100 $
# $Revision: 8 $
# $Snapshot: /Convert-Binary-C/0.45 $
# $Source: /ctlib/t_config.pl $
#
################################################################################
#
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Devel::Tokenizer::C;

@options = qw(
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

@sourcify = qw(
  Context
);

$file = shift;

if( $file =~ /t_config/ ) {
  @OPT  = @options;
  $PRE  = 'OPTION';
  $NAME = 'ConfigOption';
}
elsif( $file =~ /t_sourcify/ ) {
  @OPT  = @sourcify;
  $PRE  = 'SOURCIFY_OPTION';
  $NAME = 'SourcifyConfigOption';
}

$enums  = join "\n", map "  ${PRE}_$_,", @OPT;
$switch = Devel::Tokenizer::C->new( TokenFunc => sub { "return ${PRE}_$_[0];\n" },
                                    TokenString => 'option' )
                             ->add_tokens( @OPT )->generate;

open OUT, ">$file" or die $!;
print OUT <<END;
typedef enum {
$enums
  INVALID_$PRE
} $NAME;

static $NAME Get$NAME( const char *option )
{
$switch
unknown:
  return INVALID_$PRE;
}
END
close OUT;

