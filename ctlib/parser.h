/*******************************************************************************
*
* HEADER: parser.h
*
********************************************************************************
*
* DESCRIPTION: C parser
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/01 11:29:56 +0000 $
* $Revision: 7 $
* $Snapshot: /Convert-Binary-C/0.12 $
* $Source: /ctlib/parser.h $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_PARSER_H
#define _CTLIB_PARSER_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "ctparse.h"


/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

typedef struct _ParserState ParserState;

typedef struct {
  const int   token;
  const char *name;
} CKeywordToken;

struct lexer_state;


/*===== FUNCTION PROTOTYPES ==================================================*/

const CKeywordToken *get_c_keyword_token( const char *name );
const CKeywordToken *get_skip_token( void );

ParserState *c_parser_new( const CParseConfig *pCPC, CParseInfo *pCPI,
                           struct lexer_state *pLexer );

int  c_parser_run( ParserState *pState );

void c_parser_delete( ParserState *pState );

#endif
