use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1;

$c = new Convert::Binary::C;
$c->parse_file('definitions.c');

#-8<-

@compound = map { $_->{identifier} || () } $c->compound;

#-8<-

push @{$_->{type} eq 'union' ? \@unions : \@structs}, $_
    for $c->compound;

#-8<-

@structs = $c->struct;
@unions  = $c->union;

