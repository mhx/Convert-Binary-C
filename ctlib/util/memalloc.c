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
* $Date: 2003/10/02 09:56:06 +0100 $
* $Revision: 13 $
* $Snapshot: /Convert-Binary-C/0.48 $
* $Source: /ctlib/util/memalloc.c $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
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

#if defined(DEBUG_MEMALLOC) || (defined(ABORT_IF_NO_MEM) && !defined(NO_SLOW_MEMALLOC_CALLS))

#include "memalloc.h"
#include "ccattr.h"

#ifdef DEBUG_MEMALLOC

#ifdef UTIL_FORMAT_CHECK

# define MEM_DEBUG_FUNC debug_check
static void debug_check( char *str, ... )
            __attribute__(( __format__( __printf__, 1, 2 ), __noreturn__ ));

#else
# define MEM_DEBUG_FUNC gs_dbfunc
#endif

#define DEBUG( flag, out )                                                \
          do {                                                            \
            if( MEM_DEBUG_FUNC && ((DB_MEMALLOC_ ## flag) & gs_dbflags) ) \
              MEM_DEBUG_FUNC out ;                                        \
          } while(0)

static void (*gs_dbfunc)(const char *, ...) = NULL;
static unsigned long gs_dbflags             = 0;

#else /* !DEBUG_MEMALLOC */

#define DEBUG( flag, out )

#endif


#if defined(DEBUG_MEMALLOC) && defined(TRACE_MEMALLOC)

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <assert.h>
#include <limits.h>

#undef ULONG_MAX
#define ULONG_MAX 1000000

#ifndef ULONG_MAX
# define ULONG_MAX ((1<<(8*sizeof(unsigned long)))-1)
#endif

#define BUCKET_SIZE_INCR    4
#define HASH_OFFSET         4
#define HASH_BITS           8
#define HASH_BUCKET( ptr )  ((((unsigned long)(ptr)) >> HASH_OFFSET) & ((1 << HASH_BITS) - 1))

#define TRACE_MSG( msg )    (void) (gs_dbfunc ? gs_dbfunc : trace_msg) msg

#define CHECK_SOFT_ASSERT                                                         \
        do {                                                                      \
          char *str;                                                              \
          if( (str = getenv("MEMALLOC_SOFT_ASSERT")) == NULL || atoi(str) == 0 )  \
            abort();                                                              \
        } while(0)

#define free_slot( p )      do { (p)->ptr = 0; (p)->size = 0; } while(0)

typedef struct {
  const void    *ptr;
  const char    *file;
  int            line;
  size_t         size;
  unsigned long  serial;
} MemTrace;

typedef struct {
  int        size;
  MemTrace  *block;
} MemTraceBucket;

static struct {
  unsigned long alloc;
  unsigned long free;
  unsigned long total_blocks;
  unsigned long total_bytes;
  unsigned long max_total_blocks;
  unsigned long max_total_bytes;
  size_t        min_alloc;
  size_t        max_alloc;
  double        avg_alloc;
} gs_memstat;

static unsigned long  gs_serial = 0;
static MemTraceBucket gs_trace[1<<HASH_BITS];

static void trace_msg( const char *fmt, ... )
{
  va_list l;
  va_start(l, fmt);
  vfprintf(stderr, fmt, l);
  va_end(l);
}

static void trace_leaks( void )
{
  char *str;
  int b, i, level = -1;
  long min_buck, max_buck, empty_buckets = 0;
  unsigned long bytes_used = 0;
  MemTraceBucket *buck;

  assert( gs_memstat.alloc - gs_memstat.free == gs_memstat.total_blocks );

  if( (str = getenv("MEMALLOC_STAT_LEVEL")) != NULL )
    level = atoi(str);

  if( level < 0 && (gs_memstat.total_blocks != 0 || gs_memstat.total_bytes != 0) )
    level = 1;

  if( level >= 1 ) {
    if( gs_serial == ULONG_MAX )
      TRACE_MSG(("*** serial number overflow, results may be inaccurate ***\n"));

    TRACE_MSG(("--------------------------------\n"));

    if( level >= 2 )
      TRACE_MSG((" serials used   : %lu\n", gs_serial));

    TRACE_MSG((" total allocs   : %lu\n", gs_memstat.alloc));
    TRACE_MSG((" total frees    : %lu\n", gs_memstat.free));
    TRACE_MSG((" max mem blocks : %lu\n", gs_memstat.max_total_blocks));
    TRACE_MSG((" max mem usage  : %lu byte%s\n", gs_memstat.max_total_bytes,
                 gs_memstat.max_total_bytes == 1 ? "" : "s"));

    if( gs_memstat.max_total_blocks > 0 ) {
      TRACE_MSG((" smallest block : %d byte%s\n", gs_memstat.min_alloc,
                   gs_memstat.min_alloc == 1 ? "" : "s"));
      TRACE_MSG((" largest block  : %d byte%s\n", gs_memstat.max_alloc,
                   gs_memstat.max_alloc == 1 ? "" : "s"));
      TRACE_MSG((" average block  : %.1f bytes\n",
                   gs_memstat.avg_alloc/(double)gs_memstat.alloc));
    }

    if( gs_memstat.total_blocks > 0 ) {
      TRACE_MSG((" memory leakage : %d byte%s in %d block%s\n",
                   gs_memstat.total_bytes, gs_memstat.total_bytes == 1 ? "" : "s",
                   gs_memstat.total_blocks, gs_memstat.total_blocks == 1 ? "" : "s"
               ));
    }

    TRACE_MSG(("--------------------------------\n"));
  }

  min_buck = max_buck = gs_trace[0].size;

  for( b = 0, buck = &gs_trace[0]; b < sizeof(gs_trace)/sizeof(gs_trace[0]); ++b, ++buck ) {
    if( level >= 3 ) {
      TRACE_MSG(("bucket %d used %d bytes in %d blocks\n",
                 b, buck->size*sizeof(MemTrace), buck->size));
    }

    if( buck->size < min_buck )
      min_buck = buck->size;
    if( buck->size > max_buck )
      max_buck = buck->size;

    if( buck->block != NULL ) {
      assert( buck->size > 0 );
      bytes_used += buck->size*sizeof(MemTrace);

      for( i = 0; i < buck->size; ++i ) {
        MemTrace *p = &buck->block[i];
        if( p->ptr != NULL ) {
          TRACE_MSG(("(%d) leaked %d bytes at %p allocated in %s:%d\n",
                     p->serial, p->size, p->ptr, p->file, p->line));

          gs_memstat.total_blocks--;
          gs_memstat.total_bytes -= p->size;

          free( (void *) p->ptr );
        }
      }

      free( buck->block );
    }
    else {
      assert( buck->size == 0 );
      empty_buckets++;
    }
  }

  if( level >= 2 ) {
    TRACE_MSG(("memalloc tracing used %d bytes in %d buckets (%d empty)\n",
               bytes_used, b, empty_buckets));
    TRACE_MSG(("min/max bucket size was %d/%d blocks\n", min_buck, max_buck));
  }

  assert( gs_memstat.total_blocks == 0 );
  assert( gs_memstat.total_bytes == 0 );
}

static inline MemTrace *get_empty_slot( const void *ptr )
{
  MemTraceBucket *buck;
  MemTrace *p;
  int i, pos = -1;

  assert( ptr != NULL );

  buck = &gs_trace[ HASH_BUCKET(ptr) ];

  for( i = 0; i < buck->size; ++i ) {
    p = &buck->block[i];
    if( p->ptr == ptr )
      return NULL;
    if( pos < 0 && p->ptr == NULL )
      pos = i;
  }

  if( pos < 0 )
    pos = buck->size;

  if( pos >= buck->size ) {
    buck->size  = pos + BUCKET_SIZE_INCR;
    buck->block = realloc( buck->block, buck->size * sizeof(MemTrace) );
    if( buck->block == NULL ) {
      fprintf(stderr, "panic: out of memory in get_empty_slot()\n");
      abort();
    }
    for( p = &buck->block[i = pos]; i < buck->size; ++i, ++p )
      free_slot( p );
  }

  return &buck->block[pos];
}

static inline MemTrace *find_slot( const void *ptr )
{
  MemTraceBucket *buck;
  MemTrace *p;
  int pos;

  buck = &gs_trace[ HASH_BUCKET(ptr) ];

  for( pos = 0; pos < buck->size; ++pos ) {
    p = &buck->block[pos];
    if( p->ptr == ptr )
      return p;
  }

  return NULL;
}

static inline int trace_add( const void *ptr, size_t size, const char *file, int line )
{
  MemTrace *p;

  assert( file != NULL );

  if( ptr == NULL ) {
    if( size == 0 )
      return 1;

    TRACE_MSG(("request for %d bytes failed in %s:%d\n", size, file, line));
    return 0;
  }

  if( (p = get_empty_slot(ptr)) == NULL ) {
    TRACE_MSG(("pointer %p has already been allocated in %s:%d\n", ptr, file, line));
    return 0;
  }

  if( gs_serial == 0 ) {
    gs_memstat.min_alloc = gs_memstat.max_alloc = size;
    atexit( trace_leaks );
  }

  gs_memstat.alloc++;
  gs_memstat.total_blocks++;
  gs_memstat.total_bytes += size;

  if( gs_memstat.total_blocks > gs_memstat.max_total_blocks )
    gs_memstat.max_total_blocks = gs_memstat.total_blocks;

  if( gs_memstat.total_bytes > gs_memstat.max_total_bytes )
    gs_memstat.max_total_bytes = gs_memstat.total_bytes;

  if( size < gs_memstat.min_alloc )
    gs_memstat.min_alloc = size;

  if( size > gs_memstat.max_alloc )
    gs_memstat.max_alloc = size;

  gs_memstat.avg_alloc += (double) size;

  p->ptr    = ptr;
  p->file   = file;
  p->line   = line;
  p->size   = size;
  p->serial = gs_serial;

  if( gs_serial < ULONG_MAX )
    gs_serial++;

  return 1;
}

static inline int trace_del( const void *ptr, const char *file, int line )
{
  MemTrace *p;

  assert( file != NULL );

  if( ptr == NULL ) {
    TRACE_MSG(("trying to free NULL pointer in %s:%d\n", ptr, file, line));
    return 0;
  }

  if( (p = find_slot(ptr)) == NULL ) {
    TRACE_MSG(("pointer %p has not yet been allocated in %s:%d\n", ptr, file, line));
    return 0;
  }

  gs_memstat.free++;
  gs_memstat.total_blocks--;
  gs_memstat.total_bytes -= p->size;

  free_slot( p );

  return 1;
}

static inline int trace_upd( const void *old, const void *ptr, size_t size, const char *file, int line )
{
  MemTrace *p;

  assert( file != NULL );

  if( old != ptr && old != NULL ) {
    if( (p = find_slot(old)) == NULL )
      TRACE_MSG(("pointer %p has not yet been allocated in %s:%d\n", old, file, line));
    else {
      gs_memstat.free++;
      gs_memstat.total_blocks--;
      gs_memstat.total_bytes -= p->size;

      free_slot( p );
    }
  }

  if( ptr == NULL ) {
    if( size == 0 )
      return 1;

    TRACE_MSG(("request for %d bytes failed in %s:%d\n", size, file, line));
    return 0;
  }

  p = NULL;

  if( old == ptr ) {
    if( (p = find_slot(ptr)) == NULL )
      TRACE_MSG(("pointer %p has not yet been allocated in %s:%d\n", ptr, file, line));
  }

  if( p == NULL ) {
    if( (p = get_empty_slot(ptr)) == NULL ) {
      TRACE_MSG(("pointer %p has already been allocated in %s:%d\n", ptr, file, line));
      return 0;
    }
    gs_memstat.alloc++;
    gs_memstat.total_blocks++;
    if( gs_memstat.total_blocks > gs_memstat.max_total_blocks )
      gs_memstat.max_total_blocks = gs_memstat.total_blocks;
  }

  if( gs_serial == 0 ) {
    gs_memstat.min_alloc = gs_memstat.max_alloc = size;
    atexit( trace_leaks );
  }

  gs_memstat.total_bytes += size - p->size;

  if( gs_memstat.total_bytes > gs_memstat.max_total_bytes )
    gs_memstat.max_total_bytes = gs_memstat.total_bytes;

  if( size < gs_memstat.min_alloc )
    gs_memstat.min_alloc = size;

  if( size > gs_memstat.max_alloc )
    gs_memstat.max_alloc = size;

  gs_memstat.avg_alloc += (double) size;

  p->ptr    = ptr;
  p->file   = file;
  p->line   = line;
  p->size   = size;
  p->serial = gs_serial;

  if( gs_serial < ULONG_MAX )
    gs_serial++;

  return 1;
}

static inline int trace_check_ptr( const void *ptr )
{
  assert( ptr != NULL );
  return find_slot(ptr) != NULL;
}

static inline int trace_check_range( const void *ptr, size_t size )
{
  int b, i;
  MemTraceBucket *buck;

  assert( ptr != NULL );

  for( b = 0, buck = &gs_trace[0]; b < sizeof(gs_trace)/sizeof(gs_trace[0]); ++b, ++buck )
    for( i = 0; i < buck->size; ++i ) {
      MemTrace *pmt = &buck->block[i];

      if( pmt->ptr != NULL ) {
        const char *bs = pmt->ptr;
        const char *be = bs + pmt->size;
        const char *cs = ptr;
        const char *ce = cs + size;

        int s_in_b = bs <= cs && cs <= be;
        int e_in_b = bs <= ce && ce <= be;

        if( s_in_b && e_in_b )
          return 1;
      }
    }

  return 0;
}

#else

#define trace_add( ptr, size, file, line )         1
#define trace_upd( old, ptr, size, file, line )    1
#define trace_del( ptr, file, line )               1

#endif /* defined(DEBUG_MEMALLOC) && defined(TRACE_MEMALLOC) */


#ifdef DEBUG_MEMALLOC
void *_memAlloc( register size_t size, char *file, int line )
#else
void *_memAlloc( register size_t size )
#endif
{
  register void *p;

#if defined(DEBUG_MEMALLOC) && defined(AUTOPURGE_MEMALLOC)
  p = malloc( size + sizeof( size_t ) );
#else
  p = malloc( size );
#endif

  abortMEMALLOC( "_memAlloc", size, p );

#if defined(DEBUG_MEMALLOC) && defined(AUTOPURGE_MEMALLOC)
  if( p != NULL ) {
    *((size_t *)p) = size;
    p = (void *)(((size_t *)p)+1);
  }
#endif

  (void) trace_add( p, size, file, line );
  DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, size, (unsigned long)p) );

  return p;
}

#ifdef DEBUG_MEMALLOC
void *_memCAlloc( register size_t nobj, register size_t size, char *file, int line )
#else
void *_memCAlloc( register size_t nobj, register size_t size )
#endif
{
  register void *p;

#if defined(DEBUG_MEMALLOC) && defined(AUTOPURGE_MEMALLOC)
  p = malloc( nobj*size + sizeof( size_t ) );
#else
  p = calloc( nobj, size );
#endif

  abortMEMALLOC( "_memCAlloc", nobj*size, p );

#if defined(DEBUG_MEMALLOC) && defined(AUTOPURGE_MEMALLOC)
  if( p != NULL ) {
    *((size_t *)p) = size;
    p = (void *)(((size_t *)p)+1);
    memset( p, 0, nobj*size );
  }
#endif

  (void) trace_add( p, nobj*size, file, line );
  DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, nobj*size, (unsigned long)p) );

  return p;
}

