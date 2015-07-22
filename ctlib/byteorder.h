/*******************************************************************************
*
* HEADER: byteorder.h
*
********************************************************************************
*
* DESCRIPTION: Architecture independent integer conversion.
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/04/12 03:44:11 +0100 $
* $Revision: 4 $
* $Snapshot: /Convert-Binary-C/0.43 $
* $Source: /ctlib/byteorder.h $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_BYTEORDER_H
#define _CTLIB_BYTEORDER_H

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

#define fetch_integer CTlib_fetch_integer
void fetch_integer( unsigned size, unsigned sign, const void *src,
                    const ArchSpecs *pAS, IntValue *pIV );

#define store_integer CTlib_store_integer
void store_integer( unsigned size, void *dest,
                    const ArchSpecs *pAS, IntValue *pIV );

#endif
