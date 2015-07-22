/*******************************************************************************
*
* MODULE: ctparse.c
*
********************************************************************************
*
* DESCRIPTION: Parser interface routines
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/11/25 11:46:35 +0000 $
* $Revision: 9 $
* $Snapshot: /Convert-Binary-C/0.04 $
* $Source: /ctlib/ctparse.c $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "ctparse.h"
#include "ctdebug.h"
#include "fileinfo.h"
#include "parser.h"
#include "ucpp/cpp.h"
#include "util/memalloc.h"

/* for report_leaks() */
#ifdef MEM_DEBUG
#include "ucpp/mem.h"
#endif


/*===== DEFINES ==============================================================*/

#if defined MSDOS || defined WIN32
#define SYSTEM_DIRECTORY_DELIMITER '\\'
#define IS_NON_SYSTEM_DIR_DELIM( c ) ( (c) == '/' )
#else
#define SYSTEM_DIRECTORY_DELIMITER '/'
#define IS_NON_SYSTEM_DIR_DELIM( c ) ( (c) == '\\' )
#endif

#define IS_ANY_DIRECTORY_DELIMITER( c ) ( (c) == '/' || (c) == '\\' )

#define BUFFER_NAME "[buffer]"

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

static void GetPathName( char *buf, char *dir, char *file );
static void UpdateStruct( CParseConfig *pCPC, Struct *pStruct );


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*******************************************************************************
*
*   ROUTINE: UpdateStruct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void UpdateStruct( CParseConfig *pCPC, Struct *pStruct )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  unsigned           size, align, alignment;
  u_32               flags;

  CT_DEBUG( CTLIB, ("UpdateStruct( %s ), got %d struct declaration(s)",
            pStruct->identifier[0] ? pStruct->identifier : "<no-identifier>",
            LL_count(pStruct->declarations)) );

  if( pStruct->declarations == NULL ) {
    CT_DEBUG( CTLIB, ("no struct declarations in UpdateStruct") );
    return;
  }

  alignment = pStruct->pack ? pStruct->pack : pCPC->alignment;

  LL_foreach( pStructDecl, pStruct->declarations ) {

    CT_DEBUG( CTLIB, ("%d declarators in struct declaration, tflags=0x%08X ptr=0x%08X",
              LL_count(pStructDecl->declarators), pStructDecl->type.tflags,
              pStructDecl->type.ptr) );

    LL_foreach( pDecl, pStructDecl->declarators ) {

      CT_DEBUG( CTLIB, ("current declarator [%s]",
                pDecl->identifier[0] ? pDecl->identifier : "<no-identifier>") );

      GetTypeInfo( pCPC, &pStructDecl->type, pDecl, &size, &align, NULL, &flags );
      CT_DEBUG( CTLIB, ("declarator size=%d, align=%d, flags=0x%08X", size, align, flags) );

      if( (flags & T_HASBITFIELD) || pDecl->bitfield_size >= 0 ) {
        CT_DEBUG( CTLIB, ("found bitfield '%s' in '%s %s'",
                  pDecl->identifier[0] ? pDecl->identifier : "<no-identifier>",
                  pStruct->tflags & T_STRUCT ? "struct" : "union",
                  pStruct->identifier[0] ? pStruct->identifier : "<no-identifier>") );

        pStruct->tflags |= T_HASBITFIELD;
      }

      if( flags & T_UNSAFE_VAL ) {
        CT_DEBUG( CTLIB, ("unsafe values in '%s %s'",
                  pStruct->tflags & T_STRUCT ? "struct" : "union",
                  pStruct->identifier[0] ? pStruct->identifier : "<no-identifier>") );

        pStruct->tflags |= T_UNSAFE_VAL;
      }

      pDecl->size = size;

      if( align > alignment )
        align = alignment;

      if( align > pStruct->align )
        pStruct->align = align;

      if( pStruct->tflags & T_STRUCT ) {
        if( pStruct->size % align )
          pStruct->size += align - pStruct->size % align;

        pDecl->offset = pStruct->size;
        pStruct->size += size;
      }
      else /* T_UNION */ {
        pDecl->offset = 0;

        if( size > pStruct->size )
          pStruct->size = size;
      }
    }
  }

  if( pStruct->size % pStruct->align )
    pStruct->size += pStruct->align - pStruct->size % pStruct->align;

  CT_DEBUG( CTLIB, ("UpdateStruct( %s ): size=%d, align=%d",
            pStruct->identifier[0] ? pStruct->identifier : "<no-identifier>",
            pStruct->size, pStruct->align) );
}

