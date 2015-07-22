/*******************************************************************************
*
* MODULE: ctype.c
*
********************************************************************************
*
* DESCRIPTION: ANSI C data type objects
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/23 18:41:14 +0000 $
* $Revision: 4 $
* $Snapshot: /Convert-Binary-C/0.11 $
* $Source: /ctlib/byteorder.c $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <ctype.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "byteorder.h"


/*===== DEFINES ==============================================================*/

#ifndef NULL
#define NULL ((void *) 0)
#endif

/*----------------------------------------------------------*/
/* reading/writing integers in big/little endian byte order */
/* depending on the native byte order of the system         */
/*----------------------------------------------------------*/

#ifdef NATIVE_BIG_ENDIAN

/*--------------------*/
/* big endian systems */
/*--------------------*/

#define GET_LE_WORD( ptr, value, sign )                                        \
          value = (sign ## _16)                                                \
                  ( ( (u_16) *( (const u_8 *) ((ptr)+0) ) <<  0)               \
                  | ( (u_16) *( (const u_8 *) ((ptr)+1) ) <<  8)               \
                  )

#define GET_LE_LONG( ptr, value, sign )                                        \
          value = (sign ## _32)                                                \
                  ( ( (u_32) *( (const u_8 *) ((ptr)+0) ) <<  0)               \
                  | ( (u_32) *( (const u_8 *) ((ptr)+1) ) <<  8)               \
                  | ( (u_32) *( (const u_8 *) ((ptr)+2) ) << 16)               \
                  | ( (u_32) *( (const u_8 *) ((ptr)+3) ) << 24)               \
                  )

#ifdef NATIVE_64_BIT_INTEGER

#define GET_LE_LONGLONG( ptr, value, sign )                                    \
          value = (sign ## _64)                                                \
                  ( ( (u_64) *( (const u_8 *) ((ptr)+0) ) <<  0)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+1) ) <<  8)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+2) ) << 16)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+3) ) << 24)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+4) ) << 32)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+5) ) << 40)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+6) ) << 48)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+7) ) << 56)               \
                  )

#endif

#define SET_LE_WORD( ptr, value )                                              \
          do {                                                                 \
            register u_16 v = value;                                           \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >>  0) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >>  8) & 0xFF);                   \
          } while(0)

#define SET_LE_LONG( ptr, value )                                              \
          do {                                                                 \
            register u_32 v = value;                                           \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >>  0) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+2)) = (u_8) ((v >> 16) & 0xFF);                   \
            *((u_8 *) ((ptr)+3)) = (u_8) ((v >> 24) & 0xFF);                   \
          } while(0)

#ifdef NATIVE_64_BIT_INTEGER

#define SET_LE_LONGLONG( ptr, value )                                          \
          do {                                                                 \
            register u_64 v = value;                                           \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >>  0) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+2)) = (u_8) ((v >> 16) & 0xFF);                   \
            *((u_8 *) ((ptr)+3)) = (u_8) ((v >> 24) & 0xFF);                   \
            *((u_8 *) ((ptr)+4)) = (u_8) ((v >> 32) & 0xFF);                   \
            *((u_8 *) ((ptr)+5)) = (u_8) ((v >> 40) & 0xFF);                   \
            *((u_8 *) ((ptr)+6)) = (u_8) ((v >> 48) & 0xFF);                   \
            *((u_8 *) ((ptr)+7)) = (u_8) ((v >> 56) & 0xFF);                   \
          } while(0)

#endif

#ifdef CAN_UNALIGNED_ACCESS

