################################################################################
#
# PROGRAM: config.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for config options
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/21 09:18:41 +0000 $
# $Revision: 18 $
# $Source: /token/config.pl $
#
################################################################################
#
# Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
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
  CharSize
  ShortSize
  LongSize
  LongLongSize
  FloatSize
  DoubleSize
  LongDoubleSize
  Alignment
  CompoundAlignment
  Include
  Define
  Assert
  DisabledKeywords
  KeywordMap
  ByteOrder
  EnumType
  HasCPPComments
  HasMacroVAARGS
  OrderMembers
);

@sourcify = qw(
  Context
);

$file = shift;

if( $file =~ /config/ ) {
  @OPT  = @options;
  $PRE  = 'OPTION';
  $NAME = 'ConfigOption';
}
elsif( $file =~ /sourcify/ ) {
  @OPT  = @sourcify;
  $PRE  = 'SOURCIFY_OPTION';
  $NAME = 'SourcifyConfigOption';
}

$ROUT = "get$NAME";
$ROUT =~ s/([a-z])([A-Z])/$1_\l$2/g;

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

static $NAME $ROUT( const char *option )
{
$switch
unknown:
  return INVALID_$PRE;
}
END
close OUT;

