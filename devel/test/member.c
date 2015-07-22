#include <stdio.h>
#include <stddef.h>

#pragma pack( 1 )

typedef struct {

  char   c;
  long double d;
  long   l;

} test;

#pragma pack()

#define SIZE( what ) \
  printf("sizeof( " #what " ) = %d\n", sizeof( what ))

#define OFFSET( type, what ) \
  printf("offsetof( " #type ", " #what " ) = %d\n", offsetof( type, what ))

enum {
  UCH = (unsigned char) 800 // -800
};

int main( void )
{
/*
  test t;

  SIZE( t );
  SIZE( t.d );
  OFFSET( test, c );
  OFFSET( test, d );
  OFFSET( test, l );
*/
  printf("%d\n", UCH);

  return 0;
}
