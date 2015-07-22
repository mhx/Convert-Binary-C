use Convert::Binary::C;

my $c = Convert::Binary::C->new->parse( <<'ENDC' );

typedef struct __not  not;
typedef struct __not *ptr;

struct foo {
  enum bar *xxx;
};

ENDC

for my $type ( qw( not ptr foo bar xxx ),
               'unsigned long' )
{
  my $def = $c->def( $type );
  printf "\$c->def( '$type' )  =>  %s\n",
         defined $def ? "'$def'" : 'undef';
}
