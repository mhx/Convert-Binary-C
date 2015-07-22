my $fp = '\d+\.\d+';
my %f;
while( <> ) {
  next unless /^\s*($fp)\s+$fp\s+($fp)\s+(\d+).*Convert::Binary::C::(\w+)/;
  $f{$4} = [$1, $2/$3];
}

for( sort keys %f ) {
  my($p, $t) = @{$f{$_}};
  my @s = (' ', 'm', 'u', 'n');
  my $i = 0;
  $t *= 1000, $i++ while $t < 1;
  printf "%-20s %10.2f $s[$i]s  (%6.2f %%)\n", $_, $t, $p;
}
