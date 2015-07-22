use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1; #-8<-

$c = Convert::Binary::C->new( Alignment => 4, EnumSize => 4 )
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

for my $offset ( 24, 39, 69, 99 ) {
  print "\$c->member( 'test', $offset )";
  my $member = eval { $c->member( 'test', $offset ) };
  $@ and $@ =~ s/at\s$0.*//; #-8<-
  print $@ ? "\n$@" : " => '$member'\n";
}

print "#-8<-\n";

#-8<-

for my $offset ( 24, 39, 69 ) {
  print "\$c->member( 'test', $offset ) => ";
  my($member, $type) = $c->member( 'test', $offset );
  printf "('$member', %s)\n", defined $type ? "'$type'" : 'undef';
}

print "#-8<-\n";

#-8<-

$c->parse( <<'ENDC' );
struct inlined {
  long dummy;
  enum { INSIDE } inside;
};
ENDC

($member, $type) = $c->member( 'inlined', 6 );
print Data::Dumper->Dump( [$member, $type], [qw(member type)] );

print "#-8<-\n";

#-8<-

($member,$type) = $c->member('test.zap[2]', 6);
print "('$member', '$type')\n";

print "#-8<-\n";

#-8<-

@args = (
  ['test',        'zap[5].day'  ],
  ['test.zap[2]', 'day'         ],
  ['test',        'zap[5].day+1'],
);

for( @args ) {
  printf "\$c->offsetof( '%s', '%s' )", @$_;
  my $offset = eval { $c->offsetof( @$_ ) };
  $@ and $@ =~ s/at\s$0.*//; #-8<-
  print $@ ? "\n$@" : " => $offset\n";
}

#-8<-

$c->parse( <<'#-8<-' );
union choice {
  struct {
    char  color[2];
    long  size;
    char  taste;
  }       apple;
  char    grape[3];
  struct {
    long  weight;
    short price[3];
  }       melon;
};
#-8<-

print "#-8<-\n";
print "Offset   Member               Type\n";
print "--------------------------------------\n";
for my $offset ( 0 .. $c->sizeof('choice') - 1 ) {
  my($member, $type) = $c->member( 'choice', $offset );
  printf " %3d     %-20s %s\n", $offset, $member,
         defined $type ? "'$type'" : 'undef';
}

