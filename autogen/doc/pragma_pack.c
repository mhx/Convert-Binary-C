/*  Example assumes sizeof( short ) == 2, sizeof( long ) == 4.  */

#pragma pack(1)

struct nopad {
  char a;               /* no padding bytes between 'a' and 'b' */
  long b;
};

#pragma pack            /* reset to "native" alignment          */

#pragma pack( push, 2 )

struct pad {
  char    a;            /* one padding byte between 'a' and 'b' */
  long    b;

#pragma pack( push, 1 )

  struct {
    char  c;            /* no padding between 'c' and 'd'       */
    short d;
  }       e;            /* sizeof( e ) == 3                     */

#pragma pack( pop );    /* back to pack( 2 )                    */

  long    f;            /* one padding byte between 'e' and 'f' */
};

#pragma pack( pop );    /* back to "native"                     */
