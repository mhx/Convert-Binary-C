
typedef struct
{
  declaration **hash_table;  
  int size;
  int max_entries;
  int mask;
  int num_entries;
}hash;

declaration*
hash_get();
