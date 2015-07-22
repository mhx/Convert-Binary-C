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
* $Date: 2003/01/01 11:29:55 +0000 $
* $Revision: 4 $
* $Snapshot: /Convert-Binary-C/0.09 $
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

void pragma_init( PragmaState *pPragma );
void pragma_free( PragmaState *pPragma );

int pragma_parse( void *pState );

#endif