/*******************************************************************************
*
*   ROUTINE: GetPathName
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void GetPathName( char *buf, char *dir, char *file )
{
  int len = 0;

  if( dir ) {
    strcpy( buf, dir );
    len = strlen( buf );

    if( !IS_ANY_DIRECTORY_DELIMITER( buf[len-1] ) )
      buf[len++] = SYSTEM_DIRECTORY_DELIMITER;
  }

  strcpy( buf+len, file );

  for( ; *buf; buf++ )
    if( IS_NON_SYSTEM_DIR_DELIM( *buf ) )
      *buf = SYSTEM_DIRECTORY_DELIMITER;
}


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: ParseBuffer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

int ParseBuffer( char *filename, Buffer *pBuf, CParseInfo *pCPI, CParseConfig *pCPC )
{
  int         rval;
  LinkedList  list;
  char       *str;
  ParserState state;
  FILE       *infile;

#ifdef CTYPE_DEBUGGING
  int         count;
#ifdef YYDEBUG
  extern int c_debug, pragma_debug;
  c_debug = pragma_debug = DEBUG_FLAG( YACC ) ? 1 : 0;
#endif
#endif

  CT_DEBUG( CTLIB, ("ctparse::ParseBuffer( %s, 0x%08X, 0x%08X, 0x%08X )",
            filename ? filename : "NULL", pBuf, pCPI, pCPC) );

  /*----------------------------*/
  /* Try to open the input file */
  /*----------------------------*/

  infile = NULL;

  if( filename != NULL ) {
    char file[512];

    GetPathName( file, NULL, filename );

    CT_DEBUG( CTLIB, ("Trying \"%s\"...", file) );

    infile = fopen( file, "r" );

    if( infile == NULL ) {
      LL_foreach( str, pCPC->includes ) {
        GetPathName( file, str, filename );

        CT_DEBUG( CTLIB, ("Trying \"%s\"...", file) );

        if( (infile = fopen( file, "r" )) != NULL )
          break;
      }

      if( infile == NULL ) {
        FormatError( pCPI, "cannot find input file \"%s\"", filename );
        return 0;
      }
    }
  }

  /*------------------------------*/
  /* Initialize parser structures */
  /*------------------------------*/

  state.pCPC = pCPC;
  state.curEnumList = NULL;

  if( pCPI->enums == NULL && pCPI->structs == NULL &&
      pCPI->typedef_lists == NULL ) {
    CT_DEBUG( CTLIB, ("creating linked lists") );

    pCPI->enums         = LL_new();
    pCPI->structs       = LL_new();
    pCPI->typedef_lists = LL_new();

    pCPI->htEnumerators = HT_new_ex( 5, HT_AUTOGROW );
    pCPI->htEnums       = HT_new_ex( 4, HT_AUTOGROW );
    pCPI->htStructs     = HT_new_ex( 4, HT_AUTOGROW );
    pCPI->htTypedefs    = HT_new_ex( 4, HT_AUTOGROW );
    pCPI->htFiles       = HT_new_ex( 3, HT_AUTOGROW );
  }
  else if( pCPI->enums != NULL && pCPI->structs != NULL &&
           pCPI->typedef_lists != NULL ) {
    CT_DEBUG( CTLIB, ("re-using linked lists") );
  }
  else {
    CT_DEBUG( CTLIB, ("CParseInfo is inconsistent!") );   /* TODO: fail here! */
  }

  state.pCPI = pCPI;

  /*-------------------------------------*/
  /* Lists needed to hold unused objects */
  /*-------------------------------------*/

  state.nodeList            = LL_new();
  state.declaratorList      = LL_new();
  state.arrayList           = LL_new();
  state.structDeclList      = LL_new();
  state.structDeclListsList = LL_new();

  /*-------------------------*/
  /* Set up the preprocessor */
  /*-------------------------*/

  CT_DEBUG( CTLIB, ("initializing preprocessor") );

  state.filename = NULL;

  init_cpp();

  no_special_macros = 0;
  emit_defines      = 0;
  emit_assertions   = 0;
  emit_dependencies = 0;

  init_tables( 1 );

  CT_DEBUG( CTLIB, ("configuring preprocessor") );

  init_include_path( NULL );

  if( filename )
    set_init_filename(filename, 1);
  else
    set_init_filename(BUFFER_NAME, 0);

  init_lexer_state( &state.lexer );
  init_lexer_mode( &state.lexer );

  state.lexer.flags |= HANDLE_ASSERTIONS
                    |  HANDLE_PRAGMA
                    |  LINE_NUM;

  if( pCPC->flags & ISSUE_WARNINGS )
    state.lexer.flags |= WARN_STANDARD
                      |  WARN_ANNOYING
                      |  WARN_TRIGRAPHS
                      |  WARN_TRIGRAPHS_MORE;

