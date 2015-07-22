/*******************************************************************************
*
* MODULE: sourcify.c
*
********************************************************************************
*
* DESCRIPTION: C::B::C sourcify
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2005/02/21 09:18:40 +0000 $
* $Revision: 7 $
* $Source: /cbc/sourcify.c $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"


/*===== LOCAL INCLUDES =======================================================*/

#include "ctlib/cttype.h"

#include "cbc/cbc.h"
#include "cbc/idl.h"
#include "cbc/sourcify.h"
#include "cbc/util.h"


/*===== DEFINES ==============================================================*/

#define T_ALREADY_DUMPED   T_USER_FLAG_1

#define F_NEWLINE          0x00000001
#define F_KEYWORD          0x00000002
#define F_DONT_EXPAND      0x00000004
#define F_PRAGMA_PACK_POP  0x00000008

#define SRC_INDENT                       \
        STMT_START {                     \
          if (level > 0)                 \
            add_indent(aTHX_ s, level);  \
        } STMT_END

#define CHECK_SET_KEYWORD                \
        STMT_START {                     \
          if (pSS->flags & F_KEYWORD)    \
            sv_catpv(s, " ");            \
          else                           \
            SRC_INDENT;                  \
          pSS->flags &= ~F_NEWLINE;      \
          pSS->flags |= F_KEYWORD;       \
        } STMT_END


/*===== TYPEDEFS =============================================================*/

typedef struct {
  U32      flags;
  unsigned pack;
} SourcifyState;


/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

static void check_define_type(pTHX_ SourcifyConfig *pSC, SV *str, TypeSpec *pTS);

static void add_type_spec_string_rec(pTHX_ SourcifyConfig *pSC, SV *str, SV *s,
                                     TypeSpec *pTS, int level, SourcifyState *pSS);
static void add_enum_spec_string_rec(pTHX_ SourcifyConfig *pSC, SV *str, SV *s,
                                     EnumSpecifier *pES, int level, SourcifyState *pSS);
static void add_struct_spec_string_rec(pTHX_ SourcifyConfig *pSC, SV *str, SV *s,
                                       Struct *pStruct, int level, SourcifyState *pSS);

static void add_typedef_list_decl_string(pTHX_ SV *str, TypedefList *pTDL);
static void add_typedef_list_spec_string(pTHX_ SourcifyConfig *pSC, SV *str, TypedefList *pTDL);
static void add_enum_spec_string(pTHX_ SourcifyConfig *pSC, SV *str, EnumSpecifier *pES);
static void add_struct_spec_string(pTHX_ SourcifyConfig *pSC, SV *str, Struct *pStruct);


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*******************************************************************************
*
*   ROUTINE: check_define_type
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

static void check_define_type(pTHX_ SourcifyConfig *pSC, SV *str, TypeSpec *pTS)
{
  u_32 flags = pTS->tflags;

  CT_DEBUG(MAIN, (XSCLASS "::check_define_type( pTS=(tflags=0x%08lX, ptr=%p) )",
                  (unsigned long) pTS->tflags, pTS->ptr));

  if (flags & T_TYPE)
  {
    Typedef *pTypedef= (Typedef *) pTS->ptr;

    while (!pTypedef->pDecl->pointer_flag && pTypedef->pType->tflags & T_TYPE)
      pTypedef = (Typedef *) pTypedef->pType->ptr;

    if (pTypedef->pDecl->pointer_flag)
      return;

    pTS   = pTypedef->pType;
    flags = pTS->tflags;
  }

  if (flags & T_ENUM)
  {
    EnumSpecifier *pES = (EnumSpecifier *) pTS->ptr;

    if (pES && (pES->tflags & T_ALREADY_DUMPED) == 0)
      add_enum_spec_string(aTHX_ pSC, str, pES);
  }
  else if (flags & (T_STRUCT|T_UNION))
  {
    Struct *pStruct = (Struct *) pTS->ptr;

    if (pStruct && (pStruct->tflags & T_ALREADY_DUMPED) == 0)
      add_struct_spec_string(aTHX_ pSC, str, pStruct);
  }
}

