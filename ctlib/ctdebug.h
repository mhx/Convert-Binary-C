/*******************************************************************************
*
* HEADER: ctdebug.h
*
********************************************************************************
*
* DESCRIPTION: Debugging support
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2004/03/22 19:37:56 +0000 $
* $Revision: 9 $
* $Snapshot: /Convert-Binary-C/0.51 $
* $Source: /ctlib/ctdebug.h $
*
********************************************************************************
*
* Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_CTDEBUG_H
#define _CTLIB_CTDEBUG_H

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdarg.h>

/*===== LOCAL INCLUDES =======================================================*/

#include "util/ccattr.h"

/*===== DEFINES ==============================================================*/

#define DB_CTYPE_MAIN    0x00000001
#define DB_CTYPE_PARSER  0x00000002
#define DB_CTYPE_CLEXER  0x00000004
#define DB_CTYPE_YACC    0x00000008
#define DB_CTYPE_PRAGMA  0x00000010
#define DB_CTYPE_CTLIB   0x00000020
#define DB_CTYPE_HASH    0x00000040
#define DB_CTYPE_TYPE    0x00000080

#ifdef CTYPE_DEBUGGING

#define DEBUG_FLAG( flag )                                       \
          (g_CT_dbfunc && ((DB_CTYPE_ ## flag) & g_CT_dbflags))

#ifdef CTYPE_FORMAT_CHECK
# define CTYPE_DEBUG_FUNC CT_dbfunc_check
#else
# define CTYPE_DEBUG_FUNC g_CT_dbfunc
#endif

#define CT_DEBUG( flag, out )                                    \
          do {                                                   \
            if( DEBUG_FLAG( flag ) )                             \
              CTYPE_DEBUG_FUNC out ;                             \
          } while(0)

#else

#define CT_DEBUG( flag, out )   (void) 0

#endif

/*===== TYPEDEFS =============================================================*/

/*===== FUNCTION PROTOTYPES ==================================================*/

#ifdef CTYPE_DEBUGGING
extern void (*g_CT_dbfunc)(const char *, ...);
extern unsigned long g_CT_dbflags;
#endif

#ifdef CTYPE_DEBUGGING

# ifdef CTYPE_FORMAT_CHECK
void CT_dbfunc_check( const char *str, ... )
     __attribute__(( __format__( __printf__, 1, 2 ), __noreturn__ ));
# endif

int SetDebugCType( void (*dbfunc)(const char *, ...),
                   void (*dbvprintf)(const char *, va_list *),
                   unsigned long dbflags );

void BisonDebugFunc( void *dummy, const char *fmt, ... );

#else

# define SetDebugCType( func, flags ) 0

#endif

#endif
