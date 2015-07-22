use Convert::Binary::C;

$c = Convert::Binary::C->new( Alignment   => 4
                            , LongSize    => 4
                            , PointerSize => 4
                            )
                       ->parse( <<'ENDC' );
typedef struct {
  char abc;
  long day;
  int *ptr;
} week;

struct test {
  week zap[8];
};
ENDC

@args = (
  ['test',        'zap[5].day'  ],
  ['test.zap[2]', 'day'         ],
  ['test',        'zap[5].day+1'],
);

@check = (); #-8<-
for( @args ) {
  my $offset = eval { $c->offsetof( @$_ ) };
  printf "\$c->offsetof( '%s', '%s' ) => $offset\n", @$_;
  push @check, $offset; #-8<-
}

@check == 3     or die 'count';    #-8<-
$check[0] == 64 or die $check[0];  #-8<-
$check[1] == 4  or die $check[1];  #-8<-
$check[2] == 65 or die $check[2];  #-8<-

print "#-8<-\n";

#-8<----------------[2]-----------------------

$offset = $c->offsetof( 'test.zap', '[3].ptr+2' );
print "offset = $offset";

$offset == 46 or die $offset;  #-8<-
print "\n#-8<-\n";

#-8<----------------[3]-----------------------

printf "offset = %d\n", $c->offsetof( 'week', 'day' );
printf "offset = %d\n", $c->offsetof( 'week', '.day' );

print "\n#-8<-\n";

