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
* $Date: 2003/01/23 18:43:21 +0000 $
* $Revision: 4 $
* $Snapshot: /Convert-Binary-C/0.11 $
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
void        (*g_CT_dbfunc)(char *, ...)    = NULL;
unsigned long g_CT_dbflags                 = 0;
#endif

/*===== STATIC VARIABLES =====================================================*/

#ifdef CTYPE_DEBUGGING
static void (*gs_vprintf)(char *, va_list *) = NULL;
#endif

/*===== STATIC FUNCTIONS =====================================================*/

/*===== FUNCTIONS ============================================================*/

#ifdef CTYPE_DEBUGGING

#ifdef CTYPE_FORMAT_CHECK
void CT_dbfunc_check( char *str __attribute(( __unused__ )), ... )
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

int SetDebugCType( void (*dbfunc)(char *, ...), void (*dbvprintf)(char *, va_list *),
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

void BisonDebugFunc( void *dummy, char *fmt, ... )
{
  if( dummy != NULL && gs_vprintf != NULL ) {
    va_list l;
    va_start( l, fmt );
    gs_vprintf( fmt, &l );
    va_end( l );
  }
}
#endif
