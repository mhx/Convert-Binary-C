/*******************************************************************************
*
* HEADER: ctype.h
*
********************************************************************************
*
* DESCRIPTION: ANSI C data type objects
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/11/23 17:08:13 +0000 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.04 $
* $Source: /ctlib/byteorder.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _BYTEORDER_H
#define _BYTEORDER_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "arch.h"


/*===== DEFINES ==============================================================*/



/*===== TYPEDEFS =============================================================*/

typedef struct {
  enum {
    BO_BIG_ENDIAN,
    BO_LITTLE_ENDIAN
  } bo;
} ArchSpecs;

typedef struct {
  union {
    u_64 u;
    i_64 s;
  }     value;
  int   sign;
  char *string;
} IntValue;

/*===== FUNCTION PROTOTYPES ==================================================*/

void fetch_integer( unsigned size, unsigned sign, const void *src,
                    const ArchSpecs *pAS, IntValue *pIV );

void store_integer( unsigned size, void *dest,
                    const ArchSpecs *pAS, IntValue *pIV );

#endif