#ifdef ANSIC99_EXTENSIONS
  if( pCPC->flags & HAS_CPP_COMMENTS )
    state.lexer.flags |= CPLUSPLUS_COMMENTS;

  if( pCPC->flags & HAS_MACRO_VAARGS )
    state.lexer.flags |= MACRO_VAARG;
#endif

  if( infile != NULL ) {
    state.lexer.input        = infile;
  }
  else {
    state.lexer.input        = NULL;
    state.lexer.input_string = (unsigned char *) pBuf->buffer;
    state.lexer.pbuf         = pBuf->pos;
    state.lexer.ebuf         = pBuf->length;
  }

  /* Add includes */

  LL_foreach( str, pCPC->includes ) {
    CT_DEBUG( CTLIB, ("adding include path \"%s\"", str) );
    add_incpath( str );
  }

  /* Make defines */

  LL_foreach( str, pCPC->defines ) {
    CT_DEBUG( CTLIB, ("defining macro \"%s\"", str) );
    if( (rval = define_macro( &state.lexer, str )) != 0 ) {
      FormatError( pCPI, "invalid macro definition \"%s\"", str );
      goto cleanup;
    }
  }

  /* Make assertions */

  LL_foreach( str, pCPC->assertions ) {
    CT_DEBUG( CTLIB, ("making assertion \"%s\"", str) );
    if( (rval = make_assertion( str )) != 0 ) {
      FormatError( pCPI, "invalid assertion \"%s\"", str );
      goto cleanup;
    }
  }

  enter_file( &state.lexer, state.lexer.flags );

  /*--------------------------*/
  /* Initialize pragma parser */
  /*--------------------------*/

  pragma_init( &state.pragma );
 
  /*-----------------*/
  /* Parse the input */
  /*-----------------*/

  CT_DEBUG( CTLIB, ("entering parser") );

  rval = c_parse( &state );

  CT_DEBUG( CTLIB, ( "c_parse() returned %d", rval ) );

  /*-------------------------------*/
  /* Finish parsing (cleanup ucpp) */
  /*-------------------------------*/

  if( rval )
    while( lex( &state.lexer ) < CPPERR_EOF );

cleanup:
  free_lexer_state( &state.lexer );
  wipeout();

#ifdef MEM_DEBUG
  fprintf( stderr, "ucpp memory leaks [%s]\n", filename ? filename : BUFFER_NAME );
  report_leaks();
