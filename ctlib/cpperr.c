/*******************************************************************************
*
* MODULE: cpperr.c
*
********************************************************************************
*
* DESCRIPTION: Error reporting for the preprocessor
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/04/17 13:39:03 +0100 $
* $Revision: 7 $
* $Snapshot: /Convert-Binary-C/0.41 $
* $Source: /ctlib/cpperr.c $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

/*===== LOCAL INCLUDES =======================================================*/

#include "cpperr.h"

#include "ucpp/cpp.h"
#include "ucpp/mem.h"


/*===== DEFINES ==============================================================*/

#define INIT_CHECK                                                             \
          do {                                                                 \
            if( !initialized ) {                                               \
              fprintf(stderr, "FATAL: print functions have not been set!\n");  \
              abort();                                                         \
            }                                                                  \
          } while(0)

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

static int initialized = 0;
static PrintFunctions F;

/*===== STATIC FUNCTIONS =====================================================*/

/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: set_print_functions
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
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

void set_print_functions( PrintFunctions *pPF )
{
  if( pPF->newstr == NULL ||
      pPF->scatf  == NULL ||
      pPF->vscatf == NULL ||
      pPF->warn   == NULL ||
      pPF->error  == NULL ||
      pPF->fatal  == NULL ) {
    fprintf( stderr, "FATAL: all print functions must be set!\n" );
    abort();
  }

  F = *pPF;
  initialized = 1;
}

/*******************************************************************************
*
*   ROUTINE: ucpp_ouch
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
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

void ucpp_ouch( char *fmt, ... )
{
  va_list ap;
  void *str;

  INIT_CHECK;

  va_start( ap, fmt );
  str = F.newstr();
  F.scatf( str, "%s: (FATAL) ", current_filename );
  F.vscatf( str, fmt, &ap );
  va_end( ap );

  F.fatal( str );
}

/*******************************************************************************
*
*   ROUTINE: ucpp_error
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
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

void ucpp_error( long line, char *fmt, ... )
{
  va_list ap;
  void *str;

  INIT_CHECK;

  va_start( ap, fmt );

  str = F.newstr();

  if( line > 0 )
    F.scatf( str, "%s, line %ld: ", current_filename, line );
  else if( line == 0 )
    F.scatf( str, "%s: ", current_filename );

  F.vscatf( str, fmt, &ap );

  if( line >= 0 ) {
    struct stack_context *sc = report_context();
    size_t i;

    for( i = 0; sc[i].line >= 0; i++ )
      F.scatf( str, "\n\tincluded from %s:%ld",
               sc[i].long_name ? sc[i].long_name : sc[i].name,
               sc[i].line );

    freemem( sc );
  }

  va_end( ap );

  F.error( str );
}

/*******************************************************************************
*
*   ROUTINE: ucpp_warning
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
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

void ucpp_warning( long line, char *fmt, ... )
{
  va_list ap;
  void *str;

  INIT_CHECK;

  va_start( ap, fmt );

  str = F.newstr();

  if( line > 0 )
    F.scatf( str, "%s, line %ld: (warning) ",
             current_filename, line);
  else if (line == 0)
    F.scatf( str, "%s: (warning) ", current_filename);
  else
    F.scatf( str, "(warning) ");

  F.vscatf( str, fmt, &ap );

  if( line >= 0 ) {
    struct stack_context *sc = report_context();
    size_t i;

    for( i = 0; sc[i].line >= 0; i++ )
      F.scatf( str, "\n\tincluded from %s:%ld",
               sc[i].long_name ? sc[i].long_name : sc[i].name,
               sc[i].line );
    freemem( sc );
  }

  va_end( ap );

  F.warn( str );
}

