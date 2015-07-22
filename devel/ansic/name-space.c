/*
 * This code deals with the C name-space that distinguishes identifiers,
 * enumeration-constants, and typedef-names.
 *
 * It implements just enough of the name-space to distinguish
 * identifiers from typedef-names. With a few more keystrokes, it could
 * also identify enumeration constants, which it does not do just now.
 * There is no code to determine whether a name is doubly defined within
 * a scope, or whether a declaration in an old-style function definition
 * names something in the parameter-list, et cetera.. In other words,
 * it is a "starter kit".
 */

#include "types.h"
#include "hash.h"
#include <stdio.h>
#include "y.tab.h"


#define MAX_NUM_LEVELS 16
#define MAX_LEVEL (MAX_NUM_LEVELS-1)

int scope_level = 0;  /* Counts the number of scopes within the name-space */
int decl_level = 0;   /* For nested struct-declarations */

int idents_only[MAX_NUM_LEVELS]; /* If one, this name-space is not
				  * applicable. Always return IDENTIFIER
				  * in that case.
				  */

declaration decls[MAX_NUM_LEVELS]; /* Declarations in progress. */
hash tables[MAX_NUM_LEVELS];       /* Hash tables, one for each scope */

extern declaration *hash_put();
extern char* emalloc();

name_space_init()
{
    while(scope_level > 0) {
	scope_pop();
    }

    decl_level = 0;

    /* Create the name-space for level zero, with an arbitrary
     * initial table size. It's kind of big, because #include-files
     * usually generate a lot of names.
     */
    hash_init_sized(&tables[scope_level], 512);
}

/*
 * Create a new scope in the identifier/typedef/enum-const
 * name-space.
 */
scope_push()
{
    scope_level++;

    if(scope_level > MAX_LEVEL) {
	fprintf(stderr, "C-parser: Nesting is too deep.\n");
	exit(-1);
    }
    
    /* Initial size is again arbitrary. */
    hash_init_sized(&tables[scope_level], 32 );

}

/*
 * Destroy an old scope in the identifier/typedef/enum-const
 * name-space.
 */
scope_pop()
{

    hash_clean(&tables[scope_level]);
    scope_level--;
}

/*
 * Create a new name-space for a structure declaration.
 */
struct_push()
{
    decl_level++;
}

/*
 * Finish a structure declaration
 */
struct_pop()
{
    decl_level--;
}

/*
 * Look for the name in the name-space, beginning with
 * the outermost scope.
 */
declaration*
find_decl(name)
     char *name;
{
    int look;
    
    for(look = scope_level; look >= 0; look--) {

	declaration *find;

	if((find = hash_get(&tables[look], name)) != 0)
	  return find;
	
    }

    return 0;
}

/*
 * Within this name-space, each defined name has a type,
 * either IDENTIFIER, ENUMERATION_CONSTANT, or TYPEDEF_NAME.
 */
type_of_name(name)
     char* name;
{
      
   declaration *find = find_decl(name);
 
   if(!find)
      return IDENTIFIER;
    else
      switch(find->type) {
      case enum_const:
	  return ENUMERATION_CONSTANT;
      case typename:
	  return TYPEDEF_NAME;
      default:
	  return IDENTIFIER;
      }
}

/*
 * Remember the name of the declarator being defined.
 */
declarator_id(name)
     char* name;
{
    declaration *decl = &decls[decl_level];
    decl->name = name;
}

/*
 * Begin a new declaration with default values.
 */
new_declaration(type)
     enum decl_type type;
{
    declaration *decl = &decls[decl_level];
    decl->decl_type = type;
    decl->type = identifier;
    decl->scope_level = scope_level;
    decl->name = 0;
}

/*
 * Remember that this declaration defines a typename,
 * not an identifier.
 */
set_typedef()
{
    decls[decl_level].type = typename;
}

/*
 * Put a name into the current scope.
 */
static
put_name()
{
    declaration *decl = &decls[decl_level];
    declaration *copy = (declaration*)emalloc(sizeof(declaration));
   
    *copy = *decl;

    if(decl->decl_type == struct_decl) {
      /* Should export the decl to the structure's name-space.
       * ... for now, just boot it.
       */
	free((char*)copy);
	return;
    }

  {
      declaration* prev = hash_put(&tables[scope_level], copy);
      /*
       * If the declaration was already there, we should do
       * the right thing... for now, to heck with it.
       */
      
  }
}

/*  finish the declarator */
direct_declarator()
{
    put_name();
}

/*  finish the declarator */
pointer_declarator()
{
    put_name();
}


/*
 * Turn on typedef_name (and enum-constant) recognition)
 */
td()
{
    idents_only[decl_level] = 0;
}

/*
 * Turn it off.
 */
ntd()
{
    idents_only[decl_level] = 1;
}