#define GET_BE_WORD( ptr, value, sign ) \
          value = (sign ## _16) ( *( (const u_16 *) (ptr) ) )

#define GET_BE_LONG( ptr, value, sign ) \
          value = (sign ## _32) ( *( (const u_32 *) (ptr) ) )

#ifdef NATIVE_64_BIT_INTEGER

#define GET_BE_LONGLONG( ptr, value, sign ) \
          value = (sign ## _64) ( *( (const u_64 *) (ptr) ) )

#endif

#define SET_BE_WORD( ptr, value ) \
          *( (u_16 *) (ptr) ) = (u_16) value

#define SET_BE_LONG( ptr, value ) \
          *( (u_32 *) (ptr) ) = (u_32) value

#ifdef NATIVE_64_BIT_INTEGER

#define SET_BE_LONGLONG( ptr, value ) \
          *( (u_64 *) (ptr) ) = (u_64) value

#endif

#else

#define GET_BE_WORD( ptr, value, sign )                                        \
          do {                                                                 \
            if( ((unsigned long) (ptr)) % 2 )                                  \
              value = (sign ## _16)                                            \
                      ( ( (u_16) *( (const u_8 *) ((ptr)+0) ) <<  8)           \
                      | ( (u_16) *( (const u_8 *) ((ptr)+1) ) <<  0)           \
                      );                                                       \
            else                                                               \
              value = (sign ## _16) ( *( (const u_16 *) (ptr) ) );             \
          } while(0)

#define GET_BE_LONG( ptr, value, sign )                                        \
          do {                                                                 \
            switch( ((unsigned long) (ptr)) % 4 ) {                            \
              case 0:                                                          \
                value = (sign ## _32) ( *( (const u_32 *) (ptr) ) );           \
                break;                                                         \
                                                                               \
              case 2:                                                          \
                value = (sign ## _32)                                          \
                        ( ( (u_32) *( (const u_16 *) ((ptr)+0) ) << 16)        \
                        | ( (u_32) *( (const u_16 *) ((ptr)+2) ) <<  0)        \
                        );                                                     \
                break;                                                         \
                                                                               \
              default:                                                         \
                value = (sign ## _32)                                          \
                        ( ( (u_32) *( (const u_8 *)  ((ptr)+0) ) << 24)        \
                        | ( (u_32) *( (const u_16 *) ((ptr)+1) ) <<  8)        \
                        | ( (u_32) *( (const u_8 *)  ((ptr)+3) ) <<  0)        \
                        );                                                     \
                break;                                                         \
            }                                                                  \
          } while(0)

#ifdef NATIVE_64_BIT_INTEGER

#define GET_BE_LONGLONG( ptr, value, sign )                                    \
          do {                                                                 \
            value = (sign ## _64)                                              \
                    ( ( (u_64) *( (const u_8 *)  ((ptr)+0) ) << 56)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+1) ) << 48)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+2) ) << 40)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+3) ) << 32)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+4) ) << 24)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+5) ) << 16)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+6) ) <<  8)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+7) ) <<  0)            \
                    );                                                         \
          } while(0)

#endif

#define SET_BE_WORD( ptr, value )                                              \
          do {                                                                 \
            if( ((unsigned long) (ptr)) % 2 ) {                                \
              register u_16 v = (u_16) value;                                  \
              *((u_8 *) ((ptr)+0)) = (u_8) ((v >> 8) & 0xFF);                  \
              *((u_8 *) ((ptr)+1)) = (u_8) ((v >> 0) & 0xFF);                  \
            }                                                                  \
            else                                                               \
              *( (u_16 *) (ptr) ) = (u_16) value;                              \
          } while(0)

#define SET_BE_LONG( ptr, value )                                              \
          do {                                                                 \
            switch( ((unsigned long) (ptr)) % 4 ) {                            \
              case 0:                                                          \
                *( (u_32 *) (ptr) ) = (u_32) value;                            \
                break;                                                         \
                                                                               \
              case 2:                                                          \
                {                                                              \
                  register u_32 v = (u_32) value;                              \
                  *((u_16 *) ((ptr)+0)) = (u_16) ((v >> 16) & 0xFFFF);         \
                  *((u_16 *) ((ptr)+2)) = (u_16) ((v >>  0) & 0xFFFF);         \
                }                                                              \
                break;                                                         \
                                                                               \
              default:                                                         \
                {                                                              \
                  register u_32 v = (u_32) value;                              \
                  *((u_8 *)  ((ptr)+0)) = (u_8)  ((v >> 24) & 0xFF  );         \
                  *((u_16 *) ((ptr)+1)) = (u_16) ((v >>  8) & 0xFFFF);         \
                  *((u_8 *)  ((ptr)+3)) = (u_8)  ((v >>  0) & 0xFF  );         \
                }                                                              \
                break;                                                         \
            }                                                                  \
          } while(0)

