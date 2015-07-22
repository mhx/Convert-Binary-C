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

%size = (
END

for( sort keys %defs ) {
  printf "\t%s\t=>\t%${maxs}d,\n", "'$_'", $defs{$_};
}
print ");\n";
