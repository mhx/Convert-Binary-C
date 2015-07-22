use Convert::Binary::C; #-8<-
$c = Convert::Binary::C->new->parse(<<'#-8<-');
struct foo {
  int bar;
};

typedef int foo;
#-8<-

$c = new Convert::Binary::C;
$size = $c->sizeof( 'unsigned long' );
$data = $c->pack( 'short int', 42 );

#-8<-

eval { #-8<-
$size = $c->sizeof( 'struct { int a, b; }' );
}; #-8<-
$@ or die "no error"; #-8<-

#-8<-

$c->parse(<<'#-8<-'); 

struct foo {
  long type;
  struct {
    short x, y;
  } array[20];
};

typedef struct foo matrix[8][8];

#-8<-

print $c->sizeof( 'foo.array' ), " bytes";
print "\n#-8<-\n";

#-8<-

$data = $data x 1000; #-8<-
$column = $c->unpack( 'matrix[2]', $data );
defined $column or die "no"; #-8<-

#-8<-

$type = $c->typeof( 'matrix[2][3].array[7].y' );
print "the type is $type";

print "\n#-8<-\n";

#-8<-

$member = $c->member( 'matrix', 1431 );
print $member;
print "\n#-8<-\n";

#-8<-

$size = $c->sizeof( "matrix $member" );

#-8<-

$member = $c->member( 'foo', 43 );
$offset = $c->offsetof( 'foo', $member );
print "'$member' is located at offset $offset of struct foo";

print "\n#-8<-\n";

#-8<-

$member =~ s/\+\d+$//;
$offset = $c->offsetof( 'foo', $member );
print "'$member' starts at offset $offset of struct foo";

print "\n#-8<-\n";

