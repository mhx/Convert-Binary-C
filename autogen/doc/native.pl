use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1; #-8<-

$size = 1;  # avoid warning

#-8<-

$size = Convert::Binary::C::native('IntSize');

#-8<-

my $nat = Convert::Binary::C::native();

for my $n (sort keys %$nat) {
  print "$n\n";
}

print "#-8<-\n";

print Data::Dumper->Dump([$nat], [qw(native)]);