#endif

  if( filename == NULL )
    (void) HT_fetch( pCPI->htFiles, BUFFER_NAME, 0, 0 );

  if( state.filename )
    Free( state.filename );

  /*-----------------------*/
  /* Cleanup pragma parser */
  /*-----------------------*/

  pragma_free( &state.pragma );

  /*---------------------*/
  /* Cleanup Enumerators */
  /*---------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( CTLIB ) ) {
    CT_DEBUG( CTLIB, ("cleanup enumerator(s)") );
    if( state.curEnumList && (count = LL_count( state.curEnumList )) > 0 )
      CT_DEBUG( CTLIB, ("%d enumerator(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_destroy( state.curEnumList, (LLDestroyFunc) enum_delete );

  /*---------------*/
  /* Cleanup Nodes */
  /*---------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( CTLIB ) ) {
    CT_DEBUG( CTLIB, ("cleanup node(s)") );
    if( (count = LL_count( state.nodeList )) > 0 ) {
      HashNode hn;
      CT_DEBUG( CTLIB, ("%d node(s) still in memory, cleaning up...", count) );
      LL_foreach( hn, state.nodeList )
        CT_DEBUG( CTLIB, ("[%s]", hn->key) );
    }
  }
#endif

  LL_destroy( state.nodeList, (LLDestroyFunc) HN_delete );

  /*---------------------*/
  /* Cleanup Declarators */
  /*---------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( CTLIB ) ) {
    CT_DEBUG( CTLIB, ("cleanup declarator(s)") );
    if( (count = LL_count( state.declaratorList )) > 0 )
      CT_DEBUG( CTLIB, ("%d declarator(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_destroy( state.declaratorList, (LLDestroyFunc) decl_delete );

  /*----------------*/
  /* Cleanup Arrays */
  /*----------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( CTLIB ) ) {
    Value *pVal;
    CT_DEBUG( CTLIB, ("cleanup array(s)") );
    if( (count = LL_count( state.arrayList )) > 0 ) {
      CT_DEBUG( CTLIB, ("%d array(s) still in memory, cleaning up...", count) );
      LL_foreach( list, state.arrayList ) {
        CT_DEBUG( CTLIB, ("[ARRAY=0x%08X]", list) );
        LL_foreach( pVal, list )
          CT_DEBUG( CTLIB, ("[value=%d,flags=0x%08X]", pVal->iv, pVal->flags) );
      }
    }
  }
#endif

  LL_foreach( list, state.arrayList )
    LL_destroy( list, (LLDestroyFunc) value_delete );

  LL_destroy( state.arrayList, NULL );

  /*----------------------------*/
  /* Cleanup Struct Declarators */
  /*----------------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( CTLIB ) ) {
    CT_DEBUG( CTLIB, ("cleanup struct declarator(s)") );
    if( (count = LL_count( state.structDeclList )) > 0 )
      CT_DEBUG( CTLIB, ("%d struct declarator(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_destroy( state.structDeclList, (LLDestroyFunc) structdecl_delete );

  /*---------------------------------*/
  /* Cleanup Struct Declarator Lists */
  /*---------------------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( CTLIB ) ) {
    CT_DEBUG( CTLIB, ("cleanup struct declarator list(s)") );
    if( (count = LL_count( state.structDeclListsList )) > 0 )
      CT_DEBUG( CTLIB, ("%d struct declarator list(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_foreach( list, state.structDeclListsList )
    LL_destroy( list, (LLDestroyFunc) structdecl_delete );

  LL_destroy( state.structDeclListsList, NULL );

#if !defined NDEBUG && defined CTYPE_DEBUGGING
  if( DEBUG_FLAG( HASH ) ) {
    HT_dump( pCPI->htEnumerators );
    HT_dump( pCPI->htEnums );
    HT_dump( pCPI->htStructs );
    HT_dump( pCPI->htTypedefs );
    HT_dump( pCPI->htFiles );
  }
#endif

  return rval ? 0 : 1;
}

/*******************************************************************************
*
*   ROUTINE: InitParseInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void InitParseInfo( CParseInfo *pCPI )
{
  CT_DEBUG( CTLIB, ("ctparse::InitParseInfo()") );

  if( pCPI ) {
    pCPI->typedef_lists = NULL;
    pCPI->structs       = NULL;
    pCPI->enums         = NULL;

    pCPI->htEnumerators = NULL;
    pCPI->htEnums       = NULL;
    pCPI->htStructs     = NULL;
    pCPI->htTypedefs    = NULL;
    pCPI->htFiles       = NULL;

    pCPI->errstr        = NULL;
  }
}

/*******************************************************************************
*
*   ROUTINE: FreeParseInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void FreeParseInfo( CParseInfo *pCPI )
{
  CT_DEBUG( CTLIB, ("ctparse::FreeParseInfo()") );

  if( pCPI ) {
    LL_destroy( pCPI->enums,         (LLDestroyFunc) enumspec_delete );
    LL_destroy( pCPI->structs,       (LLDestroyFunc) struct_delete );
    LL_destroy( pCPI->typedef_lists, (LLDestroyFunc) typedef_list_delete );

    HT_destroy( pCPI->htEnumerators, NULL );
    HT_destroy( pCPI->htEnums,       NULL );
    HT_destroy( pCPI->htStructs,     NULL );
    HT_destroy( pCPI->htTypedefs,    NULL );

    HT_destroy( pCPI->htFiles,       (LLDestroyFunc) fileinfo_delete );

    if( pCPI->errstr )
      Free( pCPI->errstr );

    InitParseInfo( pCPI );  /* make sure everything is NULL'd */
  }
}

