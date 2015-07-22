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
* $Date: 2003/04/12 03:44:13 +0100 $
* $Revision: 8 $
* $Snapshot: /Convert-Binary-C/0.43 $
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

#define get_c_keyword_token CTlib_get_c_keyword_token
const CKeywordToken *get_c_keyword_token( const char *name );

#define get_skip_token CTlib_get_skip_token
const CKeywordToken *get_skip_token( void );

#define c_parser_new CTlib_c_parser_new
ParserState *c_parser_new( const CParseConfig *pCPC, CParseInfo *pCPI,
                           struct lexer_state *pLexer );

#define c_parser_run CTlib_c_parser_run
int  c_parser_run( ParserState *pState );

#define c_parser_delete CTlib_c_parser_delete
void c_parser_delete( ParserState *pState );

#endif
