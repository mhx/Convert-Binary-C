use Convert::Binary::C;

#-8<-

$c = Convert::Binary::C->new(Include => ['/usr/include']);
$c->parse_file('definitions.c');
$clone = $c->clone;

#-8<-

$c = Convert::Binary::C->new(Include => ['/usr/include']);
$c->parse_file('definitions.c');
$clone = Convert::Binary::C->new(%{$c->configure});
$clone->parse($c->sourcify);

