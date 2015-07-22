/*******************************************************************************
*
* HEADER: integer.h
*
********************************************************************************
*
* DESCRIPTION: 64-bit integer support
*
*******************************************************************************/

#ifndef _INTEGER_H
#define _INTEGER_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "arch.h"


/*===== DEFINES ==============================================================*/

#ifdef NATIVE_64_BIT_INTEGER

#define U64_ZERO(x)   (x)=0

#define _OP_UADD
#define _OP_USUB
#define _OP_UMUL
#define _OP_UDIV
#define _OP_UMOD
#define _OP_UNEG

#define _OP_USHL
#define _OP_USHR

#define _OP_UBNOT
#define _OP_UBAND
#define _OP_UBOR
#define _OP_UBXOR

#define _OP_ULNOT
#define _OP_ULAND
#define _OP_ULOR

#define _OP_UCLT
#define _OP_UCGT
#define _OP_UCLE
#define _OP_UCGE
#define _OP_UCEQ
#define _OP_UCNE

#define UNOP( name, dest, src )                                                \
        if( ((dest).s = (src).s) != 0 ) {                                      \
          _OP_S ## name ( (dest).i.s, (src).i.s );                             \
        }                                                                      \
        else {                                                                 \
          _OP_U ## name ( (dest).i.u, (src).i.u );                             \
        }                                                                      \
        0

#define BINOP( name, dest, src1, src2 )                                        \
        if( ((dest).s = (src1).s || (src2).s) != 0 ) {                         \
          _OP_S ## name ( (dest).i.s, (src1).i.s, (src2).i.s );                \
        }                                                                      \
        else {                                                                 \
          _OP_U ## name ( (dest).i.u, (src1).i.u, (src2).i.u );                \
        }                                                                      \
        0

#else /* NATIVE_64_BIT_INTEGER */

#endif

/*===== TYPEDEFS =============================================================*/

#define UNSIGNED_TYPE( x )    ( (x) & 1 )
#define SIGNED_TYPE( x )    ( ( (x) & 1 ) == 0 )

typedef struct {
  union {
    u_64 u;
    i_64 s;
  }         i;
  enum {
    type_int         = 0,  /* sorted by precedence   */
    type_u_int       = 1,  /* lsb indicates unsigned */
    type_long        = 2,
    type_u_long      = 3,
    type_long_long   = 4,
    type_u_long_long = 5,
  }         type;
} INTEGER;

/*===== FUNCTION PROTOTYPES ==================================================*/


#endif
