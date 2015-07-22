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
* $Date: 2002/04/15 22:26:46 +0100 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.05 $
* $Source: /ctlib/pragma.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _PRAGMA_H
#define _PRAGMA_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "util/list.h"
#include "ucpp/cpp.h"


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