#ifdef NATIVE_64_BIT_INTEGER

#define SET_BE_LONGLONG( ptr, value )                                          \
          do {                                                                 \
            register u_64 v = value;                                           \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >> 56) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >> 48) & 0xFF);                   \
            *((u_8 *) ((ptr)+2)) = (u_8) ((v >> 40) & 0xFF);                   \
            *((u_8 *) ((ptr)+3)) = (u_8) ((v >> 32) & 0xFF);                   \
            *((u_8 *) ((ptr)+4)) = (u_8) ((v >> 24) & 0xFF);                   \
            *((u_8 *) ((ptr)+5)) = (u_8) ((v >> 16) & 0xFF);                   \
            *((u_8 *) ((ptr)+6)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+7)) = (u_8) ((v >>  0) & 0xFF);                   \
          } while(0)

#endif

#endif

#else /* ! NATIVE_BIG_ENDIAN */

/*-----------------------*/
/* little endian systems */
/*-----------------------*/

#define GET_BE_WORD( ptr, value, sign )                                        \
          value = (sign ## _16)                                                \
                  ( ( (u_16) *( (const u_8 *) ((ptr)+0) ) <<  8)               \
                  | ( (u_16) *( (const u_8 *) ((ptr)+1) ) <<  0)               \
                  )

#define GET_BE_LONG( ptr, value, sign )                                        \
          value = (sign ## _32)                                                \
                  ( ( (u_32) *( (const u_8 *) ((ptr)+0) ) << 24)               \
                  | ( (u_32) *( (const u_8 *) ((ptr)+1) ) << 16)               \
                  | ( (u_32) *( (const u_8 *) ((ptr)+2) ) <<  8)               \
                  | ( (u_32) *( (const u_8 *) ((ptr)+3) ) <<  0)               \
                  )

#ifdef NATIVE_64_BIT_INTEGER

#define GET_BE_LONGLONG( ptr, value, sign )                                    \
          value = (sign ## _64)                                                \
                  ( ( (u_64) *( (const u_8 *) ((ptr)+0) ) << 56)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+1) ) << 48)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+2) ) << 40)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+3) ) << 32)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+4) ) << 24)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+5) ) << 16)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+6) ) <<  8)               \
                  | ( (u_64) *( (const u_8 *) ((ptr)+7) ) <<  0)               \
                  )

#endif

#define SET_BE_WORD( ptr, value )                                              \
          do {                                                                 \
            register u_16 v = (u_16) value;                                    \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >>  0) & 0xFF);                   \
          } while(0)

#define SET_BE_LONG( ptr, value )                                              \
          do {                                                                 \
            register u_32 v = (u_32) value;                                    \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >> 24) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >> 16) & 0xFF);                   \
            *((u_8 *) ((ptr)+2)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+3)) = (u_8) ((v >>  0) & 0xFF);                   \
          } while(0)

#ifdef NATIVE_64_BIT_INTEGER

#define SET_BE_LONGLONG( ptr, value )                                          \
          do {                                                                 \
            register u_64 v = value;                                           \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >> 56) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >> 48) & 0xFF);                   \
            *((u_8 *) ((ptr)+2)) = (u_8) ((v >> 40) & 0xFF);                   \
            *((u_8 *) ((ptr)+3)) = (u_8) ((v >> 32) & 0xFF);                   \
            *((u_8 *) ((ptr)+4)) = (u_8) ((v >> 24) & 0xFF);                   \
            *((u_8 *) ((ptr)+5)) = (u_8) ((v >> 16) & 0xFF);                   \
            *((u_8 *) ((ptr)+6)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+7)) = (u_8) ((v >>  0) & 0xFF);                   \
          } while(0)

