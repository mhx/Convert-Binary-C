use strict;

my %defs;
my $maxt = 0;
my $maxs = 0;

while( <> ) {
  my($type,$size) = /([^=]+)=(\d+)/;
  $maxt = length($type) if length($type) > $maxt;
  $maxs = length($size) if length($size) > $maxs;
  $defs{$type} = $size;
}

$maxt += 2;

print <<'END';
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/11/23 17:46:41 +0000 $
# $Revision: 1 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /devel/sizes/mksizeof.pl $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

%size = (
END

for( sort keys %defs ) {
  printf "  %-${maxt}s => %${maxs}d,\n", "'$_'", $defs{$_};
}
print ");\n";
