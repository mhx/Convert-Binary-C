use Convert::Binary::C;

my %h;

open FILE, "../../token/parser.pl" or die $!;

while (<FILE>) {
  s/#.*$//;
  $h{$_}++ for /\b([a-z]+)\b/g;
}

close FILE;

my $c = new Convert::Binary::C;
my @kw;

for my $k (sort keys %h) {
  eval { $c->DisabledKeywords([$k]) };
  $@ or push @kw, $k;
}

print "$_\n" for @kw;

#-8<-

$c->DisabledKeywords([qw( void )]);

#-8<-

$c->parse(<<'#-8<-');
typedef int void;
#-8<-

$c->DisabledKeywords([qw( inline restrict )]);

#-8<-

$c->parse(<<'#-8<-');
typedef struct inline {
  int a, b;
} restrict;
#-8<-

$c->Define(qw( __signed__=signed __extension__= ));

#-8<-

eval { $c->parse(<<'#-8<-');
#ifdef __signed__
# undef __signed__
#endif

typedef __extension__ __signed__ long long s_quad;
#-8<-
}; $@ or die; #-8<-

$c->Define([]); #-8<-

$c->KeywordMap({ __signed__    => 'signed',
                 __extension__ => undef });

#-8<-

$c->parse(<<'#-8<-');
#ifdef __signed__
# undef __signed__
#endif

typedef __extension__ __signed__ long long s_quad;
#-8<-

$c->configure(DisabledKeywords => [ 'signed' ],
              KeywordMap       => { __signed__  => 'signed' });

#-8<-

$c->parse(<<'#-8<-');
typedef __signed__ long signed;
#-8<-