/*******************************************************************************
*
*   ROUTINE: ResetParseInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void ResetParseInfo( CParseInfo *pCPI )
{
  Struct *pStruct;

  CT_DEBUG( CTLIB, ("ctparse::ResetParseInfo(): got %d struct(s)", LL_count( pCPI->structs )) );

  /* clear size and align fields */
  LL_foreach( pStruct, pCPI->structs ) {
    CT_DEBUG( CTLIB, ("resetting struct '%s':", pStruct->identifier[0] ?
                      pStruct->identifier : "<no-identifier>" ) );

    pStruct->align = 0;
    pStruct->size  = 0;
  }
}

/*******************************************************************************
*
*   ROUTINE: UpdateParseInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void UpdateParseInfo( CParseInfo *pCPI, CParseConfig *pCPC )
{
  Struct *pStruct;

  CT_DEBUG( CTLIB, ("ctparse::UpdateParseInfo(): got %d struct(s)", LL_count( pCPI->structs )) );

  /* compute size and alignment */
  LL_foreach( pStruct, pCPI->structs ) {
    CT_DEBUG( CTLIB, ("updating struct '%s':", pStruct->identifier[0] ?
                      pStruct->identifier : "<no-identifier>") );

    if( pStruct->align == 0 )
      UpdateStruct( pCPC, pStruct );
  }
}

