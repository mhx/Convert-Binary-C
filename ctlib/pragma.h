/*******************************************************************************
*
* HEADER: parser.h
*
********************************************************************************
*
* DESCRIPTION: Pragma parser
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/04/12 03:44:14 +0100 $
* $Revision: 5 $
* $Snapshot: /Convert-Binary-C/0.45 $
* $Source: /ctlib/pragma.h $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_PRAGMA_H
#define _CTLIB_PRAGMA_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "util/list.h"


/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

typedef struct {

  char        *str;

  struct {
    LinkedList stack;
    unsigned   current;
  }            pack;

} PragmaState;


/*===== FUNCTION PROTOTYPES ==================================================*/

#define pragma_init CTlib_pragma_init
void pragma_init( PragmaState *pPragma );

#define pragma_free CTlib_pragma_free
void pragma_free( PragmaState *pPragma );

#define pragma_parse CTlib_pragma_parse
int pragma_parse( void *pState );

#endif
