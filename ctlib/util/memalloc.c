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
* $Date: 2002/10/02 11:41:24 +0100 $
* $Revision: 3 $
* $Snapshot: /Convert-Binary-C/0.06 $
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

#ifdef AUTOPURGE_MEMALLOC
  p = malloc( size + sizeof( size_t ) );
#else
  p = malloc( size );
#endif

#ifdef ABORT_IF_NO_MEM
  if( p == NULL ) {
    fprintf(stderr, "memalloc: out of memory!\n");
    abort();
  }
#endif

#ifdef AUTOPURGE_MEMALLOC
  if( p != NULL ) {
    *((size_t *)p) = size;
    p = (void *)(((size_t *)p)+1);
  }
#endif

  DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, size, (unsigned long)p) );

  return p;
}

/*
 *  MemCAlloc
 *
 *  Allocate memory and abort() on failure.
 *  Initializes memory with zeroes.
 *  TODO: possibly we can do something better than abort()...
 */

#ifdef DEBUG_MEMALLOC
void *_MemCAlloc( register size_t nobj, register size_t size, char *file, int line )
#else
void *_MemCAlloc( register size_t nobj, register size_t size )
#endif
{
  register void *p;

#ifdef AUTOPURGE_MEMALLOC
  p = malloc( nobj*size + sizeof( size_t ) );
#else
  p = calloc( nobj, size );
#endif

#ifdef ABORT_IF_NO_MEM
  if( p == NULL ) {
    fprintf(stderr, "memcalloc: out of memory!\n");
    abort();
  }
#endif

#ifdef AUTOPURGE_MEMALLOC
  if( p != NULL ) {
    *((size_t *)p) = size;
    p = (void *)(((size_t *)p)+1);
    memset( p, 0, nobj*size );
  }
#endif

  DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, nobj*size, (unsigned long)p) );

  return p;
}

/*
 *  MemReAlloc
 *
 *  Reallocate memory and abort() on failure.
 *  TODO: possibly we can do something better than abort()...
 */

#ifdef DEBUG_MEMALLOC
void *_MemReAlloc( register void *p, register size_t size, char *file, int line )
#else
void *_MemReAlloc( register void *p, register size_t size )
#endif
{
#ifdef DEBUG_MEMALLOC
  if( p != NULL )
    DEBUG( TRACE, ("%s(%d):F=%08lX\n", file, line, (unsigned long)p) );
#endif

#ifdef AUTOPURGE_MEMALLOC
  if( p != NULL ) {
    size_t old_size;

    p = (void *)(((size_t *)p)-1);
    old_size = *((size_t *)p);

    if( old_size > size )
      memset( p + sizeof(size_t) + size, 0xA5, old_size - size );
  }

  if( size != 0 )
    p = realloc( p, size + sizeof( size_t ) );
#else
  p = realloc( p, size );
#endif

#ifdef ABORT_IF_NO_MEM
  if( p == NULL ) {
    fprintf(stderr, "memrealloc: out of memory!\n");
    abort();
  }
#endif

#ifdef AUTOPURGE_MEMALLOC
  if( p != NULL ) {
    *((size_t *)p) = size;
    p = (void *)(((size_t *)p)+1);
  }
#endif

#ifdef DEBUG_MEMALLOC
  if( size != 0 )
    DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, size, (unsigned long)p) );
#endif

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

  if( p ) {
#ifdef AUTOPURGE_MEMALLOC
    size_t size;
    p = (void *)(((size_t *)p)-1);
    size = *((size_t *)p);
    memset( p, 0xA5, size + sizeof( size_t ) );
#endif
    free( p );
  }
}

#ifdef DEBUG_MEMALLOC
void _AssertValidPtr( register void *p, char *file, int line )
{
  DEBUG( ASSERT, ("%s(%d):V=%08lX\n", file, line, (unsigned long)p) );
}

void _AssertValidBlock( register void *p, register size_t size, char *file, int line )
{
  DEBUG( ASSERT, ("%s(%d):B=%d@%08lX\n", file, line, size, (unsigned long)p) );
}

int SetDebugMemAlloc( void (*dbfunc)(char *, ...), unsigned long dbflags )
{
  gs_dbfunc  = dbfunc;
  gs_dbflags = dbflags;
  return 1;
}
#endif /* DEBUG_MEMALLOC */

