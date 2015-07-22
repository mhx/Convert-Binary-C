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
# $Date: 2002/12/11 13:54:43 +0000 $
# $Revision: 2 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /ctlib/t_pragma.pl $
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

$t = new Tokenizer tokfnc => \&tok_code,
                   endtok => 'PRAGMA_TOKEN_END';

$t->addtokens( '', qw(
  pack
  push
  pop
));

open OUT, ">$ARGV[0]" or die $!;
print OUT $t->makeswitch;
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
