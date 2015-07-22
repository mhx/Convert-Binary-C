/*******************************************************************************
*
* MODULE: hash
*
********************************************************************************
*
* DESCRIPTION: Generic hash table routines
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/05/22 16:39:00 +0100 $
* $Revision: 4 $
* $Snapshot: /Convert-Binary-C/0.02 $
* $Source: /ctlib/util/hash.c $
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
#include <stddef.h>
#include <string.h>
#include <assert.h>

#include "memalloc.h"
#include "hash.h"

/*----------*/
/* Typedefs */
/*----------*/
typedef struct {
  int               remain;
  HashNode          pNode;
  HashNode         *pBucket;
} IterState;

struct _HashTable {
  int               count;
  int               size;
  unsigned long     bmask;
  IterState         i;
  HashNode          root[1];
};

#ifdef DEBUG_HASH

#define DEBUG( flag, out )                                       \
          do {                                                   \
            if( gs_dbfunc && ((DB_HASH_ ## flag) & gs_dbflags) ) \
              gs_dbfunc out ;                                    \
          } while(0)

static void (*gs_dbfunc)(char *, ...) = NULL;
static unsigned long gs_dbflags       = 0;

#else /* !DEBUG_HASH */

#define DEBUG( flag, out )

#endif /* DEBUG_HASH */

/* size of fixed part of hash table / hash node */
#define HN_SIZE_FIX offsetof( struct _HashNode, key )
#define HT_SIZE_FIX offsetof( struct _HashTable, root )

/* compare hash values / compute a minimum of two values */
#define CMPHASH( a, b ) ((a) == (b) ? 0 : ((a) < (b) ? -1 : 1))
#define MINIMUM( a, b ) ((a) <= (b) ? a : b)

#if defined DEBUG_HASH && defined NO_TERMINATED_KEYS
#undef NO_TERMINATED_KEYS
#endif

/* normally, one extra byte is allocated per hash key
   to terminate the key with a zero byte              */
#ifdef NO_TERMINATED_KEYS
#define TERMINATOR_LENGTH 0 
#else
#define TERMINATOR_LENGTH 1
#endif


/************************************************************
*
*  G L O B A L   F U N C T I O N S
*
************************************************************/

/**
 *  Constructor
 *
 *  Using the HT_new() function you create an empty hash table.
 *
 *  \param size		Hash table base size. You can specify
 *                      any value between 1 and 16. Depending
 *                      on how many elements you plan to store
 *                      in the hash table, values from 6 to 12
 *                      can be considered useful. The number
 *                      of buckets created is 2^size, so if
 *                      you specify a size of 10, 1024 buckets
 *                      will be created and the empty hash
 *                      table will consume about 4kB of memory.
 *                      However, 1024 buckets will be enough
 *                      to very efficiently manage 100000 hash
 *                      elements.
 *
 *  \return A handle to the newly created hash table.
 *
 *  \see HT_delete() and HT_destroy()
 */

HashTable HT_new( int size )
{
  HashTable table;
  HashNode *pNode;
  int buckets;

  DEBUG( MAIN, ("HT_new( %d )\n", size) );

  assert( size > 0 );
  assert( size <= MAX_HASH_TABLE_SIZE );

  buckets = 1<<size;

  table = Alloc( HT_SIZE_FIX + buckets * sizeof( HashNode ) );

  table->count = 0;
  table->size  = size;
  table->bmask = (unsigned long) (buckets-1);
  pNode        = &table->root[0];

  DEBUG( MAIN, ("created new hash table @ 0x%08X with %d buckets\n", table, buckets) );

  while( buckets-- )
    *pNode++ = NULL;

  return table;
}

/**
 *  Destructor
 *
 *  LL_delete() will free the resources occupied by a
 *  hash table. The function will fail silently if the
 *  associated hash table is not empty.
 *  You can also delete a hash table that is not empty by
 *  using the HT_destroy() function.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \see HT_new() and HT_destroy()
 */

void HT_delete( HashTable table )
{
  DEBUG( MAIN, ("HT_delete( 0x%08X )\n", table) );

  if( table == NULL )
    return;

  AssertValidPtr( table );
  assert( table->count == 0 );

  Free( table );

  DEBUG( MAIN, ("deleted hash table @ 0x%08X\n", table) );
}

/**
 *  Extended Destructor
 *
 *  HT_destroy() will, like HT_delete(), free the resources
 *  occupied by a hash table. In addition, it will call a
 *  destructor function for each element, allowing to free
 *  the resources of the objects stored in the hash table.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param destroy	Pointer to the destructor function
 *			of the objects contained in the hash
 *                      table.
 *                      You can pass NULL if you don't want
 *                      HT_destroy() to call object destructors.
 *
 *  \see HT_new() and HT_delete()
 */

void HT_destroy( HashTable table, HTDestroyFunc destroy )
{
  int buckets;
  HashNode *pNode, node, old;

  DEBUG( MAIN, ("HT_destroy( 0x%08X )\n", table) );

  if( table == NULL )
    return;

  AssertValidPtr( table );

  buckets = 1 << table->size;

  pNode = &table->root[0];

  while( buckets-- ) {
    node = *pNode++;

    while( node ) {
      if( destroy )
        destroy( node->pObj );

      old  = node;
      node = node->next;
      Free( old );
    }
  }

  Free( table );

  DEBUG( MAIN, ("destroyed hash table @ 0x%08X\n", table) );
}

#ifdef DEBUG_HASH

/**
 *  Dump the contents of a hash table
 *
 *  HT_dump() will verbosely list all information related
 *  to a hash table. It will list the contents of all hash
 *  buckets and print all keys, hash sums and value pointers.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \note HT_dump() is not available if the code was compiled
 *        with the \c NDEBUG preprocessor flag.
 */

void HT_dump( const HashTable table )
{
  int i, j, buckets;
  HashNode *pNode, node;

  DEBUG( MAIN, ("HT_dump( 0x%08X )\n", table) );

  assert( table != NULL );
  AssertValidPtr( table );

  if( gs_dbfunc == NULL )
    return;

  gs_dbfunc( "----------------------------------------------------\n" );
  gs_dbfunc( "HashTable @ 0x%08X: %d elements in %d buckets\n",
             table, table->count, 1<<table->size );

  buckets = 1<<table->size;
  pNode = &table->root[0];

  for( i=0; i<buckets; ++i ) {
    gs_dbfunc( "\n  Bucket %d @ 0x%08X:%s\n", i+1, pNode,
               *pNode ? "" : " no elements" );

    node = *pNode++;

    for( j = 1; node != NULL; j++, node = node->next )
      gs_dbfunc( "\n    Element %d @ 0x%08X:\n"
                 "      Hash : 0x%08X\n"
                 "      Key  : [%s] (len=%d)\n"
                 "      Value: 0x%08X\n",
                 j, node, node->hash, node->key, node->keylen, node->pObj );
  }

  gs_dbfunc( "----------------------------------------------------\n" );
}
#endif

/**
 *  Pre-create a hash node
 *
 *  A hash node is the data structure that is stored in a
 *  hash table. You can pre-create a hash node using the
 *  HN_new() function. A pre-created hash node holds
 *  the hash key, but no value. The advantage of such a
 *  pre-created hash node is that no additional resources
 *  need to be allocated if you store the hash node in the
 *  hash table.
 *
 *  \param key		Pointer to the hash key.
 *
 *  \param keylen	Length of the hash key in bytes.
 *                      May be zero if \p key is a zero
 *                      terminated string.
 *
 *  \param hash		Pre-computed hash sum. If this is
 *                      zero, the hash sum is computed.
 *
 *  \return A handle to the new hash node.
 *
 *  \see HN_delete(), HT_storenode() and HT_fetchnode()
 */

HashNode HN_new( const char *key, int keylen, HashSum hash )
{
  HashNode node;

  DEBUG( MAIN, ("HN_new( 0x%08X, %d, 0x%08X )\n", key, keylen, hash) );

  assert( key != NULL );

  if( hash == 0 ) {
    if( keylen )
      HASH_DATA( hash, keylen, key );
    else
      HASH_STR_LEN( hash, key, keylen );
  }

  node = Alloc( HN_SIZE_FIX + keylen + TERMINATOR_LENGTH );

  node->pObj   = NULL;
  node->next   = NULL;
  node->hash   = hash;
  node->keylen = keylen;
  memcpy( node->key, (void *) key, keylen );
#ifndef NO_TERMINATED_KEYS
  node->key[keylen] = '\0';
#endif

  DEBUG( MAIN, ("created new hash node @ 0x%08X with key '%s'\n", node, node->key) );

  return node;
}

/**
 *  Delete a hash node
 *
 *  Free the resources occupied by a hash node that
 *  was previously allocated using the HN_new() function.
 *  You cannot free the resources of a hash node that
 *  is still embedded in a hash table.
 *
 *  \param node		Handle to an existing hash node.
 *
 *  \see HN_new()
 */

void HN_delete( HashNode node )
{
  DEBUG( MAIN, ("HN_delete( 0x%08X )\n", node) );

  if( node == NULL )
    return;

  AssertValidPtr( node );
  assert( node->pObj == NULL );

  Free( node );

  DEBUG( MAIN, ("deleted hash node @ 0x%08X\n", node) );
}

/**
 *  Store a hash node in a hash table
 *
 *  Use this function to store a previously created hash
 *  node in an existing hash table.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param node		Handle to an existing hash node.
 *
 *  \param pObj		Pointer to an object that will be
 *                      stored as a hash value.
 *
 *  \return Nonzero if the node could be stored, zero
 *          if it couldn't be stored.
 *
 *  \see HN_new and HT_fetchnode()
 */

int HT_storenode( const HashTable table, HashNode node, void *pObj )
{
  HashNode *pNode;
  int cmp;

  DEBUG( MAIN, ("HT_storenode( 0x%08X, 0x%08X, 0x%08X )\n", table, node, pObj) );

  assert( table != NULL );
  assert( node  != NULL );

  AssertValidPtr( table );
  AssertValidPtr( node );

  pNode = &table->root[node->hash & table->bmask];

  DEBUG( MAIN, ("key=[%s] len=%d hash=0x%08X bucket=%d/%d\n",
                node->key, node->keylen, node->hash,
                (node->hash & table->bmask) + 1, 1<<table->size) );

  while( *pNode ) {
    DEBUG( MAIN, ("pNode=0x%08X *pNode=0x%08X (key=[%s] len=%d hash=0x%08X)\n",
                 pNode, *pNode, (*pNode)->key, (*pNode)->keylen, (*pNode)->hash) );

    if( (cmp = CMPHASH(node->hash, (*pNode)->hash)) == 0
     && (cmp = memcmp(node->key, (*pNode)->key, MINIMUM(node->keylen, (*pNode)->keylen))) == 0
     && (cmp = node->keylen - (*pNode)->keylen) == 0 ) {
      DEBUG( MAIN, ("key [%s] already in hash, can't store\n", node->key) );
      return 0;
    }

    DEBUG( MAIN, ("cmp: %d\n", cmp) );

    if( cmp < 0 ) {
      DEBUG( MAIN, ("postition to insert new element found\n") );
      break;
    }

    DEBUG( MAIN, ("advancing to next hash element\n") );
    pNode = &(*pNode)->next;
  }

  node->pObj = pObj;
  node->next = *pNode;
  *pNode     = node;

  DEBUG( MAIN, ("successfully stored node [%s] as element #%d into hash table\n",
                node->key, table->count+1) );

  return ++table->count;
}

/**
 *  Fetch a hash node from a hash table
 *
 *  Use this function to fetch a hash node from an
 *  existing hash table. The hash node will be removed
 *  from the hash table. However, the resources for the
 *  hash node will not be freed. The hash node can be
 *  stored in another hash table.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param node		Handle to an existing hash node.
 *
 *  \return Pointer to the object that was stored as hash
 *          value with the hash node.
 *
 *  \see HN_delete() and HT_storenode()
 */

void *HT_fetchnode( const HashTable table, HashNode node )
{
  HashNode *pNode;
  void *pObj;

  DEBUG( MAIN, ("HT_fetchnode( 0x%08X, 0x%08X )\n", table, node) );

  assert( table != NULL );
  assert( node  != NULL );

  AssertValidPtr( table );
  AssertValidPtr( node );

  pNode = &table->root[node->hash & table->bmask];

  DEBUG( MAIN, ("key [%s] hash 0x%08X bucket %d/%d\n",
                node->key, node->hash, (node->hash & table->bmask) + 1, 1<<table->size) );

  while( *pNode && *pNode != node )
    pNode = &(*pNode)->next;

  if( *pNode == NULL ) {
    DEBUG( MAIN, ("hash element not found\n") );
    return NULL;
  }

  pObj   = node->pObj;
  *pNode = node->next;

  node->pObj = NULL;
  node->next = NULL;

  table->count--;

  DEBUG( MAIN, ("successfully fetched node @ 0x%08X (%d nodes still in hash table)\n",
                node, table->count) );

  return pObj;
}

/**
 *  Remove a hash node from a hash table
 *
 *  Use this function to remove a hash node from an
 *  existing hash table. The hash node will be removed
 *  from the hash table and the resources for the
 *  hash node will be freed. This is like calling
 *  HT_fetchnode() and deleting the node with HN_delete().
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param node		Handle to an existing hash node.
 *
 *  \return Pointer to the object that was stored as hash
 *          value with the hash node.
 *
 *  \see HN_delete() and HT_fetchnode()
 */

void *HT_rmnode( const HashTable table, HashNode node )
{
  HashNode *pNode;
  void *pObj;

  DEBUG( MAIN, ("HT_rmnode( 0x%08X, 0x%08X )\n", table, node) );

  assert( table != NULL );
  assert( node  != NULL );

  AssertValidPtr( table );
  AssertValidPtr( node );

  pNode = &table->root[node->hash & table->bmask];

  DEBUG( MAIN, ("key [%s] hash 0x%08X bucket %d/%d\n",
         node->key, node->hash, (node->hash & table->bmask) + 1, 1<<table->size) );

  while( *pNode && *pNode != node )
    pNode = &(*pNode)->next;

  if( *pNode == NULL ) {
    DEBUG( MAIN, ("hash element not found\n") );
    return NULL;
  }

  pObj   = node->pObj;
  *pNode = node->next;

  Free( node );

  table->count--;

  DEBUG( MAIN, ("successfully removed node @ 0x%08X (%d nodes still in hash table)\n",
                node, table->count) );

  return pObj;
}

/**
 *  Store a new key/value pair in a hash table
 *
 *  Use this function to store a new key/value pair
 *  in an existing hash table.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param key		Pointer to the hash key.
 *
 *  \param keylen	Length of the hash key in bytes.
 *                      May be zero if \p key is a zero
 *                      terminated string.
 *
 *  \param hash		Pre-computed hash sum. If this is
 *                      zero, the hash sum is computed.
 *
 *  \param pObj		Pointer to an object that will be
 *                      stored as a hash value.
 *
 *  \return Nonzero if the node could be stored, zero
 *          if it couldn't be stored.
 *
 *  \see HT_fetch() and HT_get()
 */

int HT_store( const HashTable table, const char *key, int keylen, HashSum hash, void *pObj )
{
  HashNode *pNode, node;
  int cmp;

  DEBUG( MAIN, ("HT_store( 0x%08X, 0x%08X, %d, 0x%08X, 0x%08X )\n",
                table, key, keylen, hash, pObj) );

  assert( table != NULL );
  assert( key   != NULL );

  AssertValidPtr( table );

  if( hash == 0 ) {
    if( keylen )
      HASH_DATA( hash, keylen, key );
    else
      HASH_STR_LEN( hash, key, keylen );
  }

  pNode = &table->root[hash & table->bmask];

  DEBUG( MAIN, ("key=[%s] len=%d hash=0x%08X bucket=%d/%d\n",
                key, keylen, hash, (hash & table->bmask) + 1, 1<<table->size) );

  while( *pNode ) {
    DEBUG( MAIN, ("pNode=0x%08X *pNode=0x%08X (key=[%s] len=%d hash=0x%08X)\n",
                  pNode, *pNode, (*pNode)->key, (*pNode)->keylen, (*pNode)->hash) );

    if( (cmp = CMPHASH(hash, (*pNode)->hash)) == 0
     && (cmp = memcmp((void *) key, (*pNode)->key, MINIMUM(keylen, (*pNode)->keylen))) == 0
     && (cmp = keylen - (*pNode)->keylen) == 0 ) {
      DEBUG( MAIN, ("key [%s] already in hash, can't store\n", key) );
      return 0;
    }

    DEBUG( MAIN, ("cmp: %d\n", cmp) );

    if( cmp < 0 ) {
      DEBUG( MAIN, ("postition to insert new element found\n") );
      break;
    }

    DEBUG( MAIN, ("advancing to next hash element\n") );
    pNode = &(*pNode)->next;
  }

  node = Alloc( HN_SIZE_FIX + keylen + TERMINATOR_LENGTH );

  node->next   = *pNode;
  node->pObj   = pObj;
  node->hash   = hash;
  node->keylen = keylen;
  memcpy( node->key, (void *) key, keylen );
#ifndef NO_TERMINATED_KEYS
  node->key[keylen] = '\0';
#endif

  *pNode = node;

  DEBUG( MAIN, ("successfully stored [%s] as element #%d into hash table\n",
                key, table->count+1) );

  return ++table->count;
}

/**
 *  Fetch a value from a hash table
 *
 *  Use this function to fetch a hash value from an
 *  existing hash table. The key/value pair will be
 *  removed from the hash table. The resources occupied
 *  by the hash node used to store the key/value pair
 *  will be freed.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param key		Pointer to a hash key.
 *
 *  \param keylen	Length of the hash key in bytes.
 *                      May be zero if \p key is a zero
 *                      terminated string.
 *
 *  \param hash		Pre-computed hash sum. If this is
 *                      zero, the hash sum is computed.
 *
 *  \return Pointer to the object that was stored as hash
 *          value. NULL if the key doesn't exist.
 *
 *  \see HT_get() and HT_store()
 */

void *HT_fetch( const HashTable table, const char *key, int keylen, HashSum hash )
{
  HashNode *pNode, node;
  int   cmp;
  void *pObj;

  DEBUG( MAIN, ("HT_fetch( 0x%08X, 0x%08X, %d, 0x%08X )\n", table, key, keylen, hash) );

  assert( table != NULL );
  assert( key   != NULL );

  AssertValidPtr( table );

  if( hash == 0 ) {
    if( keylen )
      HASH_DATA( hash, keylen, key );
    else
      HASH_STR_LEN( hash, key, keylen );
  }

  pNode = &table->root[hash & table->bmask];

  DEBUG( MAIN, ("key [%s] hash 0x%08X bucket %d/%d\n",
                key, hash, (hash & table->bmask) + 1, 1<<table->size) );

  while( *pNode ) {
    DEBUG( MAIN, ("node=0x%08X (key=[%s] len=%d hash=0x%08X)\n",
                  *pNode, (*pNode)->key, (*pNode)->keylen, (*pNode)->hash) );

    if( (cmp = CMPHASH(hash, (*pNode)->hash)) == 0
     && (cmp = memcmp((void *) key, (*pNode)->key, MINIMUM(keylen, (*pNode)->keylen))) == 0
     && (cmp = keylen - (*pNode)->keylen) == 0 ) {
      DEBUG( MAIN, ("hash element found\n") );
      break;
    }

    DEBUG( MAIN, ("cmp: %d\n", cmp) );

    if( cmp < 0 ) {
      DEBUG( MAIN, ("cannot find hash element\n") );
      return NULL;
    }

    DEBUG( MAIN, ("advancing to next hash element\n") );
    pNode = &(*pNode)->next;
  }

  if( *pNode == NULL ) {
    DEBUG( MAIN, ("hash element not found\n") );
    return NULL;
  }

  pObj = (*pNode)->pObj;

  node   = *pNode;
  *pNode = node->next;
  Free( node );

  table->count--;

  DEBUG( MAIN, ("successfully fetched [%s] (%d elements still in hash table)\n", key, table->count) );

  return pObj;
}

/**
 *  Get a value from a hash table
 *
 *  Use this function to get a hash value from an
 *  existing hash table. The key/value pair will not be
 *  removed from the hash table.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param key		Pointer to a hash key.
 *
 *  \param keylen	Length of the hash key in bytes.
 *                      May be zero if \p key is a zero
 *                      terminated string.
 *
 *  \param hash		Pre-computed hash sum. If this is
 *                      zero, the hash sum is computed.
 *
 *  \return Pointer to the object that is stored as hash
 *          value. NULL if the key doesn't exist.
 *
 *  \see HT_fetch() and HT_store()
 */

void *HT_get( const HashTable table, const char *key, int keylen, HashSum hash )
{
  HashNode node;
  int cmp;

  DEBUG( MAIN, ("HT_get( 0x%08X, 0x%08X, %d, 0x%08X )\n", table, key, keylen, hash) );

  assert( table != NULL );
  assert( key   != NULL );

  AssertValidPtr( table );

  if( hash == 0 ) {
    if( keylen )
      HASH_DATA( hash, keylen, key );
    else
      HASH_STR_LEN( hash, key, keylen );
  }

  node = table->root[hash & table->bmask];

  DEBUG( MAIN, ("key [%s] hash 0x%08X bucket %d/%d\n",
                key, hash, (hash & table->bmask) + 1, 1<<table->size) );

  while( node ) {
    DEBUG( MAIN, ("node=0x%08X (key=[%s] len=%d hash=0x%08X)\n",
                  node, node->key, node->keylen, node->hash) );

    if( (cmp = CMPHASH(hash, node->hash)) == 0
     && (cmp = memcmp((void *) key, node->key, MINIMUM(keylen, node->keylen))) == 0
     && (cmp = keylen - node->keylen) == 0 ) {
      DEBUG( MAIN, ("hash element found\n") );
      break;
    }

    DEBUG( MAIN, ("cmp: %d\n", cmp) );

    if( cmp < 0 ) {
      DEBUG( MAIN, ("cannot find hash element\n") );
      return NULL;
    }

    DEBUG( MAIN, ("advancing to next hash element\n") );
    node = node->next;
  }

#ifdef DEBUG_HASH
  if( node == NULL )
    DEBUG( MAIN, ("hash element not found\n") );
  else
    DEBUG( MAIN, ("successfully found [%s] in hash table\n", node->key) );
#endif

  return node ? node->pObj : NULL;
}

/**
 *  Check if a key exists in a hash table
 *
 *  Use this function to check if a key is present in an
 *  existing hash table.
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param key		Pointer to a hash key.
 *
 *  \param keylen	Length of the hash key in bytes.
 *                      May be zero if \p key is a zero
 *                      terminated string.
 *
 *  \param hash		Pre-computed hash sum. If this is
 *                      zero, the hash sum is computed.
 *
 *  \return Nonzero if the key exists, zero if it doesn't.
 *
 *  \see HT_get() and HT_fetch()
 */

int HT_exists( const HashTable table, const char *key, int keylen, HashSum hash )
{
  HashNode node;
  int cmp;

  DEBUG( MAIN, ("HT_exists( 0x%08X, 0x%08X, %d, 0x%08X )\n", table, key, keylen, hash) );

  assert( table != NULL );
  assert( key   != NULL );

  AssertValidPtr( table );

  if( hash == 0 ) {
    if( keylen )
      HASH_DATA( hash, keylen, key );
    else
      HASH_STR_LEN( hash, key, keylen );
  }

  node = table->root[hash & table->bmask];

  DEBUG( MAIN, ("key [%s] hash 0x%08X bucket %d/%d\n",
                key, hash, (hash & table->bmask) + 1, 1<<table->size) );

  while( node ) {
    DEBUG( MAIN, ("node=0x%08X (key=[%s] len=%d hash=0x%08X)\n",
                  node, node->key, node->keylen, node->hash) );

    if( (cmp = CMPHASH(hash, node->hash)) == 0
     && (cmp = memcmp((void *) key, node->key, MINIMUM(keylen, node->keylen))) == 0
     && (cmp = keylen - node->keylen) == 0 ) {
      DEBUG( MAIN, ("hash element found\n") );
      return 1;
    }

    DEBUG( MAIN, ("cmp: %d\n", cmp) );

    if( cmp < 0 ) {
      DEBUG( MAIN, ("cannot find hash element\n") );
      return 0;
    }

    DEBUG( MAIN, ("advancing to next hash element\n") );
    node = node->next;
  }

  return 0;
}

/**
 *  Reset hash element iterator
 *
 *  HT_reset() will reset the hash table's internal iterator.
 *  You must call this function prior to using HT_next().
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \see HT_next()
 */

void HT_reset( const HashTable table )
{
  DEBUG( MAIN, ("HT_reset( 0x%08X )\n", table) );

  if( table == NULL )
    return;

  AssertValidPtr( table );
  table->i.remain  = 1 << table->size;
  table->i.pBucket = &table->root[1];
  table->i.pNode   = table->root[0];

  DEBUG( MAIN, ("hash table iterator has been reset\n") );
}

/**
 *  Get next hash element
 *
 *  Get the next key/value pair while iterating through a
 *  hash table. You must have called HT_reset() before and
 *  you mustn't modify the hash table between consecutive
 *  calls to HT_next().
 *
 *  \param table	Handle to an existing hash table.
 *
 *  \param ppKey	Pointer to a variable that will
 *                      receive a pointer to the hash key.
 *                      May be \c NULL if you don't need
 *                      it. You mustn't modify the memory
 *                      pointed to by that pointer.
 *
 *  \param pKeylen	Pointer to a variable that will
 *                      receive the length of the hash key.
 *                      May be \c NULL if you don't need
 *                      it.
 *
 *  \param ppObj	Pointer to a variable that will
 *                      receive a pointer to the object
 *                      that is stored as hash value.
 *                      May be \c NULL if you don't need
 *                      it.
 *
 *  \return Nonzero if another key/value pair could be
 *          retrieved, zero if all elements have been
 *          processed.
 *
 *  \see HT_reset()
 */

int HT_next( const HashTable table, char **ppKey, int *pKeylen, void **ppObj )
{
  HashNode node;

  DEBUG( MAIN, ("HT_next( 0x%08X, 0x%08X, 0x%08X, 0x%08X )\n", table, ppKey, pKeylen, ppObj) );

  if( table == NULL )
    return 0;

  AssertValidPtr( table );

  DEBUG( MAIN, ("i.remain=%d i.pBucket=0x%08X i.pNode=0x%08X\n",
                table->i.remain, table->i.pBucket, table->i.pNode) );

  while( table->i.remain > 0 ) {
    while( (node = table->i.pNode) != NULL ) {
      table->i.pNode = table->i.pNode->next;
      if( ppKey   ) *ppKey   = node->key;
      if( pKeylen ) *pKeylen = node->keylen;
      if( ppObj   ) *ppObj   = node->pObj;
      return 1;
    }
    DEBUG( MAIN, ("going to next bucket\n") );

    table->i.pNode = *table->i.pBucket++;
    table->i.remain--;

    DEBUG( MAIN, ("i.remain=%d i.pBucket=0x%08X i.pNode=0x%08X\n",
                  table->i.remain, table->i.pBucket, table->i.pNode) );
  }

  DEBUG( MAIN, ("iteration through all elements completed\n") );

  return 0;
}

#ifdef DEBUG_HASH
int SetDebugHash( void (*dbfunc)(char *, ...), unsigned long dbflags )
{
  gs_dbfunc  = dbfunc;
  gs_dbflags = dbflags;
  return 1;
}
#endif /* DEBUG_HASH */

