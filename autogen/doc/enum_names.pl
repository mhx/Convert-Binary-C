use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 0;

$c = new Convert::Binary::C;

#-8<-

$c->parse( <<'#-8<-' );
enum { A, B, C };

#-8<-

$c->parse( <<'#-8<-' );
struct foo {
  enum weekday *pWeekday;
  unsigned long year;
};

#-8<-

@names = $c->enum_names;

#-8<-

@enums = map { $_->{identifier} || () } $c->enum;

#-8<-

print Data::Dumper->Dump( [\@names], ['*names'] ), "\n";
print Data::Dumper->Dump( [\@enums], ['*enums'] ), "\n";

