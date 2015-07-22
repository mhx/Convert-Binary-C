use Convert::Binary::C; #-8<-

$c = Convert::Binary::C->new->parse( <<'#-8<-' );
struct test {
  char    ary[3];
  union {
    short word[2];
    long *quad;
  }       uni;
  struct {
    unsigned short six:6;
    unsigned short ten:10;
  }       bits;
};
#-8<-

for my $member ( qw( test test.ary test.uni test.uni.quad
                     test.uni.word test.uni.word[1]
                     test.bits test.bits.six test.bits.ten ) ) {
  printf "%-30s => '%s'\n", "\$c->typeof('$member')", $c->typeof( $member );
}