/*******************************************************************************
*
*   ROUTINE: CloneParseInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void CloneParseInfo( CParseInfo *pDest, CParseInfo *pSrc )
{
  HashTable      ptrmap;
  EnumSpecifier *pES;
  Struct        *pStruct;
  TypedefList   *pTDL;
  char          *pKey;

  CT_DEBUG( CTLIB, ("ctparse::CloneParseInfo()") );

  if(   pSrc->enums         == NULL
     || pSrc->structs       == NULL
     || pSrc->typedef_lists == NULL
     || pSrc->htEnumerators == NULL
     || pSrc->htEnums       == NULL
     || pSrc->htStructs     == NULL
     || pSrc->htTypedefs    == NULL
     || pSrc->htFiles       == NULL
    )
    return;  /* don't clone empty objects */

  ptrmap = HT_new_ex( 3, HT_AUTOGROW );

  pDest->enums         = LL_new();
  pDest->structs       = LL_new();
  pDest->typedef_lists = LL_new();
  pDest->htEnumerators = HT_new_ex( HT_size( pSrc->htEnumerators ), HT_AUTOGROW );
  pDest->htEnums       = HT_new_ex( HT_size( pSrc->htEnums ), HT_AUTOGROW );
  pDest->htStructs     = HT_new_ex( HT_size( pSrc->htStructs ), HT_AUTOGROW );
  pDest->htTypedefs    = HT_new_ex( HT_size( pSrc->htTypedefs ), HT_AUTOGROW );

  CT_DEBUG( CTLIB, ("cloning enums") );

  LL_foreach( pES, pSrc->enums ) {
    Enumerator    *pEnum;
    EnumSpecifier *pClone = enumspec_clone( pES );

    CT_DEBUG( CTLIB, ("storing pointer to map: 0x%08X <=> 0x%08X", pES, pClone) );
    HT_store( ptrmap, (const char *) &pES, sizeof( pES ), 0, pClone );
    LL_push( pDest->enums, pClone );

    if( pClone->identifier[0] )
      HT_store( pDest->htEnums, pClone->identifier, 0, 0, pClone );

    LL_foreach( pEnum, pClone->enumerators )
      HT_store( pDest->htEnumerators, pEnum->identifier, 0, 0, pEnum );
  }

  CT_DEBUG( CTLIB, ("cloning structs") );

  LL_foreach( pStruct, pSrc->structs ) {
    Struct *pClone = struct_clone( pStruct );

    CT_DEBUG( CTLIB, ("storing pointer to map: 0x%08X <=> 0x%08X", pStruct, pClone) );
    HT_store( ptrmap, (const char *) &pStruct, sizeof( pStruct ), 0, pClone );
    LL_push( pDest->structs, pClone );

    if( pClone->identifier[0] )
      HT_store( pDest->htStructs, pClone->identifier, 0, 0, pClone );
  }

  CT_DEBUG( CTLIB, ("cloning typedefs") );

  LL_foreach( pTDL, pSrc->typedef_lists ) {
    TypedefList *pClone = typedef_list_clone( pTDL );
    Typedef *pOld, *pNew;

    LL_reset( pTDL->typedefs );
    LL_reset( pClone->typedefs );

    while(   (pOld = LL_next(pTDL->typedefs))   != NULL
          && (pNew = LL_next(pClone->typedefs)) != NULL
         ) {
      CT_DEBUG( CTLIB, ("storing pointer to map: 0x%08X <=> 0x%08X", pOld, pNew) );
      HT_store( ptrmap, (const char *) &pOld, sizeof( pOld ), 0, pNew );
      HT_store( pDest->htTypedefs, pNew->pDecl->identifier, 0, 0, pNew );
    }

    LL_push( pDest->typedef_lists, pClone );
  }

  LL_foreach( pStruct, pDest->structs ) {
    StructDeclaration *pStructDecl;

    CT_DEBUG( CTLIB, ("remapping pointers for struct @ 0x%08X (\"%s\")",
                      pStruct, pStruct->identifier) );

    LL_foreach( pStructDecl, pStruct->declarations ) {
      if( pStructDecl->type.ptr != NULL ) {
        void *ptr = HT_get( ptrmap, (const char *) &pStructDecl->type.ptr,
                                    sizeof(void *), 0 );

        CT_DEBUG( CTLIB, ("StructDecl @ 0x%08X: 0x%08X => 0x%08X",
                          pStructDecl, pStructDecl->type.ptr, ptr) );

        if( ptr )
          pStructDecl->type.ptr = ptr;
        else
          fprintf( stderr, "FATAL: pointer 0x%08X not found!\n",
                           pStructDecl->type.ptr );
      }
    }
  }

  CT_DEBUG( CTLIB, ("remapping pointers for typedef lists") );

  LL_foreach( pTDL, pDest->typedef_lists ) {
    if( pTDL->type.ptr != NULL ) {
      void *ptr = HT_get( ptrmap, (const char *) &pTDL->type.ptr,
                                  sizeof(void *), 0 );

      CT_DEBUG( CTLIB, ("TypedefList @ 0x%08X: 0x%08X => 0x%08X",
                        pTDL, pTDL->type.ptr, ptr) );

      if( ptr )
        pTDL->type.ptr = ptr;
      else
        fprintf( stderr, "FATAL: pointer 0x%08X not found!\n",
                         pTDL->type.ptr );
    }
  }

  HT_destroy( ptrmap, NULL );

  pDest->htFiles = HT_clone( pSrc->htFiles, (HTCloneFunc) fileinfo_clone );
}

