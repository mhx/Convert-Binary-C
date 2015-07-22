/*******************************************************************************
*
* MODULE: integer.c
*
********************************************************************************
*
* DESCRIPTION: 64-bit integer support
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <ctype.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "integer.h"
#include "ctdebug.h"


/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: integer2decstr
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Turn an integer object into a decimal string.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

int str2integer( const INTEGER *pInt, char *pStr, int buflen )
{

}

/*******************************************************************************
*
*   ROUTINE: str2integer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Turn a dec/hex/oct string into an integer object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

int str2integer( const char *pStr, INTEGER *pInt )
{
  register int val;
  u_64 iv;

#ifndef NATIVE_64_BIT_INTEGER
  register u_32 hval=0, lval=0;
#endif

  if( pStr == NULL || pInt == NULL )
    return 0;

  while( isspace( *pStr ) )  /* ignore leading whitespace */
    pStr++;

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
  
      lval = temp + (int) (*src++ - '0');
  
      if( lval < temp )
        hval++;
    }

#endif

  }

#ifndef NATIVE_64_BIT_INTEGER
  end_of_string:

  iv.h = hval;
  iv.l = lval;
#endif

  /* process suffix (if any) */


}

