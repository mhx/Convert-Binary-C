use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1;

$c = Convert::Binary::C->new;
$c->parse_file('definitions.c');

#-8<-

%enum = map %{ $_->{enumerators} || {} }, $c->enum;

#-8<-

print Data::Dumper->Dump([\%enum], ['*enum']);

