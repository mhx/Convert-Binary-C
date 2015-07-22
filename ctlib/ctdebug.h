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
* $Date: 2002/05/22 16:38:46 +0100 $
* $Revision: 2 $
* $Snapshot: /Convert-Binary-C/0.06 $
* $Source: /ctlib/ctdebug.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTDEBUG_H
#define _CTDEBUG_H

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdarg.h>

/*===== LOCAL INCLUDES =======================================================*/

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

#define CT_DEBUG( flag, out )                                    \
          do {                                                   \
            if( DEBUG_FLAG( flag ) )                             \
              g_CT_dbfunc out ;                                  \
          } while(0)

#else

#define CT_DEBUG( flag, out )

#endif

/*===== TYPEDEFS =============================================================*/

/*===== FUNCTION PROTOTYPES ==================================================*/

#ifdef CTYPE_DEBUGGING
extern void (*g_CT_dbfunc)(char *, ...);
extern unsigned long g_CT_dbflags;
#endif

#ifdef CTYPE_DEBUGGING
int SetDebugCType( void (*dbfunc)(char *, ...), void (*dbvprintf)(char *, va_list),
                   unsigned long dbflags );
void BisonDebugFunc( void *dummy, char *fmt, ... );
#else
#define SetDebugCType( func, flags ) 0
#endif

#endif
