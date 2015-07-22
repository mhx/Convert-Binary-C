/*******************************************************************************
*
* HEADER: list
*
********************************************************************************
*
* DESCRIPTION: Generic routines for a doubly linked ring list
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/23 18:45:50 +0000 $
* $Revision: 6 $
* $Snapshot: /Convert-Binary-C/0.10 $
* $Source: /ctlib/util/list.h $
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

/**
 *  \file list.h
 *  \brief Generic implementation of Linked Lists
 *
 *  The interface is laid out to make the linked lists look
 *  as they were arrays that can be manipulated in multiple
 *  ways. Internally, each array is represented by a doubly
 *  linked ring list, which is quite efficient for most cases.
 *  The following piece of code provides some examples of how
 *  the linked list functions can be used.
 *
 *  \include LinkedList.c
 *
 *  If you're familiar with Perl, you may notice a certain
 *  similarity between these routines and the functions
 *  Perl uses for manipulating arrays. This is absolutely
 *  intended.
 */
#ifndef _UTIL_LIST_H
#define _UTIL_LIST_H

/**
 *  Linked List Handle
 */
typedef struct _LinkedList * LinkedList;

/**
 *  Destructor Function Pointer
 */
typedef void (* LLDestroyFunc)(void *);

/**
 *  Cloning Function Pointer
 */
typedef void * (* LLCloneFunc)(const void *);

/**
 *  Comparison Function Pointer
 */
typedef int (* LLCompareFunc)(const void *, const void *);

LinkedList   LL_new( void );
void         LL_delete( LinkedList list );
void         LL_flush( LinkedList list, LLDestroyFunc destroy );
void         LL_destroy( LinkedList list, LLDestroyFunc destroy );
LinkedList   LL_clone( LinkedList list, LLCloneFunc func );

int          LL_count( const LinkedList list );

void         LL_push( const LinkedList list, void *pObj );
void *       LL_pop( const LinkedList list );

void         LL_unshift( const LinkedList list, void *pObj );
void *       LL_shift( const LinkedList list );

void         LL_insert( const LinkedList list, int item, void *pObj );
void *       LL_extract( const LinkedList list, int item );

void *       LL_get( const LinkedList list, int item );

LinkedList   LL_splice( const LinkedList list, int offset, int length, LinkedList rlist );

void         LL_reset( const LinkedList list );
void *       LL_next( const LinkedList list );
void *       LL_prev( const LinkedList list );

void         LL_sort( const LinkedList list, LLCompareFunc cmp );

/**
 *  Loop over all list elements.
 *
 *  The LL_foreach() macro is actually only a shortcut for the
 *  following loop:
 *
 *  \code
 *  for( LL_reset(list); pObj = LL_next(list); ) {
 *    // do something with pObj
 *  }
 *  \endcode
 *
 *  It is safe to use LL_foreach() even if \a list is NULL.
 *  In that case, the loop won't be executed.
 *
 *  \param pObj		Variable that will receive a pointer
 *                      to the current object.
 *
 *  \param list		Handle to an existing linked list.
 *
 *  \see LL_reset() and LL_next()
 *  \hideinitializer
 */
#define LL_foreach( pObj, list ) \
          for( LL_reset(list); (pObj = LL_next(list)) != NULL; )

#endif
