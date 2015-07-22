/*******************************************************************************
*
* HEADER: memalloc
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
* $Snapshot: /Convert-Binary-C/0.01 $
* $Source: /ctlib/util/memalloc.h $
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

/**
 *  \file memalloc.h
 *  \brief Memory allocation and tracing routines
 *
 *  The functions in this file provide an interface to
 *  the standard malloc / free functions, but in addition
 *  you can selectively enable tracing of your memory
 *  allocation. This may be useful to detect memory leaks
 *  or usage of already freed memory blocks.
 *
 *  A Perl script is supplied to analyze the output of
 *  the memory tracing routines.
 *
 *  To enable the tracing capability, the library must be
 *  compiled with the #DEBUG_MEMALLOC preprocessor flag. Then,
 *  you can selectively enable the tracing for each file or
 *  project by using the SetDebugMemAlloc() routine.
 *
 *  The following code shows an example:
 *
 *  \include Alloc.c
 *
 *  Then, a file like this will be written to stdout:
 *
 *  \verbinclude mem_debug.dat
 *
 *  This output is easy to understand. It tells you that
 *
 *  -# in file \c Alloc.c, line 9, there were 16 bytes allocated at address 0x400031C0,
 *  -# in file \c Alloc.c, line 10, address 0x400031C0 was verified,
 *  -# in file \c Alloc.c, line 11, the memory block at address 0x400031C0 was freed,
 *  -# in file \c Alloc.c, line 12, address 0x400031C0 was verified again.
 *
 *  These files usually become very large if you work a lot with
 *  dynamic memory allocation. So it would be rather hard to step
 *  through that file on your own. For that reason, there's a Perl
 *  script called \c check_alloc.pl that will take \c mem_debug.dat
 *  as input and print all errors discovered and summary statistics:
 *
 *  \verbinclude mem_debug.out
 *
 *  As you can see, the last call to AssertValidPtr() caused an error
 *  because the block that was checked has already been freed. The
 *  other output is only useful if you have lots of dynamic memory
 *  allocation, for example:
 *
 *  \verbinclude memdb_large.out
 *
 *  This will tell you that a total of 32404 memory blocks have been
 *  successfully allocated and freed, a maximum of 13305 memory blocks
 *  were in use simultanously, the peak memory usage was 183675 bytes,
 *  the smallest and largest block that were allocated were 2 and 29
 *  bytes in size, respectively, and there were no memory leaks detected.
 *
 */
#ifndef _MEMALLOC_H
#define _MEMALLOC_H

#define DB_MEMALLOC_TRACE    0x00000001
#define DB_MEMALLOC_ASSERT   0x00000002

#ifdef DEBUG_MEMALLOC
void *_MemAlloc( size_t size, char *file, int line );
void  _MemFree( void *p, char *file, int line );
void  _AssertValidPtr( void *p, char *file, int line );
int    SetDebugMemAlloc( void (*dbfunc)(char *, ...), unsigned long dbflags );
#else
void *_MemAlloc( size_t size );
void  _MemFree( void *p );
#endif

/***************************************************************/
/*                       DOCUMENTATION                         */
/***************************************************************/

#ifdef DOXYGEN

/**
 *  Make Alloc() abort when out of memory
 *
 *  Set this preprocessor flag if you want the Alloc()
 *  function to abort if the system runs out of memory.
 */

#define ABORT_IF_NO_MEM

/**
 *  Compile with debugging/tracing support
 */

#define DEBUG_MEMALLOC

/**
 *  Allocate a memory block
 *
 *  Allocates a memory block of \a size bytes. If the files
 *  were compiled with the #ABORT_IF_NO_MEM preprocessor flag,
 *  the function aborts if no memory can be allocated.
 *
 *  \param size           Size of the memory block in bytes.
 *
 *  \return A pointer to the allocated memory block, or NULL
 *          if memory couldn't be allocated.
 */

void *Alloc( size_t size );

/**
 *  Free a memory block
 *
 *  Frees a memory block that has been previously allocated
 *  using the Alloc() function.
 *
 *  \param ptr            Pointer to a previously allocated
 *                        memory block.
 */

void Free( void *ptr );

/**
 *  Trace pointer access.
 *
 *  This may prove useful for checking if \a ptr points to
 *  an existing, previously allocated, not yet freed memory
 *  block.
 *
 *  \param ptr            Pointer to be traced.
 */

void AssertValidPtr( void *ptr );

/**
 *  Configure debugging support.
 *
 *  \param dbfunc         Pointer to a printf() like function
 *                        for writing the debug output.
 *
 *  \param dbflags        Binary ORed debugging flags. Currently,
 *                        you can request memory allocation tracing
 *                        with \c DB_MEMALLOC_TRACE and pointer
 *                        assertions with \c DB_MEMALLOC_ASSERT.
 */

int SetDebugMemAlloc( void (*dbfunc)(char *, ...), unsigned long dbflags );

#else /* !DOXYGEN */

/***************************************************************/
/*                    END OF DOCUMENTATION                     */
/***************************************************************/

#ifdef DEBUG_MEMALLOC

#define Alloc( size )           _MemAlloc( size, __FILE__, __LINE__ )
#define Free( ptr )             _MemFree( ptr, __FILE__, __LINE__ )
#define AssertValidPtr( ptr )   _AssertValidPtr( ptr, __FILE__, __LINE__ )

#else /* !DEBUG_MEMALLOC */

#define Alloc( size )           _MemAlloc( size )
#define Free( ptr )             _MemFree( ptr )
#define AssertValidPtr( ptr )
#define SetDebugMemAlloc( func, flags ) 0

#endif /* DEBUG_MEMALLOC */

#endif /* DOXYGEN */

#endif