/*******************************************************************************
*
*   ROUTINE: add_type_spec_string_rec
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

static void add_type_spec_string_rec(pTHX_ SourcifyConfig *pSC, SV *str, SV *s,
                                     TypeSpec *pTS, int level, SourcifyState *pSS)
{
  u_32 flags = pTS->tflags;

  CT_DEBUG(MAIN, (XSCLASS "::add_type_spec_string_rec( pTS=(tflags=0x%08lX, ptr=%p"
                          "), level=%d, pSS->flags=0x%08lX, pSS->pack=%u )",
                          (unsigned long) pTS->tflags, pTS->ptr, level,
                          (unsigned long) pSS->flags, pSS->pack));

  if (flags & T_TYPE)
  {
    Typedef *pTypedef= (Typedef *) pTS->ptr;

    if (pTypedef && pTypedef->pDecl->identifier[0])
    {
      CHECK_SET_KEYWORD;
      sv_catpv(s, pTypedef->pDecl->identifier);
    }
  }
  else if (flags & T_ENUM)
  {
    EnumSpecifier *pES = (EnumSpecifier *) pTS->ptr;

    if (pES)
    {
      if (pES->identifier[0] && ((pES->tflags & T_ALREADY_DUMPED) ||
                                 (pSS->flags & F_DONT_EXPAND)))
      {
        CHECK_SET_KEYWORD;
        sv_catpvf(s, "enum %s", pES->identifier);
      }
      else
        add_enum_spec_string_rec(aTHX_ pSC, str, s, pES, level, pSS);
    }
  }
  else if (flags & (T_STRUCT|T_UNION))
  {
    Struct *pStruct = (Struct *) pTS->ptr;

    if (pStruct)
    {
      if (pStruct->identifier[0] && ((pStruct->tflags & T_ALREADY_DUMPED) ||
                                     (pSS->flags & F_DONT_EXPAND)))
      {
        CHECK_SET_KEYWORD;
        sv_catpvf(s, "%s %s", flags & T_UNION ? "union" : "struct",
                              pStruct->identifier);
      }
      else
        add_struct_spec_string_rec(aTHX_ pSC, str, s, pStruct, level, pSS);
    }
  }
  else
  {
    CHECK_SET_KEYWORD;
    get_basic_type_spec_string(aTHX_ &s, flags);
  }
}

/*******************************************************************************
*
*   ROUTINE: add_enum_spec_string_rec
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

static void add_enum_spec_string_rec(pTHX_ SourcifyConfig *pSC, SV *str, SV *s,
                                     EnumSpecifier *pES, int level, SourcifyState *pSS)
{
  CT_DEBUG(MAIN, (XSCLASS "::add_enum_spec_string_rec( pES=(identifier=\"%s\"),"
                          " level=%d, pSS->flags=0x%08lX, pSS->pack=%u )",
                          pES->identifier, level, (unsigned long) pSS->flags, pSS->pack));

  pES->tflags |= T_ALREADY_DUMPED;

  if (pSC->context)
  {
    if ((pSS->flags & F_NEWLINE) == 0)
    {
      sv_catpv(s, "\n");
      pSS->flags &= ~F_KEYWORD;
      pSS->flags |= F_NEWLINE;
    }
    sv_catpvf(s, "#line %lu \"%s\"\n", pES->context.line,
                                       pES->context.pFI->name);
  }

  if (pSS->flags & F_KEYWORD)
    sv_catpv(s, " ");
  else
    SRC_INDENT;

  pSS->flags &= ~(F_NEWLINE|F_KEYWORD);

  sv_catpv(s, "enum");
  if (pES->identifier[0])
    sv_catpvf(s, " %s", pES->identifier);

  if (pES->enumerators)
  {
    Enumerator *pEnum;
    int         first = 1;
    Value       lastVal;

    sv_catpv(s, "\n");
    SRC_INDENT;
    sv_catpv(s, "{");

    LL_foreach(pEnum, pES->enumerators)
    {
      if (!first)
        sv_catpv(s, ",");

      sv_catpv(s, "\n");
      SRC_INDENT;

      if (( first && pEnum->value.iv == 0) ||
          (!first && pEnum->value.iv == lastVal.iv + 1))
        sv_catpvf(s, "\t%s", pEnum->identifier);
      else
        sv_catpvf(s, "\t%s = %ld", pEnum->identifier, pEnum->value.iv);

      if (first)
        first = 0;

      lastVal = pEnum->value;
    }

    sv_catpv(s, "\n");
    SRC_INDENT;
    sv_catpv(s, "}");
  }
}

/*******************************************************************************
*
*   ROUTINE: add_struct_spec_string_rec
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

static void add_struct_spec_string_rec(pTHX_ SourcifyConfig *pSC, SV *str, SV *s,
                                       Struct *pStruct, int level, SourcifyState *pSS)
{
  int pack_pushed;

  CT_DEBUG(MAIN, (XSCLASS "::add_struct_spec_string_rec( pStruct=(identifier="
                          "\"%s\", pack=%d, tflags=0x%08lX), level=%d"
                          " pSS->flags=0x%08lX, pSS->pack=%u )",
                          pStruct->identifier,
                          pStruct->pack, (unsigned long) pStruct->tflags,
                          level, (unsigned long) pSS->flags, pSS->pack));

  pStruct->tflags |= T_ALREADY_DUMPED;

  pack_pushed = pStruct->declarations
             && pStruct->pack
             && pStruct->pack != pSS->pack;

  if (pack_pushed)
  {
    if ((pSS->flags & F_NEWLINE) == 0)
    {
      sv_catpv(s, "\n");
      pSS->flags &= ~F_KEYWORD;
      pSS->flags |= F_NEWLINE;
    }
    sv_catpvf(s, "#pragma pack(push, %u)\n", pStruct->pack);
  }

  if (pSC->context)
  {
    if ((pSS->flags & F_NEWLINE) == 0)
    {
      sv_catpv(s, "\n");
      pSS->flags &= ~F_KEYWORD;
      pSS->flags |= F_NEWLINE;
    }
    sv_catpvf(s, "#line %lu \"%s\"\n", pStruct->context.line,
                                       pStruct->context.pFI->name);
  }

  if (pSS->flags & F_KEYWORD)
    sv_catpv(s, " ");
  else
    SRC_INDENT;

  pSS->flags &= ~(F_NEWLINE|F_KEYWORD);

  sv_catpv(s, pStruct->tflags & T_STRUCT ? "struct" : "union");

  if (pStruct->identifier[0])
    sv_catpvf(s, " %s", pStruct->identifier);

  if (pStruct->declarations)
  {
    StructDeclaration *pStructDecl;

    sv_catpv(s, "\n");
    SRC_INDENT;
    sv_catpv(s, "{\n");

    LL_foreach(pStructDecl, pStruct->declarations)
    {
      Declarator *pDecl;
      int first = 1, need_def = 0;
      SourcifyState ss;

      ss.flags = F_NEWLINE;
      ss.pack  = pack_pushed ? pStruct->pack : 0;

      LL_foreach(pDecl, pStructDecl->declarators)
        if (pDecl->pointer_flag == 0)
        {
          need_def = 1;
          break;
        }

      if (!need_def)
        ss.flags |= F_DONT_EXPAND;

      add_type_spec_string_rec(aTHX_ pSC, str, s, &pStructDecl->type, level+1, &ss);

      ss.flags &= ~F_DONT_EXPAND;

      if (ss.flags & F_NEWLINE)
        add_indent(aTHX_ s, level+1);
      else if (pStructDecl->declarators)
        sv_catpv(s, " ");

      LL_foreach(pDecl, pStructDecl->declarators)
      {
        Value *pValue;

        if (first)
          first = 0;
        else
          sv_catpv(s, ", ");

        if (pDecl->bitfield_size >= 0)
        {
          sv_catpvf(s, "%s:%d", pDecl->identifier[0] != '\0'
                                ? pDecl->identifier : "",
                                pDecl->bitfield_size);
        }
        else {
          sv_catpvf(s, "%s%s", pDecl->pointer_flag ? "*" : "",
                               pDecl->identifier);

          LL_foreach(pValue, pDecl->array)
            sv_catpvf(s, "[%ld]", pValue->iv);
        }
      }

      sv_catpv(s, ";\n");

      if (ss.flags & F_PRAGMA_PACK_POP)
        sv_catpv(s, "#pragma pack(pop)\n");

      if (need_def)
        check_define_type(aTHX_ pSC, str, &pStructDecl->type);
    }

    SRC_INDENT;
    sv_catpv(s, "}");
  }

  if (pack_pushed)
    pSS->flags |= F_PRAGMA_PACK_POP;
}

/*******************************************************************************
*
*   ROUTINE: add_typedef_list_decl_string
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

static void add_typedef_list_decl_string(pTHX_ SV *str, TypedefList *pTDL)
{
  Typedef *pTypedef;
  int first = 1;

  CT_DEBUG(MAIN, (XSCLASS "::add_typedef_list_decl_string( pTDL=%p )", pTDL));

  LL_foreach(pTypedef, pTDL->typedefs)
  {
    Declarator *pDecl = pTypedef->pDecl;
    Value *pValue;

    if (first)
      first = 0;
    else
      sv_catpv(str, ", ");

    sv_catpvf(str, "%s%s", pDecl->pointer_flag ? "*" : "", pDecl->identifier);

    LL_foreach(pValue, pDecl->array)
      sv_catpvf(str, "[%ld]", pValue->iv);
  }
}

/*******************************************************************************
*
*   ROUTINE: add_typedef_list_spec_string
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

static void add_typedef_list_spec_string(pTHX_ SourcifyConfig *pSC, SV *str, TypedefList *pTDL)
{
  SV *s = newSVpv("typedef", 0);
  SourcifyState ss;

  CT_DEBUG(MAIN, (XSCLASS "::add_typedef_list_spec_string( pTDL=%p )", pTDL));

  ss.flags = F_KEYWORD;
  ss.pack  = 0;

  add_type_spec_string_rec(aTHX_ pSC, str, s, &pTDL->type, 0, &ss);

  if ((ss.flags & F_NEWLINE) == 0)
    sv_catpv(s, " ");

  add_typedef_list_decl_string(aTHX_ s, pTDL);

  sv_catpv(s, ";\n");

  if (ss.flags & F_PRAGMA_PACK_POP)
    sv_catpv(s, "#pragma pack(pop)\n");

  sv_catsv(str, s);

  SvREFCNT_dec(s);
}

/*******************************************************************************
*
*   ROUTINE: add_enum_spec_string
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

static void add_enum_spec_string(pTHX_ SourcifyConfig *pSC, SV *str, EnumSpecifier *pES)
{
  SV *s = newSVpvn("", 0);
  SourcifyState ss;

  CT_DEBUG(MAIN, (XSCLASS "::add_enum_spec_string( pES=%p )", pES));

  ss.flags = 0;
  ss.pack  = 0;

  add_enum_spec_string_rec(aTHX_ pSC, str, s, pES, 0, &ss);
  sv_catpv(s, ";\n");
  sv_catsv(str, s);

  SvREFCNT_dec(s);
}

/*******************************************************************************
*
*   ROUTINE: add_struct_spec_string
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

static void add_struct_spec_string(pTHX_ SourcifyConfig *pSC, SV *str, Struct *pStruct)
{
  SV *s = newSVpvn("", 0);
  SourcifyState ss;

  CT_DEBUG(MAIN, (XSCLASS "::add_struct_spec_string( pStruct=%p )", pStruct));

  ss.flags = 0;
  ss.pack  = 0;

  add_struct_spec_string_rec(aTHX_ pSC, str, s, pStruct, 0, &ss);
  sv_catpv(s, ";\n");

  if (ss.flags & F_PRAGMA_PACK_POP)
    sv_catpv(s, "#pragma pack(pop)\n");

  sv_catsv(str, s);

  SvREFCNT_dec(s);
}

/*******************************************************************************
*
*   ROUTINE: get_sourcify_config_option
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Aug 2003
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

#include "token/t_sourcify.c"


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: get_sourcify_config
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Aug 2003
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

void get_sourcify_config(pTHX_ HV *cfg, SourcifyConfig *pSC)
{
  HE *opt;

  (void) hv_iterinit(cfg);

  while ((opt = hv_iternext(cfg)) != NULL)
  {
    const char *key;
    I32 keylen;
    SV *value;

    key   = hv_iterkey(opt, &keylen);
    value = hv_iterval(cfg, opt);

    switch (get_sourcify_config_option(key))
    {
      case SOURCIFY_OPTION_Context:
        pSC->context = SvTRUE(value);
        break;

      default:
        Perl_croak(aTHX_ "Invalid option '%s'", key);
    }
  }
}

/*******************************************************************************
*
*   ROUTINE: get_parsed_definitions_string
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

SV *get_parsed_definitions_string(pTHX_ CParseInfo *pCPI, SourcifyConfig *pSC)
{
  TypedefList   *pTDL;
  EnumSpecifier *pES;
  Struct        *pStruct;
  int            fTypedefPre = 0, fTypedef = 0, fEnum = 0,
                 fStruct = 0, fUndefEnum = 0, fUndefStruct = 0;

  SV *s = newSVpvn("", 0);

  CT_DEBUG(MAIN, (XSCLASS "::get_parsed_definitions_string( pCPI=%p, pSC=%p )", pCPI, pSC));

  /* typedef predeclarations */

  LL_foreach(pTDL, pCPI->typedef_lists)
  {
    u_32 tflags = pTDL->type.tflags;

    if ((tflags & (T_ENUM|T_STRUCT|T_UNION|T_TYPE)) == 0)
    {
      if (!fTypedefPre)
      {
        sv_catpv(s, "/* typedef predeclarations */\n\n");
        fTypedefPre = 1;
      }
      add_typedef_list_spec_string(aTHX_ pSC, s, pTDL);
    }
    else
    {
      const char *what = NULL, *ident;

      if (tflags & T_ENUM)
      {
        EnumSpecifier *pES = (EnumSpecifier *) pTDL->type.ptr;
        if (pES && pES->identifier[0] != '\0')
        {
          what  = "enum";
          ident = pES->identifier;
        }
      }
      else if (tflags & (T_STRUCT|T_UNION))
      {
        Struct *pStruct = (Struct *) pTDL->type.ptr;
        if (pStruct && pStruct->identifier[0] != '\0')
        {
          what  = pStruct->tflags & T_STRUCT ? "struct" : "union";
          ident = pStruct->identifier;
        }
      }

      if (what != NULL)
      {
        if (!fTypedefPre)
        {
          sv_catpv(s, "/* typedef predeclarations */\n\n");
          fTypedefPre = 1;
        }
        sv_catpvf(s, "typedef %s %s ", what, ident);
        add_typedef_list_decl_string(aTHX_ s, pTDL);
        sv_catpv(s, ";\n");
      }
    }
  }

  /* typedefs */

  LL_foreach(pTDL, pCPI->typedef_lists)
    if (pTDL->type.ptr != NULL)
      if (((pTDL->type.tflags & T_ENUM) &&
           ((EnumSpecifier *) pTDL->type.ptr)->identifier[0] == '\0') ||
          ((pTDL->type.tflags & (T_STRUCT|T_UNION)) &&
           ((Struct *) pTDL->type.ptr)->identifier[0] == '\0') ||
          (pTDL->type.tflags & T_TYPE))
      {
        if (!fTypedef)
        {
          sv_catpv(s, "\n\n/* typedefs */\n\n");
          fTypedef = 1;
        }
        add_typedef_list_spec_string(aTHX_ pSC, s, pTDL);
        sv_catpv(s, "\n");
      }

  /* defined enums */

  LL_foreach(pES, pCPI->enums)
    if (pES->enumerators &&
        pES->identifier[0] != '\0' &&
        (pES->tflags & (T_ALREADY_DUMPED)) == 0)
    {
      if (!fEnum)
      {
        sv_catpv(s, "\n/* defined enums */\n\n");
        fEnum = 1;
      }
      add_enum_spec_string(aTHX_ pSC, s, pES);
      sv_catpv(s, "\n");
    }

  /* defined structs and unions */

  LL_foreach(pStruct, pCPI->structs)
    if(pStruct->declarations &&
       pStruct->identifier[0] != '\0' &&
       (pStruct->tflags & (T_ALREADY_DUMPED)) == 0)
    {
      if (!fStruct)
      {
        sv_catpv(s, "\n/* defined structs and unions */\n\n");
        fStruct = 1;
      }
      add_struct_spec_string(aTHX_ pSC, s, pStruct);
      sv_catpv(s, "\n");
    }

  /* undefined enums */

  LL_foreach(pES, pCPI->enums)
  {
    if ((pES->tflags & T_ALREADY_DUMPED) == 0 && pES->refcount == 0)
    {
      if (pES->enumerators || pES->identifier[0] != '\0')
      {
        if (!fUndefEnum)
        {
          sv_catpv(s, "\n/* undefined enums */\n\n");
          fUndefEnum = 1;
        }
        add_enum_spec_string(aTHX_ pSC, s, pES);
        sv_catpv(s, "\n");
      }
    }

    pES->tflags &= ~T_ALREADY_DUMPED;
  }

  /* undefined structs and unions */

  LL_foreach(pStruct, pCPI->structs)
  {
    if ((pStruct->tflags & T_ALREADY_DUMPED) == 0 && pStruct->refcount == 0)
    {
      if (pStruct->declarations || pStruct->identifier[0] != '\0')
      {
        if (!fUndefStruct)
        {
          sv_catpv(s, "\n/* undefined/unnamed structs and unions */\n\n");
          fUndefStruct = 1;
        }
        add_struct_spec_string(aTHX_ pSC, s, pStruct);
        sv_catpv(s, "\n");
      }
    }

    pStruct->tflags &= ~T_ALREADY_DUMPED;
  }

  return s;
}

