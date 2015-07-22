use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1; #-8<-

print Data::Dumper->Dump([Convert::Binary::C::native()], [qw(native)]);

