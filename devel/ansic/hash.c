/*
 * These are hash-routines from a standard library, stripped down
 * and specialized. The search loops look like they might spin
 * forever, but they proveably terminate due to an algebraic property
 * of the REHASH function. I don't want to go into it now. Trust me.
 */

#include "types.h"
#include "hash.h"

extern char* emalloc();

static str_hash();
static declaration **new_table();
static int round_up_to_pwr2();

hash_init_sized(obj, initial_table_size)
     hash* obj;
{
    if(initial_table_size < 4) initial_table_size = 4;
    obj->size = round_up_to_pwr2(initial_table_size);
    obj->num_entries = 0;
    obj->max_entries = obj->size/2 - 1;
    obj->mask = obj->size - 1;
    obj->hash_table = new_table(obj->size);
}

hash_clean(obj)
  hash* obj;
{
    int i;
    declaration **ht = obj->hash_table;
    
    for(i = 0; i < obj->size; i++) {
	declaration *dc = ht[i];
	if(dc) {
	    free((char*)dc->name);
	    free((char*)dc);
	}
    }

    free((char*)obj->hash_table);
}
 

static void hash_overflow();

#define HASH(cont) ((str_hash(cont)) & obj->mask )
#define REHASH(num)  (((((num)+1)*3) & obj->mask) )

/* Put a new entry into the table. If there was previously an
 * equivalent entry in the table, return it.
 * If there was not, return NULL.
 */

declaration*
hash_put(obj, entry )
     hash* obj;
     declaration *entry;
{

    int bucket_number;
    declaration **bucket;
    
    bucket_number = HASH(entry->name);
    
    while(1)  {

	bucket = obj->hash_table + bucket_number;
	
	if ( *bucket == (declaration*)0 )  { 
	    *bucket = entry;
	    obj->num_entries++;
	    if ( obj->num_entries > obj->max_entries )
	      hash_overflow(obj);
	    return (declaration*)0;  /* <======== added new entry */
      }
      
      if ( strcmp( entry->name, (*bucket)->name ) != 0) { 
	  bucket_number = REHASH(bucket_number);
	  continue; /* <====== search some more (collision) */
      }
	
	/* Found old declaration. Replace. */
      { 
	  declaration *old = *bucket;
	  *bucket = entry;
	  return old; /* <============== replaced entry */
      }
	
    }
    
}
 

/* Find an equivalent entry.  If there is none, return NULL.
 * Do not change the table.
 */

declaration*
hash_get(obj, name)
     hash* obj;
     char* name;
{

   int bucket_number;
   declaration** bucket;

   bucket_number = HASH(name);

   while(1)    {
       bucket = obj->hash_table + bucket_number;
       
       if ( *bucket == (declaration*)0 ) { 
	  return (declaration*)0; /* <====== entry not found */
	}
      
       if ( strcmp( name, (*bucket)->name) != 0)	{ 
	   bucket_number = REHASH(bucket_number);
	   continue; /* <====== search some more (collision) */
       }
       
       return *bucket; /* <====== found old declaration */
   }
   
}
 

/* private routine doubles the size of the table.
 */

static void
hash_overflow(obj)
   hash* obj;
{
  declaration** old_hash = obj->hash_table;
  int old_size = obj->size;
  int recno;
  
  obj->max_entries = obj->size - 1;
  obj->size= obj->size * 2;
  obj->mask= obj->size - 1;
  obj->hash_table = new_table(obj->size);
  
  /* Take everything that was in the old table, and put it
   ** into the new one.
   */
  
  for (recno = 0; recno < old_size; recno++) {
      declaration **mem = old_hash + recno;
      if ( *mem != 0 ) { 
	  int bucket_number = HASH((*mem)->name);
	  while(1) {
	      declaration** bucket = obj->hash_table + bucket_number;
	      if ( *bucket == 0 ) { 
		  *bucket = *mem;
		  break; /* <==== copied it */
	      }
	      
	      /* search some more */
	      bucket_number = REHASH(bucket_number);
	      
	  }
      }
  }
  
  free((char*)old_hash);
  
}

 

/* private routine creates new hash-table.
 */

static
declaration**
new_table(size)
{
    
    declaration** table =
      (declaration**)emalloc(sizeof(declaration)*size);
    declaration** cursor = table;
    declaration** end = table+size;
    while(cursor < end)  *cursor ++ = 0;
    
    return table;
}



static int
round_up_to_pwr2(initial_table_size)
     int initial_table_size;
{
    int size = 4; /* algorithm does not work with 1 or 2 */
    
    while(size < initial_table_size ) {
	size*= 2;
    }
    return size;
}



static
str_hash(str)
     char *str;
{
    int retval = 0;
    while(*str) retval += retval + (unsigned char)(*str++);
    return retval;
}

