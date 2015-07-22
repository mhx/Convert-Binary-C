/*******************************************************************************
*
* HEADER: sourcify.h
*
********************************************************************************
*
* DESCRIPTION: C::B::C sourcify
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2011/04/10 11:32:16 +0100 $
* $Revision: 8 $
* $Source: /cbc/sourcify.h $
*
********************************************************************************
*
* Copyright (c) 2002-2011 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CBC_SOURCIFY_H
#define _CBC_SOURCIFY_H

/*===== GLOBAL INCLUDES ======================================================*/


/*===== LOCAL INCLUDES =======================================================*/

#include "ctlib/ctparse.h"


/*===== DEFINES ==============================================================*/


/*===== TYPEDEFS =============================================================*/

typedef struct {
  int      context;
  int      defines;
} SourcifyConfig;


/*===== FUNCTION PROTOTYPES ==================================================*/

#define get_sourcify_config CBC_get_sourcify_config
void get_sourcify_config(pTHX_ HV *cfg, SourcifyConfig *pSC);

#define get_parsed_definitions_string CBC_get_parsed_definitions_string
SV *get_parsed_definitions_string(pTHX_ CParseInfo *pCPI, SourcifyConfig *pSC);


#endif
