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
* $Date: 2004/05/20 20:22:00 +0100 $
* $Revision: 38 $
* $Snapshot: /Convert-Binary-C/0.54 $
* $Source: /ctlib/ctparse.c $
*
********************************************************************************
*
* Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "ctparse.h"
#include "cterror.h"
#include "ctdebug.h"
#include "fileinfo.h"
#include "parser.h"

#include "util/memalloc.h"

#include "ucpp/cpp.h"

#ifdef MEM_DEBUG
#include "ucpp/mem.h" /* for report_leaks() */
#endif

#include "cppreent.h"


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

static char *get_path_name( const char *dir, const char *file );
static void update_struct( const CParseConfig *pCPC, Struct *pStruct );


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

#ifndef UCPP_REENTRANT
CParseInfo *g_current_cpi;
#endif


/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*******************************************************************************
*
*   ROUTINE: update_struct
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

static void update_struct( const CParseConfig *pCPC, Struct *pStruct )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  unsigned           size, align, alignment;
  u_32               flags;

  CT_DEBUG( CTLIB, ("update_struct( %s ), got %d struct declaration(s)",
            pStruct->identifier[0] ? pStruct->identifier : "<no-identifier>",
            LL_count(pStruct->declarations)) );

  if( pStruct->declarations == NULL ) {
    CT_DEBUG( CTLIB, ("no struct declarations in update_struct") );
    return;
  }

  alignment = pStruct->pack ? pStruct->pack : pCPC->alignment;

  pStruct->align = alignment < pCPC->compound_alignment
                 ? alignment : pCPC->compound_alignment;

  LL_foreach( pStructDecl, pStruct->declarations ) {

    CT_DEBUG( CTLIB, ("%d declarators in struct declaration, tflags=0x%08lX ptr=%p",
              LL_count(pStructDecl->declarators),
              (unsigned long) pStructDecl->type.tflags, pStructDecl->type.ptr) );

    pStructDecl->offset = pStruct->tflags & T_STRUCT ? -1 : 0;
    pStructDecl->size   = 0;

    if( pStructDecl->declarators ) {

      LL_foreach( pDecl, pStructDecl->declarators ) {
        CT_DEBUG( CTLIB, ("current declarator [%s]",
                  pDecl->identifier[0] ? pDecl->identifier : "<no-identifier>") );

        get_type_info( pCPC, &pStructDecl->type, pDecl, &size, &align, NULL, &flags );
        CT_DEBUG( CTLIB, ("declarator size=%d, align=%d, flags=0x%08lX",
                          size, align, (unsigned long) flags) );

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
          unsigned mod = pStruct->size % align;

          if( mod )
            pStruct->size += align - mod;

          if( pStructDecl->offset < 0 )
            pStructDecl->offset = pStruct->size;

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
    else /* unnamed struct/union */ {

      CT_DEBUG( CTLIB, ("current declaration is an unnamed struct/union") );

      get_type_info( pCPC, &pStructDecl->type, NULL, &size, &align, NULL, &flags );
      CT_DEBUG( CTLIB, ("unnamed struct/union: size=%d, align=%d, flags=0x%08lX",
                        size, align, (unsigned long) flags) );

      if( flags & T_HASBITFIELD ) {
        CT_DEBUG( CTLIB, ("found bitfield in unnamed struct/union") );
        pStruct->tflags |= T_HASBITFIELD;
      }

      if( flags & T_UNSAFE_VAL ) {
        CT_DEBUG( CTLIB, ("unsafe values in unnamed struct/union") );
        pStruct->tflags |= T_UNSAFE_VAL;
      }

      if( align > alignment )
        align = alignment;

      if( align > pStruct->align )
        pStruct->align = align;

      if( pStruct->tflags & T_STRUCT ) {
        unsigned mod = pStruct->size % align;

        if( mod )
          pStruct->size += align - mod;

        if( pStructDecl->offset < 0 )
          pStructDecl->offset = pStruct->size;

        pStruct->size += size;
      }
      else /* T_UNION */ {
        if( size > pStruct->size )
          pStruct->size = size;
      }
    }

    if( pStructDecl->offset < 0 )
      pStructDecl->offset = pStruct->size;

    pStructDecl->size = pStruct->size - pStructDecl->offset;

  }

  if( pStruct->size % pStruct->align )
    pStruct->size += pStruct->align - pStruct->size % pStruct->align;

  CT_DEBUG( CTLIB, ("update_struct( %s ): size=%d, align=%d",
            pStruct->identifier[0] ? pStruct->identifier : "<no-identifier>",
            pStruct->size, pStruct->align) );
}

/*******************************************************************************
*
*   ROUTINE: get_path_name
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

static char *get_path_name( const char *dir, const char *file )
{
  int dirlen = 0, filelen, append_delim = 0;
  char *buf, *b;

  if( dir != NULL ) {
    dirlen = strlen( dir );
    if( !IS_ANY_DIRECTORY_DELIMITER( dir[dirlen-1] ) )
      append_delim = 1;
  }

  filelen = strlen( file );

  AllocF( char *, buf, dirlen + append_delim + filelen + 1 );
  
  if( dir != NULL )
    strcpy( buf, dir );

  if( append_delim )
    buf[dirlen++] = SYSTEM_DIRECTORY_DELIMITER;

  strcpy( buf+dirlen, file );

  for( b=buf; *b; b++ )
    if( IS_NON_SYSTEM_DIR_DELIM( *b ) )
      *b = SYSTEM_DIRECTORY_DELIMITER;

  return buf;
}


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: parse_buffer
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

int parse_buffer( const char *filename, const Buffer *pBuf,
                 const CParseConfig *pCPC, CParseInfo *pCPI )
{
  int                rval;
  char              *file, *str;
  FILE              *infile;
  struct lexer_state lexer;
  ParserState       *pState;
#ifdef UCPP_REENTRANT
  struct CPP        *cpp;
#endif

  CT_DEBUG( CTLIB, ("ctparse::parse_buffer( %s, %p, %p, %p )",
            filename ? filename : BUFFER_NAME, pBuf, pCPI, pCPC) );

#ifndef UCPP_REENTRANT
  g_current_cpi = pCPI;
#endif

  /*----------------------------------*/
  /* Initialize parse info structures */
  /*----------------------------------*/

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

    pCPI->errorStack    = LL_new();
  }
  else if( pCPI->enums != NULL && pCPI->structs != NULL &&
           pCPI->typedef_lists != NULL ) {
    CT_DEBUG( CTLIB, ("re-using linked lists") );
    pop_all_errors( pCPI );
  }
  else {
    CT_DEBUG( CTLIB, ("CParseInfo is inconsistent!") );   /* TODO: fail here! */
  }

  /*----------------------------*/
  /* Try to open the input file */
  /*----------------------------*/

  infile = NULL;

  if( filename != NULL ) {
    file = get_path_name( NULL, filename );

    CT_DEBUG( CTLIB, ("Trying '%s'...", file) );

    infile = fopen( file, "r" );

    if( infile == NULL ) {
      LL_foreach( str, pCPC->includes ) {
        Free( file );

        file = get_path_name( str, filename );

        CT_DEBUG( CTLIB, ("Trying '%s'...", file) );

        if( (infile = fopen( file, "r" )) != NULL )
          break;
      }

      if( infile == NULL ) {
        Free( file );
        push_error( pCPI, "Cannot find input file '%s'", filename );
#ifndef UCPP_REENTRANT
        g_current_cpi = NULL;
#endif
        return 0;
      }
    }
  }

  /*-------------------------*/
  /* Set up the preprocessor */
  /*-------------------------*/

  CT_DEBUG( CTLIB, ("initializing preprocessor") );

