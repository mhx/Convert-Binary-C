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
* $Date: 2005/01/23 11:49:41 +0000 $
* $Revision: 9 $
* $Source: /ctlib/byteorder.h $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
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
    AS_BO_BIG_ENDIAN,
    AS_BO_LITTLE_ENDIAN
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

#define string_is_integer CTlib_string_is_integer
int string_is_integer(const char *pStr);

#define fetch_integer CTlib_fetch_integer
void fetch_integer( unsigned size, unsigned sign, const void *src,
                    const ArchSpecs *pAS, IntValue *pIV );

#define store_integer CTlib_store_integer
void store_integer( unsigned size, void *dest,
                    const ArchSpecs *pAS, IntValue *pIV );

#endif