/*******************************************************************************
*
*   ROUTINE: GetTypeInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

ErrorGTI GetTypeInfo( CParseConfig *pCPC, TypeSpec *pTS, Declarator *pDecl,
                      unsigned *pSize, unsigned *pAlign, unsigned *pItemSize,
                      u_32 *pFlags )
{
  u_32 flags = pTS->tflags;
  void *tptr = pTS->ptr;
  unsigned size;
  ErrorGTI err = GTI_NO_ERROR;

  CT_DEBUG( CTLIB, ("ctparse::GetTypeInfo( pCPC=0x%08X, pTS=0x%08X "
                    "[flags=0x%08X, ptr=0x%08X], pDecl=0x%08X, pFlags=0x%08X )",
                    pCPC, pTS, flags, tptr, pDecl, pFlags) );

  if( pFlags )
    *pFlags = 0;

  if( pDecl && pDecl->pointer_flag ) {
    CT_DEBUG( CTLIB, ("pointer flag set") );
    size = pCPC->ptr_size ? pCPC->ptr_size : CTLIB_POINTER_SIZE;
    if( pAlign )
      *pAlign = size;
  }
  else if( pDecl && pDecl->bitfield_size >= 0 ) {
    size = 0;
    if( pAlign )
      *pAlign = 1;
  }
  else if( flags & T_TYPE ) {
    CT_DEBUG( CTLIB, ("T_TYPE flag set") );
    if( tptr ) {
      Typedef *pTypedef = (Typedef *) tptr;
      if( pFlags ) {
        u_32 flags;
        err = GetTypeInfo( pCPC, pTypedef->pType, pTypedef->pDecl, &size,
                           pAlign, NULL, &flags );
        *pFlags |= flags;
      }
      else
        err = GetTypeInfo( pCPC, pTypedef->pType, pTypedef->pDecl, &size,
                           pAlign, NULL, NULL );
    }
    else {
      CT_DEBUG( CTLIB, ("NULL pointer to typedef in GetTypeInfo") );
      size = pCPC->int_size ? pCPC->int_size : sizeof( int );
      if( pAlign )
        *pAlign = size;
      err = GTI_TYPEDEF_IS_NULL;
    }
  }
  else if( flags & T_ENUM ) {
    CT_DEBUG( CTLIB, ("T_ENUM flag set") );
    if( pCPC->enum_size || tptr ) {
      size = pCPC->enum_size
           ? pCPC->enum_size
           : ((EnumSpecifier *) tptr)->size;
    }
    else {
      CT_DEBUG( CTLIB, ("neither enum_size (%d) nor enum pointer (0x%08X) in GetTypeInfo",
                        pCPC->enum_size, tptr) );
      size = pCPC->int_size ? pCPC->int_size : sizeof( int );
      err = GTI_NO_ENUM_SIZE;
    }

    if( pAlign )
      *pAlign = size;
  }
  else if( flags & (T_STRUCT|T_UNION) ) {
    CT_DEBUG( CTLIB, ("T_STRUCT or T_UNION flag set") );
    if( tptr ) {
      Struct *pStruct = (Struct *) tptr;

      if( pStruct->declarations == NULL ) {
        CT_DEBUG( CTLIB, ("no struct declarations in GetTypeInfo") );
        size = pCPC->int_size ? pCPC->int_size : sizeof( int );
        if( pAlign )
          *pAlign = size;
        err = GTI_NO_STRUCT_DECL;
      }
      else {
        if( pStruct->align == 0 )
          UpdateStruct( pCPC, pStruct );
    
        size = pStruct->size;
        if( pAlign )
          *pAlign = pStruct->align;
      }

      if( pFlags )
        *pFlags |= pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
    }
    else {
      CT_DEBUG( CTLIB, ("NULL pointer to struct/union in GetTypeInfo") );
      size = pCPC->int_size ? pCPC->int_size : sizeof( int );
      if( pAlign )
        *pAlign = size;
      err = GTI_STRUCT_IS_NULL;
    }
  }
  else {
    CT_DEBUG( CTLIB, ("only basic type flags set") );

#define LOAD_SIZE( type ) \
        size = pCPC->type ## _size ? pCPC->type ## _size : CTLIB_ ## type ## _SIZE

    if( flags & (T_CHAR | T_VOID) )  /* XXX: do we want void ? */
      size = 1;
    else if( (flags & (T_LONG|T_DOUBLE)) == (T_LONG|T_DOUBLE) )
      LOAD_SIZE( long_double );
    else if( flags & T_LONGLONG ) LOAD_SIZE( long_long );
    else if( flags & T_FLOAT )    LOAD_SIZE( float );
    else if( flags & T_DOUBLE )   LOAD_SIZE( double );
    else if( flags & T_SHORT )    LOAD_SIZE( short );
    else if( flags & T_LONG )     LOAD_SIZE( long );
    else                          LOAD_SIZE( int );