#ifdef DEBUG_MEMALLOC
void *_memReAlloc( register void *p, register size_t size, char *file, int line )
#else
void *_memReAlloc( register void *p, register size_t size )
#endif
{
#if defined(DEBUG_MEMALLOC) && defined(TRACE_MEMALLOC)
  void *oldp = p;
#endif

#ifdef DEBUG_MEMALLOC
  if( p != NULL )
    DEBUG( TRACE, ("%s(%d):F=%08lX\n", file, line, (unsigned long)p) );
#endif

#if defined(DEBUG_MEMALLOC) && defined(AUTOPURGE_MEMALLOC)
  if( p != NULL ) {
    size_t old_size;

    p = (void *)(((size_t *)p)-1);
    old_size = *((size_t *)p);

    if( old_size > size )
      memset( ((char *)p) + sizeof(size_t) + size, 0xA5, old_size - size );
  }

  if( size != 0 )
    p = realloc( p, size + sizeof( size_t ) );
#else
  p = realloc( p, size );
#endif

  abortMEMALLOC( "_memReAlloc", size, p );

#if defined(DEBUG_MEMALLOC) && defined(AUTOPURGE_MEMALLOC)
  if( p != NULL ) {
    *((size_t *)p) = size;
    p = (void *)(((size_t *)p)+1);
  }
#endif

#ifdef DEBUG_MEMALLOC
  if( size != 0 )
    DEBUG( TRACE, ("%s(%d):A=%d@%08lX\n", file, line, size, (unsigned long)p) );

  (void) trace_upd( oldp, p, size, file, line );
#endif

  return p;
}