#ifdef UCPP_REENTRANT
  cpp = new_cpp();
#endif

  init_cpp(aUCPP);

#ifdef UCPP_REENTRANT
  cpp->ucpp_ouch    = my_ucpp_ouch;
  cpp->ucpp_error   = my_ucpp_error;
  cpp->ucpp_warning = my_ucpp_warning;
  cpp->callback_arg = (void *) pCPI;
#endif

  r_no_special_macros = 0;
  r_emit_defines      = 0;
  r_emit_assertions   = 0;
  r_emit_dependencies = 0;

  init_tables( aUCPP_ 1 );

  CT_DEBUG( CTLIB, ("configuring preprocessor") );

  init_include_path( aUCPP_ NULL );

  if( filename != NULL ) {
    set_init_filename( aUCPP_ file, 1 );
    Free( file );
  }
  else
    set_init_filename( aUCPP_ BUFFER_NAME, 0 );

  init_lexer_state( &lexer );
  init_lexer_mode( &lexer );

  lexer.flags |= HANDLE_ASSERTIONS
              |  HANDLE_PRAGMA
              |  LINE_NUM;

  if( pCPC->flags & ISSUE_WARNINGS )
    lexer.flags |= WARN_STANDARD
                |  WARN_ANNOYING
                |  WARN_TRIGRAPHS
                |  WARN_TRIGRAPHS_MORE;

  if( pCPC->flags & HAS_CPP_COMMENTS )
    lexer.flags |= CPLUSPLUS_COMMENTS;

  if( pCPC->flags & HAS_MACRO_VAARGS )
    lexer.flags |= MACRO_VAARG;

  if( infile != NULL ) {
    lexer.input        = infile;
  }
  else {
    lexer.input        = NULL;
    lexer.input_string = (unsigned char *) pBuf->buffer;
    lexer.pbuf         = pBuf->pos;
    lexer.ebuf         = pBuf->length;
  }

  /* Add includes */

  LL_foreach( str, pCPC->includes ) {
    CT_DEBUG( CTLIB, ("adding include path '%s'", str) );
    add_incpath( aUCPP_ str );
  }

  /* Make defines */

  LL_foreach( str, pCPC->defines ) {
    CT_DEBUG( CTLIB, ("defining macro '%s'", str) );
    (void) define_macro( aUCPP_ &lexer, str );
  }

  /* Make assertions */

  LL_foreach( str, pCPC->assertions ) {
    CT_DEBUG( CTLIB, ("making assertion '%s'", str) );
    (void) make_assertion( aUCPP_ str );
  }

  enter_file( aUCPP_ &lexer, lexer.flags );

  /*---------------------*/
  /* Create the C parser */
  /*---------------------*/

  pState = c_parser_new( pCPC, pCPI, aUCPP_ &lexer );

  /*-----------------*/
  /* Parse the input */
  /*-----------------*/

  if( pCPC->flags & DISABLE_PARSER ) {
    CT_DEBUG( CTLIB, ("parser is disabled, running only preprocessor") );
    rval = 0;
  }
  else {
    CT_DEBUG( CTLIB, ("entering parser") );
    rval = c_parser_run( pState );
    CT_DEBUG( CTLIB, ("c_parse() returned %d", rval) );
  }

  /*-------------------------------*/
  /* Finish parsing (cleanup ucpp) */
  /*-------------------------------*/

  if( rval || (pCPC->flags & DISABLE_PARSER) )
    while( lex( aUCPP_ &lexer ) < CPPERR_EOF );

  free_lexer_state( &lexer );
  wipeout( aUCPP );

