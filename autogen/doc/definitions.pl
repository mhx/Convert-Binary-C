use Convert::Binary::C;
use Data::Dumper;

my($m,$f) = @ARGV;
my $c = Convert::Binary::C->new->parse_file($f);

$Data::Dumper::Indent = 1;

print Data::Dumper->Dump( [[$c->$m]], ["*$m"] );
