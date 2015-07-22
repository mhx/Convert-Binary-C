use Convert::Binary::C;

my %h;

open FILE, "../../ctlib/t_keywords.pl" or die $!;

while( <FILE> ) {
  s/#.*$//;
  $h{$_}++ for /\b([a-z]+)\b/g;
}

close FILE;

my $c = new Convert::Binary::C;
my @kw;

for my $k ( sort keys %h ) {
  eval {
    $c->DisabledKeywords( [$k] );
  };

  $@ or push @kw, $k;
}

print "$_\n" for @kw;

#-8<-

$c->DisabledKeywords( [qw( void )] );

#-8<-

$c->parse( <<'#-8<-' );
typedef int void;
#-8<-

$c->DisabledKeywords( [qw( inline restrict )] );

#-8<-

$c->parse( <<'#-8<-' );
typedef struct inline {
  int a, b;
} restrict;
#-8<-

