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
* $Date: 2002/04/15 22:26:46 +0100 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.02 $
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

typedef struct {

  CParseInfo   *pCPI;

  LinkedList    curEnumList;
  LinkedList    nodeList,
                arrayList,
                declaratorList,
                declListsList,
                structDeclList,
                structDeclListsList;

  CParseConfig *pCPC;

  PragmaState   pragma;

  struct lexer_state lexer;

  char         *filename;

} ParserState;


/*===== FUNCTION PROTOTYPES ==================================================*/

int c_parse( void *pState );

#endif