#endif

#ifdef CAN_UNALIGNED_ACCESS

#define GET_LE_WORD( ptr, value, sign ) \
          value = (sign ## _16) ( *( (const u_16 *) (ptr) ) )

#define GET_LE_LONG( ptr, value, sign ) \
          value = (sign ## _32) ( *( (const u_32 *) (ptr) ) )

#ifdef NATIVE_64_BIT_INTEGER

#define GET_LE_LONGLONG( ptr, value, sign ) \
          value = (sign ## _64) ( *( (const u_64 *) (ptr) ) )

#endif

#define SET_LE_WORD( ptr, value ) \
          *( (u_16 *) (ptr) ) = (u_16) value

#define SET_LE_LONG( ptr, value ) \
          *( (u_32 *) (ptr) ) = (u_32) value

#ifdef NATIVE_64_BIT_INTEGER

#define SET_LE_LONGLONG( ptr, value ) \
          *( (u_64 *) (ptr) ) = (u_64) value

#endif

#else

#define GET_LE_WORD( ptr, value, sign )                                        \
          do {                                                                 \
            if( ((unsigned long) (ptr)) % 2 )                                  \
              value = (sign ## _16)                                            \
                      ( ( (u_16) *( (const u_8 *) ((ptr)+0) ) <<  0)           \
                      | ( (u_16) *( (const u_8 *) ((ptr)+1) ) <<  8)           \
                      );                                                       \
            else                                                               \
              value = (sign ## _16) ( *( (const u_16 *) (ptr) ) );             \
          } while(0)

#define GET_LE_LONG( ptr, value, sign )                                        \
          do {                                                                 \
            switch( ((unsigned long) (ptr)) % 4 ) {                            \
              case 0:                                                          \
                value = (sign ## _32) ( *( (const u_32 *) (ptr) ) );           \
                break;                                                         \
                                                                               \
              case 2:                                                          \
                value = (sign ## _32)                                          \
                        ( ( (u_32) *( (const u_16 *) ((ptr)+0) ) <<  0)        \
                        | ( (u_32) *( (const u_16 *) ((ptr)+2) ) << 16)        \
                        );                                                     \
                break;                                                         \
                                                                               \
              default:                                                         \
                value = (sign ## _32)                                          \
                        ( ( (u_32) *( (const u_8 *)  ((ptr)+0) ) <<  0)        \
                        | ( (u_32) *( (const u_16 *) ((ptr)+1) ) <<  8)        \
                        | ( (u_32) *( (const u_8 *)  ((ptr)+3) ) << 24)        \
                        );                                                     \
                break;                                                         \
            }                                                                  \
          } while(0)

#ifdef NATIVE_64_BIT_INTEGER

#define GET_LE_LONGLONG( ptr, value, sign )                                    \
          do {                                                                 \
            value = (sign ## _64)                                              \
                    ( ( (u_64) *( (const u_8 *)  ((ptr)+0) ) <<  0)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+1) ) <<  8)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+2) ) << 16)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+3) ) << 24)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+4) ) << 32)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+5) ) << 40)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+6) ) << 48)            \
                    | ( (u_64) *( (const u_8 *)  ((ptr)+7) ) << 56)            \
                    );                                                         \
          } while(0)

#endif

#define SET_LE_WORD( ptr, value )                                              \
          do {                                                                 \
            if( ((unsigned long) (ptr)) % 2 ) {                                \
              register u_16 v = (u_16) value;                                  \
              *((u_8 *) ((ptr)+0)) = (u_8) ((v >> 0) & 0xFF);                  \
              *((u_8 *) ((ptr)+1)) = (u_8) ((v >> 8) & 0xFF);                  \
            }                                                                  \
            else                                                               \
              *( (u_16 *) (ptr) ) = (u_16) value;                              \
          } while(0)

