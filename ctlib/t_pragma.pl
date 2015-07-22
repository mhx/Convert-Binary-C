################################################################################
#
# PROGRAM: t_pragma.pl
#
################################################################################
#
# DESCRIPTION: Generate tokenizer code for pragma parser
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/03/17 21:10:05 +0000 $
# $Revision: 4 $
# $Snapshot: /Convert-Binary-C/0.12 $
# $Source: /ctlib/t_pragma.pl $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
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