#ifdef DEBUG_MEMALLOC

void _memFree( register void *p, char *file, int line )
{
  (void) trace_del( p, file, line );
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

void _assertValidPtr( register void *p, char *file, int line )
{
  DEBUG( ASSERT, ("%s(%d):V=%08lX\n", file, line, (unsigned long)p) );
#ifdef TRACE_MEMALLOC
  if( p == NULL || !trace_check_ptr( p ) ) {
    TRACE_MSG(("Assertion failed: %p is not a valid pointer in %s:%d\n", p, file, line));
    CHECK_SOFT_ASSERT;
  }
#endif
}

void _assertValidBlock( register void *p, register size_t size, char *file, int line )
{
  DEBUG( ASSERT, ("%s(%d):B=%d@%08lX\n", file, line, size, (unsigned long)p) );
#ifdef TRACE_MEMALLOC
  if( p == NULL || !trace_check_range( p, size ) ) {
    TRACE_MSG(("Assertion failed: %p(%d) is not a valid block in %s:%d\n", p, size, file, line));
    CHECK_SOFT_ASSERT;
  }
#endif
}

#ifdef UTIL_FORMAT_CHECK
static void debug_check( char *str __attribute__(( __unused__ )), ... )
{
  fprintf( stderr, "compiled with UTIL_FORMAT_CHECK, please don't run\n" );
  abort();
}
#endif

int SetDebugMemAlloc( void (*dbfunc)(const char *, ...), unsigned long dbflags )
{
  gs_dbfunc  = dbfunc;
  gs_dbflags = dbflags;
  return 1;
}

#endif /* DEBUG_MEMALLOC */

#endif /* !defined(DEBUG_MEMALLOC) && !defined(ABORT_IF_NO_MEM) */
