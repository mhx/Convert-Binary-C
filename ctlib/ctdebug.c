/*******************************************************************************
*
* MODULE: ctdebug.c
*
********************************************************************************
*
* DESCRIPTION: Debugging support
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/04/14 19:59:03 +0100 $
* $Revision: 5 $
* $Snapshot: /Convert-Binary-C/0.40 $
* $Source: /ctlib/ctdebug.c $
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
#include <stdarg.h>
#include <stdlib.h>

/*===== LOCAL INCLUDES =======================================================*/

#include "ctdebug.h"

/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

#ifdef CTYPE_DEBUGGING
void        (*g_CT_dbfunc)(const char *, ...) = NULL;
unsigned long g_CT_dbflags                    = 0;
#endif

/*===== STATIC VARIABLES =====================================================*/

#ifdef CTYPE_DEBUGGING
static void (*gs_vprintf)(const char *, va_list *) = NULL;
#endif

/*===== STATIC FUNCTIONS =====================================================*/

/*===== FUNCTIONS ============================================================*/

#ifdef CTYPE_DEBUGGING

#ifdef CTYPE_FORMAT_CHECK
void CT_dbfunc_check( const char *str __attribute(( __unused__ )), ... )
{
  fprintf( stderr, "compiled with CTYPE_FORMAT_CHECK, please don't run\n" );
  abort();
}
#endif

/*******************************************************************************
*
*   ROUTINE: SetDebugCType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

int SetDebugCType( void (*dbfunc)(const char *, ...),
                   void (*dbvprintf)(const char *, va_list *),
                   unsigned long dbflags )
{
  g_CT_dbfunc  = dbfunc;
  gs_vprintf   = dbvprintf;
  g_CT_dbflags = dbflags;
  return 1;
}

/*******************************************************************************
*
*   ROUTINE: BisonDebugFunc
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

void BisonDebugFunc( void *dummy, const char *fmt, ... )
{
  if( dummy != NULL && gs_vprintf != NULL ) {
    va_list l;
    va_start( l, fmt );
    gs_vprintf( fmt, &l );
    va_end( l );
  }
}
#endif