#undef LOAD_SIZE

    if( pAlign )
      *pAlign = size;
  }

  if( pItemSize )
    *pItemSize = size;

  if( pDecl && pDecl->array ) {
    Value *pValue;

    CT_DEBUG( CTLIB, ("processing array [0x%08X]", pDecl->array) );

    LL_foreach( pValue, pDecl->array ) {
      CT_DEBUG( CTLIB, ("[%d]", pValue->iv) );
      size *= pValue->iv;
      if( pFlags && IS_UNSAFE_VAL( *pValue ) )
        *pFlags |= T_UNSAFE_VAL;
    }
  }

  if( pSize )
    *pSize = size;

  CT_DEBUG( CTLIB, ("ctparse::GetTypeInfo( size(0x%08X)=%d, align(0x%08X)=%d, "
                    "item(0x%08X)=%d, bitfields(0x%08X)=%d ) finished",
                    pSize, pSize ? *pSize : 0, pAlign, pAlign ? *pAlign : 0,
                    pItemSize, pItemSize ? *pItemSize : 0,
                    pFlags, pFlags ? *pFlags : 0) );

  return err;
}

/*******************************************************************************
*
*   ROUTINE: FormatError
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void FormatError( CParseInfo *pCPI, char *format, ... )
{
  va_list args;
  char buffer[1024];
  int len;

  va_start( args, format );

  if( pCPI->errstr ) {
    CT_DEBUG( CTLIB, ("Unhandled error: %s", pCPI->errstr) );
    Free( pCPI->errstr );
  }

  len = vsprintf( buffer, format, args );

  if( len > 0 ) {
    pCPI->errstr = (char *) Alloc( len+1 );
    strcpy( pCPI->errstr, buffer );
  }
  else
    pCPI->errstr = NULL;

  va_end( args );
}

/*******************************************************************************
*
*   ROUTINE: FreeError
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void FreeError( CParseInfo *pCPI )
{
  if( pCPI->errstr )
    Free( pCPI->errstr );
}