#ifdef UCPP_REENTRANT
  del_cpp( cpp );
#endif

#ifdef MEM_DEBUG
  report_leaks();
#endif

  /*----------------------*/
  /* Cleanup the C parser */
  /*----------------------*/

  c_parser_delete( pState );

  /* Invalidate the buffer name in the parsed files table */

  if( filename == NULL )
    ((FileInfo *) HT_get( pCPI->htFiles, BUFFER_NAME, 0, 0 ))->valid = 0;

#if !defined NDEBUG && defined CTYPE_DEBUGGING
  if( DEBUG_FLAG( HASH ) ) {
    HT_dump( pCPI->htEnumerators );
    HT_dump( pCPI->htEnums );
    HT_dump( pCPI->htStructs );
    HT_dump( pCPI->htTypedefs );
    HT_dump( pCPI->htFiles );
  }
#endif

#ifndef UCPP_REENTRANT
  g_current_cpi = NULL;
#endif

  return rval ? 0 : 1;
}

/*******************************************************************************
*
*   ROUTINE: init_parse_info
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

void init_parse_info( CParseInfo *pCPI )
{
  CT_DEBUG( CTLIB, ("ctparse::init_parse_info()") );

  if( pCPI ) {
    pCPI->typedef_lists = NULL;
    pCPI->structs       = NULL;
    pCPI->enums         = NULL;

    pCPI->htEnumerators = NULL;
    pCPI->htEnums       = NULL;
    pCPI->htStructs     = NULL;
    pCPI->htTypedefs    = NULL;
    pCPI->htFiles       = NULL;

    pCPI->errorStack    = NULL;
  }
}

/*******************************************************************************
*
*   ROUTINE: free_parse_info
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

void free_parse_info( CParseInfo *pCPI )
{
  CT_DEBUG( CTLIB, ("ctparse::free_parse_info()") );

  if( pCPI ) {
    LL_destroy( pCPI->enums,         (LLDestroyFunc) enumspec_delete );
    LL_destroy( pCPI->structs,       (LLDestroyFunc) struct_delete );
    LL_destroy( pCPI->typedef_lists, (LLDestroyFunc) typedef_list_delete );

    HT_destroy( pCPI->htEnumerators, NULL );
    HT_destroy( pCPI->htEnums,       NULL );
    HT_destroy( pCPI->htStructs,     NULL );
    HT_destroy( pCPI->htTypedefs,    NULL );

    HT_destroy( pCPI->htFiles,       (LLDestroyFunc) fileinfo_delete );

    if( pCPI->errorStack ) {
      pop_all_errors( pCPI );
      LL_delete( pCPI->errorStack );
    }

    init_parse_info( pCPI );  /* make sure everything is NULL'd */
  }
}

