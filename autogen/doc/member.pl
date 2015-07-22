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

for my $offset ( 24, 39, 69, 99 ) {
  print "\$c->member( 'test', $offset )";
  my $member = eval { $c->member( 'test', $offset ) };
  $@ and $@ =~ s/at\s$0.*//; #-8<-
  print $@ ? "\n  exception: $@" : " => '$member'\n";
  push @check, $member; #-8<-
}

@check == 4                  or die 'count';    #-8<-
$check[0] eq '.zap[2].abc'   or die $check[0];  #-8<-
$check[1] eq '.zap[3]+3'     or die $check[1];  #-8<-
$check[2] eq '.zap[5].ptr+1' or die $check[2];  #-8<-
not defined $check[3]        or die $check[3];  #-8<-
$c->sizeof('test') == 96     or die 'sizeof';   #-8<-

print "#-8<-\n";

#-8<----------------[2]-----------------------

$member = $c->member('test.zap[2]', 6);
print $member;

$member eq '.day+2' or die $member;  #-8<-
print "\n#-8<-\n";

#-8<----------------[3]-----------------------

$member = $c->member('test.zap', 42);
print $member;

$member eq '[3].day+2' or die $member;  #-8<-
print "\n#-8<-\n";

#-8<----------------[4]-----------------------

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

print "Offset   Member               Type\n";
print "--------------------------------------\n";
for my $offset ( 0 .. $c->sizeof('choice') - 1 ) {
  my $member = $c->member( 'choice', $offset );
  my $type = $c->typeof( "choice $member" );
  printf " %3d     %-20s '%s'\n", $offset, $member, $type;
}
print "#-8<-\n";

print "Offset   Member               Type\n";
print "--------------------------------------\n";
for my $offset ( 0 .. $c->sizeof('choice') - 1 ) {
  my $off = $offset;
  for my $member ( $c->member( 'choice', $offset ) ) {
    my $type = $c->typeof( "choice $member" );
    printf " %3s     %-20s '%s'\n", $off, $member, $type;
    $off = '';
  }
}

