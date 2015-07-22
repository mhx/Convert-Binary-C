use Convert::Binary::C;

my $c = Convert::Binary::C->new->parse( <<'ENDC' );

typedef struct __not  not;
typedef struct __not *ptr;

struct foo {
  enum bar *xxx;
};

typedef int quad[4];

ENDC

for my $type ( qw( not ptr foo bar xxx foo.xxx foo.abc
                   xxx.yyy quad quad[3] quad[4] short[1] ),
               'unsigned long' )
{
  my $def = $c->def( $type );
  printf "%-14s  =>  %s\n", $type, defined $def
                                   ? "'$def'" : 'undef';
}
