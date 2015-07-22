/*******************************************************************************
*
* HEADER: pack.h
*
********************************************************************************
*
* DESCRIPTION: C::B::C pack/unpack routines
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2005/01/23 11:49:36 +0000 $
* $Revision: 3 $
* $Source: /cbc/pack.h $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CBC_PACK_H
#define _CBC_PACK_H

/*===== GLOBAL INCLUDES ======================================================*/


/*===== LOCAL INCLUDES =======================================================*/

#include "ctlib/cttype.h"

#include "cbc/cbc.h"
#include "cbc/idl.h"

/*===== DEFINES ==============================================================*/

/* values passed between all packing/unpacking routines */
#define pPACKARGS   pTHX_ const CBC *THIS, PackInfo *PACK
#define aPACKARGS   aTHX_ THIS, PACK


/*===== TYPEDEFS =============================================================*/

typedef struct {
  char         *bufptr;
  unsigned      alignment;
  unsigned      align_base;
  Buffer        buf;
  IDList        idl;
  SV           *bufsv;
  SV           *self;
} PackInfo;


/*===== FUNCTION PROTOTYPES ==================================================*/

#define pack_type CBC_pack_type
void pack_type(pPACKARGS, TypeSpec *pTS, Declarator *pDecl, int dimension, SV *sv);

#define unpack_type CBC_unpack_type
SV *unpack_type(pPACKARGS, TypeSpec *pTS, Declarator *pDecl, int dimension);

#endif
