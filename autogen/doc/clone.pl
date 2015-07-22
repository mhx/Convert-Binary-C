use Convert::Binary::C;

#-8<-

$c = new Convert::Binary::C Include => ['/usr/include'];
$c->parse_file('definitions.c');
$clone = $c->clone;

#-8<-

$c = new Convert::Binary::C Include => ['/usr/include'];
$c->parse_file('definitions.c');
$clone = new Convert::Binary::C %{$c->configure};
$clone->parse($c->sourcify);

