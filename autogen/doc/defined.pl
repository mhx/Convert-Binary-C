use Convert::Binary::C;

my $c = Convert::Binary::C->new->parse(<<'ENDC');

#define ADD(a, b) ((a) + (b))

#if 1
# define DEFINED
#else
# define UNDEFINED
#endif

ENDC

for my $macro (qw( ADD DEFINED UNDEFINED )) {
  my $not = $c->defined($macro) ? '' : ' not';
  print "Macro '$macro' is$not defined.\n";
}
