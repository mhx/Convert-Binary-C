#include <stdio.h>

typedef unsigned long U32;

typedef struct {
  U32 lower;
  U32 upper;
} U64;

static const U32 CDIV[10] = {
  0U, 429496729U,  858993459U, 1288490188U,
     1717986918U, 2147483648U, 2576980377U,
     3006477107U, 3435973836U, 3865470566U
};

static const U32 CMOD[10] =
  { 0U, 6U, 2U, 8U, 4U, 0U, 6U, 2U, 8U, 4U };

int U64_2_STR( register char *dest, const U64 *src )
{
  register U32 uval, lval, tval, umod, lmod;
  int stack[20], len, sp = 0;

  uval = src->upper;
  lval = src->lower;

  while( uval > 0 ) {
    umod  = uval % 10; uval /= 10;
    lmod  = lval % 10; lval /= 10;

    lmod += CMOD[umod];
    tval  = CDIV[umod];

    if( lmod >= 10 )
      lmod -= 10, tval++;

    lval += tval;

    if( lval < tval )
      uval++;

    stack[sp++] = lmod;
  }

  while( lval > 0 )
    stack[sp++] = lval % 10, lval /= 10;

  len = sp;

  if( sp == 0 )
    *dest++ = '0';
  else while( sp-- > 0 )
    *dest++ = '0' + stack[sp];

  *dest = '\0';

  return len;
}

void STR_2_U64( U64 *dest, register const char *src )
{
  register U32 uval, lval, temp;

  uval = lval = 0;

  while( lval < 429496729 ) {
    /* printf( "uval=%10u lval=%10u\n", uval, lval ); */

    if( !isdigit( *src ) )
      goto end_of_string;

    lval = 10*lval + (int) (*src++ - '0');
  }

  while( isdigit( *src ) ) {
    /* printf( "uval=%10u lval=%10u\n", uval, lval ); */

    uval = ((uval << 3) | (lval >> 29))
         + ((uval << 1) | (lval >> 31));

    lval <<= 1;

/*
    temp = lval + (lval << 2) + (int) (*src++ - '0');

    if( temp < lval )
      uval++;

    lval = temp;
*/
    temp = lval + (lval << 2);

    if( temp < lval )
      uval++;

    lval = temp + (int) (*src++ - '0');

    if( lval < temp )
      uval++;
  }

  end_of_string:

  dest->upper = uval;
  dest->lower = lval;
}

int main( void )
{
  char buffer[32];
  // U64 x = {0x2C0FFEE5, 0xDEADBEEF};
  // U64 x = {0x64D60A35, 0x2D781233};
  U64 x = {0xf7160ad7, 0x944b8917};
  U64 y;
  U64 z;

  U64_2_STR( buffer, &x );
  printf("%Lu\n", ((unsigned long long)x.upper<<32)|x.lower);
  printf("%s\n", buffer);

  STR_2_U64( &y, buffer );
  printf("%Lu\n", ((unsigned long long)y.upper<<32)|y.lower);
  printf("%08X, %08X\n", y.upper, y.lower);

  return 0;
}
