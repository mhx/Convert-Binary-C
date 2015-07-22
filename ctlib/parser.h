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
* $Date: 2002/12/07 17:17:28 +0000 $
* $Revision: 3 $
* $Snapshot: /Convert-Binary-C/0.06 $
* $Source: /ctlib/parser.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _PARSER_H
#define _PARSER_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "ctparse.h"
#include "pragma.h"
#include "util/list.h"
#include "ucpp/cpp.h"


/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

typedef struct _ParserState ParserState;

/*===== FUNCTION PROTOTYPES ==================================================*/

ParserState *c_parser_new( const CParseConfig *pCPC, CParseInfo *pCPI,
                           struct lexer_state *pLexer );

int  c_parser_run( ParserState *pState );

void c_parser_delete( ParserState *pState );

#endif
