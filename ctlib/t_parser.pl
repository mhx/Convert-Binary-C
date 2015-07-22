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
# $Date: 2003/01/10 22:28:28 +0000 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.09 $
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

# keywords that cannot be disabled
@no_disable = qw(
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

# keywords that can be disabled
@disable = qw(
  auto
  const
  double
  enum extern
  float
  inline
  long
  register restrict
  short signed static
  unsigned
  void volatile
);

# put them in a hash
@NDIS{@no_disable} = (1) x @no_disable;

$file = shift;

if( $file =~ /t_parser/ ) {
  $t = Tokenizer->new( tokfnc => \&t_parser )
                ->addtokens( '', @disable, @no_disable );
}
elsif( $file =~ /t_keywords/ ) {
  $t = Tokenizer->new( tokfnc => \&t_keywords, tokstr => 'str' )
                ->addtokens( '', @disable );
}
elsif( $file =~ /t_ckeytok/ ) {
  $t = Tokenizer->new( tokfnc => \&t_ckeytok, tokstr => 'name' )
                ->addtokens( '', @disable, @no_disable );
}
else { die "invalid file: $file\n" }

open OUT, ">$file" or die "$file: $!";
print OUT $t->makeswitch;
close OUT;

sub t_parser {
  my $token = shift;
  if( exists $NDIS{$token} ) {
    return "return \U$token\E_TOK;\n";
  }
  else {
    return "if( pState->pCPC->keywords & HAS_KEYWORD_\U$token\E )\n"
         . "  return \U$token\E_TOK;\n";
  }
};

sub t_keywords {
  my $token = shift;
  return "keywords &= ~HAS_KEYWORD_\U$token\E;\n"
        ."goto success;\n";
};

sub t_ckeytok {
  my $token = shift;
  return <<END
static const CKeywordToken ckt = { \U$token\E_TOK, "$token" };
return &ckt;
END
};

