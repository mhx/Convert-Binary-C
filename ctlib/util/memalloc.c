/*******************************************************************************
*
* MODULE: memalloc
*
********************************************************************************
*
* DESCRIPTION: Memory allocation and tracing routines
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/04/15 22:26:47 +0100 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.02 $
* $Source: /ctlib/util/memalloc.c $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of either the Artistic License or the
* GNU General Public License as published by the Free Software
* Foundation; either version 2 of the License, or (at your option)
* any later version.
*
* THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
* IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
* WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
*
*******************************************************************************/

#include <stdio.h>
#include <stdlib.h>

#include "memalloc.h"

#ifdef DEBUG_MEMALLOC

#define DEBUG( flag, out )                                         \
          if( gs_dbfunc && ((DB_MEMALLOC_ ## flag) & gs_dbflags) ) \
            gs_dbfunc out

static void (*gs_dbfunc)(char *, ...) = NULL;
static unsigned long gs_dbflags       = 0;

#else /* !DEBUG_MEMALLOC */

#define DEBUG( flag, out )

#endif

/************************************************************
*
*  G L O B A L   F U N C T I O N S
*
************************************************************/

/*
 *  MemAlloc
 *
 *  Allocate memory and abort() on failure.
 *  TODO: possibly we can do something better than abort()...
 */

#ifdef DEBUG_MEMALLOC
void *_MemAlloc( register size_t size, char *file, int line )
#else
void *_MemAlloc( register size_t size )
#endif
{
  register void *p;

  p = malloc( size );

#ifdef ABORT_IF_NO_MEM
  if( p == NULL ) {
    fprintf(stderr, "memalloc: out of memory!\n");
    abort();
  }
#endif

  DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, size, (unsigned long)p) );

  return p;
}

/*
 *  MemFree
 *
 *  Free allocated memory.
 */

#ifdef DEBUG_MEMALLOC
void _MemFree( register void *p, char *file, int line )
#else
void _MemFree( register void *p )
#endif
{
  DEBUG( TRACE, ("%s(%d):F=%08lX\n", file, line, (unsigned long)p) );

  if( p )
    free( p );
}

#ifdef DEBUG_MEMALLOC
void _AssertValidPtr( register void *p, char *file, int line )
{
  DEBUG( ASSERT, ("%s(%d):V=%08lX\n", file, line, (unsigned long)p) );
}

int SetDebugMemAlloc( void (*dbfunc)(char *, ...), unsigned long dbflags )
{
  gs_dbfunc  = dbfunc;
  gs_dbflags = dbflags;
  return 1;
}
#endif /* DEBUG_MEMALLOC */