#define SET_LE_LONG( ptr, value )                                              \
          do {                                                                 \
            switch( ((unsigned long) (ptr)) % 4 ) {                            \
              case 0:                                                          \
                *( (u_32 *) (ptr) ) = (u_32) value;                            \
                break;                                                         \
                                                                               \
              case 2:                                                          \
                {                                                              \
                  register u_32 v = (u_32) value;                              \
                  *((u_16 *) ((ptr)+0)) = (u_16) ((v >>  0) & 0xFFFF);         \
                  *((u_16 *) ((ptr)+2)) = (u_16) ((v >> 16) & 0xFFFF);         \
                }                                                              \
                break;                                                         \
                                                                               \
              default:                                                         \
                {                                                              \
                  register u_32 v = (u_32) value;                              \
                  *((u_8 *)  ((ptr)+0)) = (u_8)  ((v >>  0) & 0xFF  );         \
                  *((u_16 *) ((ptr)+1)) = (u_16) ((v >>  8) & 0xFFFF);         \
                  *((u_8 *)  ((ptr)+3)) = (u_8)  ((v >> 24) & 0xFF  );         \
                }                                                              \
                break;                                                         \
            }                                                                  \
          } while(0)

#ifdef NATIVE_64_BIT_INTEGER

#define SET_LE_LONGLONG( ptr, value )                                          \
          do {                                                                 \
            register u_64 v = value;                                           \
            *((u_8 *) ((ptr)+0)) = (u_8) ((v >>  0) & 0xFF);                   \
            *((u_8 *) ((ptr)+1)) = (u_8) ((v >>  8) & 0xFF);                   \
            *((u_8 *) ((ptr)+2)) = (u_8) ((v >> 16) & 0xFF);                   \
            *((u_8 *) ((ptr)+3)) = (u_8) ((v >> 24) & 0xFF);                   \
            *((u_8 *) ((ptr)+4)) = (u_8) ((v >> 32) & 0xFF);                   \
            *((u_8 *) ((ptr)+5)) = (u_8) ((v >> 40) & 0xFF);                   \
            *((u_8 *) ((ptr)+6)) = (u_8) ((v >> 48) & 0xFF);                   \
            *((u_8 *) ((ptr)+7)) = (u_8) ((v >> 56) & 0xFF);                   \
          } while(0)

#endif

#endif

#endif /* NATIVE_BIG_ENDIAN */

