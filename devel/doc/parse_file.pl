use Convert::Binary::C;

$c = new Convert::Binary::C;

#-8<-
$c->parse( <<'#-8<-' );

void my_func( int i )
{
  if( i < 10 ) {
    enum digit { ONE, TWO, THREE } x = ONE;
    printf("%d, %d\n", i, x);
  }
  else {
    enum digit { THREE, TWO, ONE } x = ONE;
    printf("%d, %d\n", i, x);
  }
}

#-8<-
