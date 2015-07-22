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
* $Date: 2006/01/04 22:23:20 +0000 $
* $Revision: 57 $
* $Source: /ctlib/ctparse.c $
*
********************************************************************************
*
* Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stddef.h>
#include <assert.h>


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

static char *get_path_name(const char *dir, const char *file);


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

#ifndef UCPP_REENTRANT
CParseInfo *g_current_cpi;
#endif


/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

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

static char *get_path_name(const char *dir, const char *file)
{
  int dirlen = 0, filelen, append_delim = 0;
  char *buf, *b;

  if (dir != NULL)
  {
    dirlen = strlen(dir);
    if (!IS_ANY_DIRECTORY_DELIMITER(dir[dirlen-1]))
      append_delim = 1;
  }

  filelen = strlen(file);

  AllocF(char *, buf, dirlen + append_delim + filelen + 1);
  
  if (dir != NULL)
    strcpy(buf, dir);

  if (append_delim)
    buf[dirlen++] = SYSTEM_DIRECTORY_DELIMITER;

  strcpy(buf+dirlen, file);

  for (b = buf; *b; b++)
    if (IS_NON_SYSTEM_DIR_DELIM(*b))
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

int parse_buffer(const char *filename, const Buffer *pBuf,
                 const CParseConfig *pCPC, CParseInfo *pCPI)
{
  int                rval;
  char              *file, *str;
  FILE              *infile;
  struct lexer_state lexer;
  ParserState       *pState;
#ifdef UCPP_REENTRANT
  struct CPP        *cpp;
#endif

  CT_DEBUG(CTLIB, ("ctparse::parse_buffer( %s, %p, %p, %p )",
           filename ? filename : BUFFER_NAME, pBuf, pCPI, pCPC));

#ifndef UCPP_REENTRANT
  g_current_cpi = pCPI;
#endif

  /*----------------------------------*/
  /* Initialize parse info structures */
  /*----------------------------------*/

  if (!pCPI->available)
  {
    assert(pCPI->enums == NULL);
    assert(pCPI->structs == NULL);
    assert(pCPI->typedef_lists == NULL);

    assert(pCPI->htEnumerators == NULL);
    assert(pCPI->htEnums == NULL);
    assert(pCPI->htStructs == NULL);
    assert(pCPI->htTypedefs == NULL);
    assert(pCPI->htFiles == NULL);

    CT_DEBUG(CTLIB, ("creating linked lists"));

    pCPI->enums         = LL_new();
    pCPI->structs       = LL_new();
    pCPI->typedef_lists = LL_new();

    pCPI->htEnumerators = HT_new_ex(5, HT_AUTOGROW);
    pCPI->htEnums       = HT_new_ex(4, HT_AUTOGROW);
    pCPI->htStructs     = HT_new_ex(4, HT_AUTOGROW);
    pCPI->htTypedefs    = HT_new_ex(4, HT_AUTOGROW);
    pCPI->htFiles       = HT_new_ex(3, HT_AUTOGROW);

    pCPI->errorStack    = LL_new();

    pCPI->available     = 1;
  }
  else if (pCPI->enums != NULL && pCPI->structs != NULL &&
           pCPI->typedef_lists != NULL)
  {
    CT_DEBUG(CTLIB, ("re-using linked lists"));
    pop_all_errors(pCPI);
  }
  else
    fatal_error("CParseInfo is inconsistent!");

  /* make sure we trigger update_parse_info() afterwards */
  pCPI->ready = 0;

  /*----------------------------*/
  /* Try to open the input file */
  /*----------------------------*/

  infile = NULL;

  if (filename != NULL)
  {
    file = get_path_name(NULL, filename);

    CT_DEBUG(CTLIB, ("Trying '%s'...", file));

    infile = fopen(file, "r");

    if (infile == NULL)
    {
      LL_foreach(str, pCPC->includes)
      {
        Free(file);

        file = get_path_name(str, filename);

        CT_DEBUG(CTLIB, ("Trying '%s'...", file));

        if((infile = fopen(file, "r")) != NULL)
          break;
      }

      if (infile == NULL)
      {
        Free(file);
        push_error(pCPI, "Cannot find input file '%s'", filename);
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

  CT_DEBUG(CTLIB, ("initializing preprocessor"));

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

  CT_DEBUG(CTLIB, ("configuring preprocessor"));

  init_include_path(aUCPP_ NULL);

  if (filename != NULL)
  {
    set_init_filename(aUCPP_ file, 1);
    Free(file);
  }
  else
    set_init_filename(aUCPP_ BUFFER_NAME, 0);

  init_lexer_state(&lexer);
  init_lexer_mode(&lexer);

  lexer.flags |= HANDLE_ASSERTIONS
              |  HANDLE_PRAGMA
              |  LINE_NUM;

  if (pCPC->issue_warnings)
    lexer.flags |= WARN_STANDARD
                |  WARN_ANNOYING
                |  WARN_TRIGRAPHS
                |  WARN_TRIGRAPHS_MORE;

  if (pCPC->has_cpp_comments)
    lexer.flags |= CPLUSPLUS_COMMENTS;

  if (pCPC->has_macro_vaargs)
    lexer.flags |= MACRO_VAARG;

  if (infile != NULL)
  {
    lexer.input        = infile;
  }
  else
  {
    lexer.input        = NULL;
    lexer.input_string = (unsigned char *) pBuf->buffer;
    lexer.pbuf         = pBuf->pos;
    lexer.ebuf         = pBuf->length;
  }

  /* Add includes */

  LL_foreach(str, pCPC->includes)
  {
    CT_DEBUG(CTLIB, ("adding include path '%s'", str));
    add_incpath(aUCPP_ str);
  }

  /* Make defines */

  LL_foreach(str, pCPC->defines)
  {
    CT_DEBUG(CTLIB, ("defining macro '%s'", str));
    (void) define_macro(aUCPP_ &lexer, str);
  }

  /* Make assertions */

  LL_foreach(str, pCPC->assertions)
  {
    CT_DEBUG(CTLIB, ("making assertion '%s'", str));
    (void) make_assertion(aUCPP_ str);
  }

  enter_file(aUCPP_ &lexer, lexer.flags);

  /*---------------------*/
  /* Create the C parser */
  /*---------------------*/

  pState = c_parser_new(pCPC, pCPI, aUCPP_ &lexer);

  /*-----------------*/
  /* Parse the input */
  /*-----------------*/

  if (pCPC->disable_parser)
  {
    CT_DEBUG(CTLIB, ("parser is disabled, running only preprocessor"));
    rval = 0;
  }
  else
  {
    CT_DEBUG(CTLIB, ("entering parser"));
    rval = c_parser_run(pState);
    CT_DEBUG(CTLIB, ("c_parse() returned %d", rval));
  }

  /*-------------------------------*/
  /* Finish parsing (cleanup ucpp) */
  /*-------------------------------*/

  if (rval || pCPC->disable_parser)
    while (lex(aUCPP_ &lexer) < CPPERR_EOF);

  (void) check_cpp_errors(aUCPP_ &lexer);

  if (DEBUG_FLAG(PREPROC))
  {
#ifdef UCPP_REENTRANT
    cpp->
#endif
    emit_output = stderr;  /* the best we can get here... */
    print_defines(aUCPP);
  }

  free_lexer_state(&lexer);
  wipeout(aUCPP);

#ifdef UCPP_REENTRANT
  del_cpp(cpp);
#endif

#ifdef MEM_DEBUG
  report_leaks();
#endif

  /*----------------------*/
  /* Cleanup the C parser */
  /*----------------------*/

  c_parser_delete(pState);

  /* Invalidate the buffer name in the parsed files table */

  if (filename == NULL)
    ((FileInfo *) HT_get(pCPI->htFiles, BUFFER_NAME, 0, 0))->valid = 0;

#if !defined NDEBUG && defined CTLIB_DEBUGGING
  if (DEBUG_FLAG(HASH))
  {
    HT_dump(pCPI->htEnumerators);
    HT_dump(pCPI->htEnums);
    HT_dump(pCPI->htStructs);
    HT_dump(pCPI->htTypedefs);
    HT_dump(pCPI->htFiles);
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

void init_parse_info(CParseInfo *pCPI)
{
  CT_DEBUG( CTLIB, ("ctparse::init_parse_info()") );

  if (pCPI)
  {
    pCPI->typedef_lists = NULL;
    pCPI->structs       = NULL;
    pCPI->enums         = NULL;

    pCPI->htEnumerators = NULL;
    pCPI->htEnums       = NULL;
    pCPI->htStructs     = NULL;
    pCPI->htTypedefs    = NULL;
    pCPI->htFiles       = NULL;

    pCPI->errorStack    = NULL;

    pCPI->available     = 0;
    pCPI->ready         = 0;
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

void free_parse_info(CParseInfo *pCPI)
{
  CT_DEBUG(CTLIB, ("ctparse::free_parse_info()"));

  if (pCPI)
  {
    if (pCPI->available)
    {
      LL_destroy(pCPI->enums,         (LLDestroyFunc) enumspec_delete);
      LL_destroy(pCPI->structs,       (LLDestroyFunc) struct_delete);
      LL_destroy(pCPI->typedef_lists, (LLDestroyFunc) typedef_list_delete);

      HT_destroy(pCPI->htEnumerators, NULL);
      HT_destroy(pCPI->htEnums,       NULL);
      HT_destroy(pCPI->htStructs,     NULL);
      HT_destroy(pCPI->htTypedefs,    NULL);

      HT_destroy(pCPI->htFiles,       (LLDestroyFunc) fileinfo_delete);

      if (pCPI->errorStack)
      {
        pop_all_errors(pCPI);
        LL_delete(pCPI->errorStack);
      }
    }

    init_parse_info(pCPI);  /* make sure everything is NULL'd */
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

void reset_parse_info(CParseInfo *pCPI)
{
  Struct *pStruct;
  TypedefList *pTDL;
  Typedef *pTD;

  CT_DEBUG(CTLIB, ("ctparse::reset_parse_info(): got %d struct(s)",
                   LL_count(pCPI->structs)));

  /* clear size and align fields */
  LL_foreach(pStruct, pCPI->structs)
  {
    CT_DEBUG(CTLIB, ("resetting struct '%s':", pStruct->identifier[0] ?
                     pStruct->identifier : "<no-identifier>"));

    pStruct->align = 0;
    pStruct->size  = 0;
  }

  LL_foreach(pTDL, pCPI->typedef_lists)
    LL_foreach(pTD, pTDL->typedefs)
    {
      pTD->pDecl->size      = -1;
      pTD->pDecl->item_size = -1;
    }

  pCPI->ready = 0;
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

void update_parse_info(CParseInfo *pCPI, const CParseConfig *pCPC)
{
  Struct *pStruct;
  TypedefList *pTDL;
  Typedef *pTD;

  CT_DEBUG(CTLIB, ("ctparse::update_parse_info(): got %d struct(s)",
                   LL_count(pCPI->structs)));

  /* compute size and alignment */
  LL_foreach(pStruct, pCPI->structs)
  {
    CT_DEBUG(CTLIB, ("updating struct '%s':", pStruct->identifier[0] ?
                     pStruct->identifier : "<no-identifier>"));

    if (pStruct->align == 0)
      pCPC->layout_compound(&pCPC->layout, pStruct);
  }

  LL_foreach(pTDL, pCPI->typedef_lists)
    LL_foreach(pTD, pTDL->typedefs)
      if (pTD->pDecl->size < 0)
      {
        unsigned size, item_size;

        if (pCPC->get_type_info(&pCPC->layout, pTD->pType, pTD->pDecl,
                                "si", &size, &item_size) == GTI_NO_ERROR)
        {
          pTD->pDecl->size      = (int) size;
          pTD->pDecl->item_size = (int) item_size;
        }
      }

  pCPI->ready = 1;
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

#define PTR_NOT_FOUND(ptr)                                                     \
          fatal_error("FATAL: pointer " #ptr " (%p) not found! (%s:%d)\n",     \
                      ptr, __FILE__, __LINE__)

#define REMAP_PTR(what, target)                                                \
        do {                                                                   \
          if (target != NULL)                                                  \
          {                                                                    \
            void *ptr = HT_get(ptrmap, (const char *) &target,                 \
                               sizeof(void *), 0);                             \
                                                                               \
            CT_DEBUG(CTLIB, (#what ": %p => %p", target, ptr));                \
                                                                               \
            if (ptr)                                                           \
              target = ptr;                                                    \
            else                                                               \
              PTR_NOT_FOUND((void *) target);                                  \
          }                                                                    \
        } while (0)

void clone_parse_info(CParseInfo *pDest, const CParseInfo *pSrc)
{
  HashTable      ptrmap;
  EnumSpecifier *pES;
  Struct        *pStruct;
  TypedefList   *pTDL;

  CT_DEBUG(CTLIB, ("ctparse::clone_parse_info()"));

  if (!pSrc->available)
    return;  /* don't clone empty objects */

  assert(pSrc->enums != NULL);
  assert(pSrc->structs != NULL);
  assert(pSrc->typedef_lists != NULL);

  assert(pSrc->htEnumerators != NULL);
  assert(pSrc->htEnums != NULL);
  assert(pSrc->htStructs != NULL);
  assert(pSrc->htTypedefs != NULL);
  assert(pSrc->htFiles != NULL);

  ptrmap = HT_new_ex(3, HT_AUTOGROW);

  pDest->enums         = LL_new();
  pDest->structs       = LL_new();
  pDest->typedef_lists = LL_new();
  pDest->htEnumerators = HT_new_ex(HT_size(pSrc->htEnumerators), HT_AUTOGROW);
  pDest->htEnums       = HT_new_ex(HT_size(pSrc->htEnums), HT_AUTOGROW);
  pDest->htStructs     = HT_new_ex(HT_size(pSrc->htStructs), HT_AUTOGROW);
  pDest->htTypedefs    = HT_new_ex(HT_size(pSrc->htTypedefs), HT_AUTOGROW);
  pDest->errorStack    = LL_new();
  pDest->available     = pSrc->available;
  pDest->ready         = pSrc->ready;

  CT_DEBUG(CTLIB, ("cloning enums"));

  LL_foreach(pES, pSrc->enums)
  {
    Enumerator    *pEnum;
    EnumSpecifier *pClone = enumspec_clone(pES);

    CT_DEBUG(CTLIB, ("storing pointer to map: %p <=> %p", pES, pClone));
    HT_store(ptrmap, (const char *) &pES, sizeof(pES), 0, pClone);
    LL_push(pDest->enums, pClone);

    if (pClone->identifier[0])
      HT_store(pDest->htEnums, pClone->identifier, 0, 0, pClone);

    LL_foreach(pEnum, pClone->enumerators)
      HT_store(pDest->htEnumerators, pEnum->identifier, 0, 0, pEnum);
  }

  CT_DEBUG(CTLIB, ("cloning structs"));

  LL_foreach(pStruct, pSrc->structs)
  {
    Struct *pClone = struct_clone(pStruct);

    CT_DEBUG(CTLIB, ("storing pointer to map: %p <=> %p", pStruct, pClone));
    HT_store(ptrmap, (const char *) &pStruct, sizeof(pStruct), 0, pClone);
    LL_push(pDest->structs, pClone);

    if (pClone->identifier[0])
      HT_store(pDest->htStructs, pClone->identifier, 0, 0, pClone);
  }

  CT_DEBUG(CTLIB, ("cloning typedefs"));

  LL_foreach(pTDL, pSrc->typedef_lists)
  {
    TypedefList *pClone = typedef_list_clone(pTDL);
    Typedef *pOld, *pNew;

    LL_reset(pTDL->typedefs);
    LL_reset(pClone->typedefs);

    while ((pOld = LL_next(pTDL->typedefs))   != NULL &&
           (pNew = LL_next(pClone->typedefs)) != NULL)
    {
      CT_DEBUG(CTLIB, ("storing pointer to map: %p <=> %p", pOld, pNew));
      HT_store(ptrmap, (const char *) &pOld, sizeof(pOld), 0, pNew);
      HT_store(pDest->htTypedefs, pNew->pDecl->identifier, 0, 0, pNew);
    }

    LL_push(pDest->typedef_lists, pClone);
  }

  CT_DEBUG(CTLIB, ("cloning file information"));

  {
    void *pOld, *pNew;

    pDest->htFiles = HT_clone(pSrc->htFiles, (HTCloneFunc) fileinfo_clone);

    HT_reset(pSrc->htFiles);
    HT_reset(pDest->htFiles);

    while (HT_next(pSrc->htFiles, NULL, NULL, &pOld) &&
           HT_next(pDest->htFiles, NULL, NULL, &pNew))
    {
      CT_DEBUG(CTLIB, ("storing pointer to map: %p <=> %p", pOld, pNew));
      HT_store(ptrmap, (const char *) &pOld, sizeof(pOld), 0, pNew);
    }
  }

  CT_DEBUG(CTLIB, ("remapping pointers for enums"));

  LL_foreach(pES, pDest->enums)
    REMAP_PTR(EnumSpec, pES->context.pFI);

  CT_DEBUG(CTLIB, ("remapping pointers for structs"));

  LL_foreach(pStruct, pDest->structs)
  {
    StructDeclaration *pStructDecl;

    CT_DEBUG(CTLIB, ("remapping pointers for struct @ %p ('%s')",
                     pStruct, pStruct->identifier));

    LL_foreach(pStructDecl, pStruct->declarations)
      REMAP_PTR(StructDecl, pStructDecl->type.ptr);

    REMAP_PTR(Struct, pStruct->context.pFI);
  }

  CT_DEBUG(CTLIB, ("remapping pointers for typedef lists"));

  LL_foreach(pTDL, pDest->typedef_lists)
    REMAP_PTR(TypedefList, pTDL->type.ptr);

  HT_destroy(ptrmap, NULL);
}

#undef REMAP_PTR
#undef PTR_NOT_FOUND