/*******************************************************************************
*
*   ROUTINE: reset_parse_info
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

void reset_parse_info( CParseInfo *pCPI )
{
  Struct *pStruct;
  TypedefList *pTDL;
  Typedef *pTD;

  CT_DEBUG( CTLIB, ("ctparse::reset_parse_info(): got %d struct(s)",
                    LL_count( pCPI->structs )) );

  /* clear size and align fields */
  LL_foreach( pStruct, pCPI->structs ) {
    CT_DEBUG( CTLIB, ("resetting struct '%s':", pStruct->identifier[0] ?
                      pStruct->identifier : "<no-identifier>" ) );

    pStruct->align = 0;
    pStruct->size  = 0;
  }

  LL_foreach( pTDL, pCPI->typedef_lists )
    LL_foreach( pTD, pTDL->typedefs )
      pTD->pDecl->size = -1;
}

/*******************************************************************************
*
*   ROUTINE: update_parse_info
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

void update_parse_info( CParseInfo *pCPI, const CParseConfig *pCPC )
{
  Struct *pStruct;
  TypedefList *pTDL;
  Typedef *pTD;

  CT_DEBUG( CTLIB, ("ctparse::update_parse_info(): got %d struct(s)",
                    LL_count( pCPI->structs )) );

  /* compute size and alignment */
  LL_foreach( pStruct, pCPI->structs ) {
    CT_DEBUG( CTLIB, ("updating struct '%s':", pStruct->identifier[0] ?
                      pStruct->identifier : "<no-identifier>") );

    if( pStruct->align == 0 )
      update_struct( pCPC, pStruct );
  }

  LL_foreach( pTDL, pCPI->typedef_lists )
    LL_foreach( pTD, pTDL->typedefs )
      if( pTD->pDecl->size < 0 ) {
        unsigned size;
        if( get_type_info( pCPC, pTD->pType, pTD->pDecl, &size,
	                   NULL, NULL, NULL ) == GTI_NO_ERROR )
          pTD->pDecl->size = (int) size;
      }
}

