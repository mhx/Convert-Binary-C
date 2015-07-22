#include <stdio.h>

int main( void ) {
  int x, y;
  x &&= y;

  return 0;
}

#if 0

typedef struct {
  int a;
  struct {
    char  c[3];
    short d;
  }   b[2];
} xxx;

enum enu {
  UCH = &(((xxx *)0)->b[1].c[2]),
  NEG = -1,
  BIG = 16000000000/4
};

int main( void )
{
  printf("%d\n", sizeof(enum enu));
  printf("%d\n", UCH);
  printf("%u\n", BIG);

  return 0;
}

#endif