#define GET_BE_BYTE( ptr, value, sign )                                        \
          value = *((const sign ## _8 *) (ptr))

#define GET_LE_BYTE( ptr, value, sign )                                        \
          value = *((const sign ## _8 *) (ptr))

#define SET_BE_BYTE( ptr, value )                                              \
          *((u_8 *) (ptr)) = (u_8) value

#define SET_LE_BYTE( ptr, value )                                              \
          *((u_8 *) (ptr)) = (u_8) value


/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

static int integer2string( IntValue *pInt );
static void string2integer( IntValue *pInt );


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: integer2string
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Nov 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Turn a dec/hex/oct string into an integer.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int integer2string( IntValue *pInt )
{
#ifdef NATIVE_64_BIT_INTEGER
  register u_64 val;
#else
  register u_32 hval, lval, tval, umod, lmod;
#endif

  int stack[20], len, sp;
  char *pStr = pInt->string;

  if( pStr == NULL )
    return 0;

  len = sp = 0;

#ifdef NATIVE_64_BIT_INTEGER

  if( pInt->sign && pInt->value.s < 0 ) {
    val = -pInt->value.s;
    *pStr++ = '-';
    len++;
  }
  else
    val = pInt->value.u;

  while( val > 0 )
    stack[sp++] = val % 10, val /= 10;

#else

  hval = pInt->value.u.h;
  lval = pInt->value.u.l;

  if( pInt->sign && pInt->value.s.h < 0 ) {
    *pStr++ = '-';
    len++;

    if( lval-- == 0 )
      hval--;

    hval = ~hval;
    lval = ~lval;
  }

  while( hval > 0 ) {
    static const u_32 CDIV[10] = {
      0x00000000, 0x19999999, 0x33333333, 0x4CCCCCCC, 0x66666666,
      0x80000000, 0x99999999, 0xB3333333, 0xCCCCCCCC, 0xE6666666
    };
    static const u_32 CMOD[10] =
    { 0U, 6U, 2U, 8U, 4U, 0U, 6U, 2U, 8U, 4U };

    umod  = hval % 10; hval /= 10;
    lmod  = lval % 10; lval /= 10;

    lmod += CMOD[umod];
    tval  = CDIV[umod];

    if( lmod >= 10 )
      lmod -= 10, tval++;

    lval += tval;

    if( lval < tval )
      hval++;

    stack[sp++] = lmod;
  }

  while( lval > 0 )
    stack[sp++] = lval % 10, lval /= 10;

#endif

  len += sp;

  if( sp == 0 )
    *pStr++ = '0';
  else while( sp-- > 0 )
    *pStr++ = (char) ('0' + stack[sp]);

  *pStr = '\0';

  return len;
}

/*******************************************************************************
*
*   ROUTINE: string2integer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Nov 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Turn a dec/hex/oct string into an integer.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void string2integer( IntValue *pInt )
{
  register int val;
  register const char *pStr = pInt->string;

#ifdef NATIVE_64_BIT_INTEGER
  register u_64 iv = 0;
#else
  register u_32 hval = 0, lval = 0;
#endif

  pInt->sign = 0;

  while( isspace( *pStr ) )  /* ignore leading whitespace */
    pStr++;

  switch( *pStr ) {
    default : break;
    case '-': pInt->sign = 1;
    case '+': while( isspace( *++pStr ) );
  }

  if( *pStr == '0' ) {  /* seems to be hex or octal */
    if( *++pStr == 'x' ) {  /* must be hex */
      while( isxdigit( val = *++pStr ) ) {
        if( isdigit( val ) )
          val -= (int) '0';
        else if( isupper( val ) )
          val -= (int) 'A' - 10;
        else
          val -= (int) 'a' - 10;

#ifdef NATIVE_64_BIT_INTEGER

        iv = (iv << 4) | (val & 0xF);

#else

        hval = (hval << 4) | (lval >> 28);
        lval = (lval << 4) | (val & 0xF);

#endif

      }
    }
    else {  /* must be octal */
      while( isdigit( val = *pStr++ ) ) {
        val -= (int) '0';

#ifdef NATIVE_64_BIT_INTEGER

        iv = (iv << 3) | (val & 0x7);

#else

        hval = (hval << 3) | (lval >> 29);
        lval = (lval << 3) | (val & 0x7);

#endif

      }
    }
  }
  else {  /* must be decimal */

#ifdef NATIVE_64_BIT_INTEGER

    while( isdigit( val = *pStr++ ) )
      iv = 10*iv + (val - (int) '0');

#else

    register u_32 temp;

    do {
      if( !isdigit( val = *pStr++ ) )
        goto end_of_string;
  
      lval = 10*lval + (val - (int) '0');
    } while( lval < 429496729 );
  
    while( isdigit( val = *pStr++ ) ) {
      hval = ((hval << 3) | (lval >> 29))
           + ((hval << 1) | (lval >> 31));
  
      lval <<= 1;
  
      temp = lval + (lval << 2);
  
      if( temp < lval )
        hval++;
  
      lval = temp + (int) (val - '0');
  
      if( lval < temp )
        hval++;
    }

#endif

  }

#ifdef NATIVE_64_BIT_INTEGER

  if( pInt->sign )
    pInt->value.s = -iv;
  else
    pInt->value.u = iv;

#else

  end_of_string:

  if( pInt->sign && (hval || lval) ) {
    if( lval-- == 0 )
      hval--;

    pInt->value.u.h = ~hval;
    pInt->value.u.l = ~lval;
  }
  else {
    pInt->value.u.h = hval;
    pInt->value.u.l = lval;
  }

#endif
}

/*******************************************************************************
*
*   ROUTINE: fetch_integer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#ifdef NATIVE_64_BIT_INTEGER

#define FETCH( bo, what )                                                      \
        do {                                                                   \
          if( sign )                                                           \
            GET_ ## bo ## _ ## what ( ptr, pIV->value.s, i );                  \
          else                                                                 \
            GET_ ## bo ## _ ## what ( ptr, pIV->value.u, u );                  \
        } while(0)

#else

#define FETCH( bo, what )                                                      \
        do {                                                                   \
          if( sign ) {                                                         \
            GET_ ## bo ## _ ## what ( ptr, pIV->value.s.l, i );                \
            pIV->value.s.h = ((i_32) pIV->value.s.l) < 0 ? -1 : 0;             \
          }                                                                    \
          else {                                                               \
            GET_ ## bo ## _ ## what ( ptr, pIV->value.u.l, u );                \
            pIV->value.u.h = 0;                                                \
          }                                                                    \
        } while(0)

#endif

void fetch_integer( unsigned size, unsigned sign, const void *src,
                    const ArchSpecs *pAS, IntValue *pIV )
{                                                   
  register const u_8 *ptr = (const u_8 *) src;

  switch( size ) {
    case 1:
      FETCH( BE, BYTE );
      break;

    case 2:
      if( pAS->bo == BO_BIG_ENDIAN )
        FETCH( BE, WORD );
      else
        FETCH( LE, WORD );
      break;

    case 4:
      if( pAS->bo == BO_BIG_ENDIAN )
        FETCH( BE, LONG );
      else
        FETCH( LE, LONG );
      break;

    case 8:
#ifdef NATIVE_64_BIT_INTEGER
      if( pAS->bo == BO_BIG_ENDIAN )
        FETCH( BE, LONGLONG );
      else
        FETCH( LE, LONGLONG );
#else
      if( pAS->bo == BO_BIG_ENDIAN ) {
        GET_BE_LONG( ptr,   pIV->value.u.h, u );
        GET_BE_LONG( ptr+4, pIV->value.u.l, u );
      }
      else {
        GET_LE_LONG( ptr,   pIV->value.u.l, u );
        GET_LE_LONG( ptr+4, pIV->value.u.h, u );
      }
#endif
      break;

    default:
      break;
  }

  pIV->sign = sign;

  if( pIV->string )
    (void) integer2string( pIV );
}

#undef FETCH

/*******************************************************************************
*
*   ROUTINE: store_integer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#ifdef NATIVE_64_BIT_INTEGER

#define STORE( bo, what )                                                      \
        do {                                                                   \
          SET_ ## bo ## _ ## what ( ptr, pIV->value.u );                       \
        } while(0)

#else

#define STORE( bo, what )                                                      \
        do {                                                                   \
          SET_ ## bo ## _ ## what ( ptr, pIV->value.u.l );                     \
        } while(0)

#endif

void store_integer( unsigned size, void *dest,
                    const ArchSpecs *pAS, IntValue *pIV )
{
  register u_8 *ptr = (u_8 *) dest;

  if( pIV->string )
    string2integer( pIV );

  switch( size ) {
    case 1:
      STORE( BE, BYTE );
      break;

    case 2:
      if( pAS->bo == BO_BIG_ENDIAN )
        STORE( BE, WORD );
      else
        STORE( LE, WORD );
      break;

    case 4:
      if( pAS->bo == BO_BIG_ENDIAN )
        STORE( BE, LONG );
      else
        STORE( LE, LONG );
      break;

    case 8:
#ifdef NATIVE_64_BIT_INTEGER
      if( pAS->bo == BO_BIG_ENDIAN )
        STORE( BE, LONGLONG );
      else
        STORE( LE, LONGLONG );
#else
      if( pAS->bo == BO_BIG_ENDIAN ) {
        SET_BE_LONG( ptr,   pIV->value.u.h );
        SET_BE_LONG( ptr+4, pIV->value.u.l );
      }
      else {
        SET_LE_LONG( ptr,   pIV->value.u.l );
        SET_LE_LONG( ptr+4, pIV->value.u.h );
      }
#endif
      break;

    default:
      break;
  }
}

#undef STORE