/*******************************************************************************
*
*   ROUTINE: clone_parse_info
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

#define PTR_NOT_FOUND( ptr )                                                   \
        do {                                                                   \
          fprintf( stderr, "FATAL: pointer " #ptr " (%p) not found! (%s:%d)\n",\
                           ptr, __FILE__, __LINE__ );                          \
          abort();                                                             \
        } while(0)

void clone_parse_info( CParseInfo *pDest, CParseInfo *pSrc )
{
  HashTable      ptrmap;
  EnumSpecifier *pES;
  Struct        *pStruct;
  TypedefList   *pTDL;

  CT_DEBUG( CTLIB, ("ctparse::clone_parse_info()") );

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
  pDest->errorStack    = LL_new();

  CT_DEBUG( CTLIB, ("cloning enums") );

  LL_foreach( pES, pSrc->enums ) {
    Enumerator    *pEnum;
    EnumSpecifier *pClone = enumspec_clone( pES );

    CT_DEBUG( CTLIB, ("storing pointer to map: %p <=> %p", pES, pClone) );
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

    CT_DEBUG( CTLIB, ("storing pointer to map: %p <=> %p", pStruct, pClone) );
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
      CT_DEBUG( CTLIB, ("storing pointer to map: %p <=> %p", pOld, pNew) );
      HT_store( ptrmap, (const char *) &pOld, sizeof( pOld ), 0, pNew );
      HT_store( pDest->htTypedefs, pNew->pDecl->identifier, 0, 0, pNew );
    }

    LL_push( pDest->typedef_lists, pClone );
  }

  CT_DEBUG( CTLIB, ("cloning file information") );

  {
    void *pOld, *pNew;

    pDest->htFiles = HT_clone( pSrc->htFiles, (HTCloneFunc) fileinfo_clone );

    HT_reset( pSrc->htFiles );
    HT_reset( pDest->htFiles );

    while(   HT_next( pSrc->htFiles, NULL, NULL, &pOld)
          && HT_next( pDest->htFiles, NULL, NULL, &pNew)
         ) {
      CT_DEBUG( CTLIB, ("storing pointer to map: %p <=> %p", pOld, pNew) );
      HT_store( ptrmap, (const char *) &pOld, sizeof( pOld ), 0, pNew );
    }
  }

  CT_DEBUG( CTLIB, ("remapping pointers for enums") );

  LL_foreach( pES, pDest->enums ) {
    void *ptr;

    ptr = HT_get( ptrmap, (const char *) &pES->context.pFI,
                          sizeof(void *), 0 );

    CT_DEBUG( CTLIB, ("EnumSpec @ %p: %p => %p", pES, pES->context.pFI, ptr) );

    if( ptr )
      pES->context.pFI = ptr;
    else
      PTR_NOT_FOUND( (void *) pES->context.pFI );
  }

  CT_DEBUG( CTLIB, ("remapping pointers for structs") );

  LL_foreach( pStruct, pDest->structs ) {
    StructDeclaration *pStructDecl;
    void *ptr;

    CT_DEBUG( CTLIB, ("remapping pointers for struct @ %p ('%s')",
                      pStruct, pStruct->identifier) );

    LL_foreach( pStructDecl, pStruct->declarations ) {
      if( pStructDecl->type.ptr != NULL ) {
        ptr = HT_get( ptrmap, (const char *) &pStructDecl->type.ptr,
                              sizeof(void *), 0 );

        CT_DEBUG( CTLIB, ("StructDecl @ %p: %p => %p",
                          pStructDecl, pStructDecl->type.ptr, ptr) );

        if( ptr )
          pStructDecl->type.ptr = ptr;
        else
          PTR_NOT_FOUND( pStructDecl->type.ptr );
      }
    }

    ptr = HT_get( ptrmap, (const char *) &pStruct->context.pFI,
                          sizeof(void *), 0 );

    CT_DEBUG( CTLIB, ("Struct @ %p: %p => %p",
                      pStruct, pStruct->context.pFI, ptr) );

    if( ptr )
      pStruct->context.pFI = ptr;
    else
      PTR_NOT_FOUND( (void *) pStruct->context.pFI );
  }

  CT_DEBUG( CTLIB, ("remapping pointers for typedef lists") );

  LL_foreach( pTDL, pDest->typedef_lists ) {
    if( pTDL->type.ptr != NULL ) {
      void *ptr = HT_get( ptrmap, (const char *) &pTDL->type.ptr,
                                  sizeof(void *), 0 );

      CT_DEBUG( CTLIB, ("TypedefList @ %p: %p => %p",
                        pTDL, pTDL->type.ptr, ptr) );

      if( ptr )
        pTDL->type.ptr = ptr;
      else
        PTR_NOT_FOUND( pTDL->type.ptr );
    }
  }

  HT_destroy( ptrmap, NULL );
}

#undef PTR_NOT_FOUND

/*******************************************************************************
*
*   ROUTINE: get_type_info
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

ErrorGTI get_type_info( const CParseConfig *pCPC, const TypeSpec *pTS,
                        const Declarator *pDecl, unsigned *pSize,
                        unsigned *pAlign, unsigned *pItemSize, u_32 *pFlags )
{
  u_32 flags = pTS->tflags;
  void *tptr = pTS->ptr;
  unsigned size;
  ErrorGTI err = GTI_NO_ERROR;

  CT_DEBUG( CTLIB, ("ctparse::get_type_info( pCPC=%p, pTS=%p "
                    "[flags=0x%08lX, ptr=%p], pDecl=%p, pFlags=%p )",
                    pCPC, pTS, (unsigned long) flags, tptr, pDecl, pFlags) );

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
        err = get_type_info( pCPC, pTypedef->pType, pTypedef->pDecl, &size,
                             pAlign, NULL, &flags );
        *pFlags |= flags;
      }
      else
        err = get_type_info( pCPC, pTypedef->pType, pTypedef->pDecl, &size,
                             pAlign, NULL, NULL );
    }
    else {
      CT_DEBUG( CTLIB, ("NULL pointer to typedef in get_type_info") );
      size = pCPC->int_size ? pCPC->int_size : sizeof( int );
      if( pAlign )
        *pAlign = size;
      err = GTI_TYPEDEF_IS_NULL;
    }
  }
  else if( flags & T_ENUM ) {
    CT_DEBUG( CTLIB, ("T_ENUM flag set") );
    if( pCPC->enum_size > 0 || tptr ) {
      size = pCPC->enum_size > 0
           ? (unsigned) pCPC->enum_size
           : ((EnumSpecifier *) tptr)->sizes[-pCPC->enum_size];
    }
    else {
      CT_DEBUG( CTLIB, ("neither enum_size (%d) nor enum pointer (%p) in get_type_info",
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
        CT_DEBUG( CTLIB, ("no struct declarations in get_type_info") );
        size = pCPC->int_size ? pCPC->int_size : sizeof( int );
        if( pAlign )
          *pAlign = size;
        err = GTI_NO_STRUCT_DECL;
      }
      else {
        if( pStruct->align == 0 )
          update_struct( pCPC, pStruct );

        size = pStruct->size;
        if( pAlign )
          *pAlign = pStruct->align;
      }

      if( pFlags )
        *pFlags |= pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
    }
    else {
      CT_DEBUG( CTLIB, ("NULL pointer to struct/union in get_type_info") );
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

  if( pSize ) {
    if( pDecl && pDecl->array ) {
      Value *pValue;

      CT_DEBUG( CTLIB, ("processing array [%p]", pDecl->array) );

      LL_foreach( pValue, pDecl->array ) {
        CT_DEBUG( CTLIB, ("[%ld]", pValue->iv) );
        size *= pValue->iv;
        if( pFlags && IS_UNSAFE_VAL( *pValue ) )
          *pFlags |= T_UNSAFE_VAL;
      }
    }

    *pSize = size;
  }

  CT_DEBUG( CTLIB, ("ctparse::get_type_info( size(%p)=%d, align(%p)=%d, "
                    "item(%p)=%d, flags(%p)=0x%08lX ) finished",
                    pSize, pSize ? *pSize : 0, pAlign, pAlign ? *pAlign : 0,
                    pItemSize, pItemSize ? *pItemSize : 0,
                    pFlags, (unsigned long) (pFlags ? *pFlags : 0)) );

  return err;
}

