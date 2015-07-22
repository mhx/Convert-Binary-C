################################################################################
#
# PROGRAM: pragma.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for pragma parser
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2009/03/15 03:10:45 +0000 $
# $Revision: 17 $
# $Source: /token/pragma.pl $
#
################################################################################
#
# Copyright (c) 2002-2009 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################

use Devel::Tokenizer::C;

$t = new Devel::Tokenizer::C TokenFunc => \&tok_code,
                             TokenEnd  => 'PRAGMA_TOKEN_END';

$t->add_tokens( qw(
  pack
  push
  pop
));

open OUT, ">$ARGV[0]" or die $!;
print OUT $t->generate;
close OUT;

sub tok_code {
  my $token = shift;
  my $toklen = length $token;
  return <<ENDTOKCODE
toklen = $toklen;
tokval = \U$token\E_TOK;
goto success;
ENDTOKCODE
};
