/*******************************************************************************
*
* HEADER: option.h
*
********************************************************************************
*
* DESCRIPTION: C::B::C options
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2005/05/19 18:53:43 +0100 $
* $Revision: 3 $
* $Source: /cbc/option.h $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CBC_OPTION_H
#define _CBC_OPTION_H

/*===== GLOBAL INCLUDES ======================================================*/


/*===== LOCAL INCLUDES =======================================================*/

#include "util/list.h"
#include "cbc/cbc.h"


/*===== DEFINES ==============================================================*/


/*===== TYPEDEFS =============================================================*/


/*===== FUNCTION PROTOTYPES ==================================================*/

#define handle_string_list CBC_handle_string_list
void handle_string_list(pTHX_ const char *option, LinkedList list, SV *sv, SV **rval);

#define handle_option CBC_handle_option
int handle_option(pTHX_ CBC *THIS, SV *opt, SV *sv_val, SV **rval);

#define get_configuration CBC_get_configuration
SV *get_configuration(pTHX_ CBC *THIS);

#define get_native_property CBC_get_native_property
SV *get_native_property(pTHX_ const char *property);

#define post_configure_update CBC_post_configure_update
void post_configure_update(pTHX_ CBC *THIS);

#endif
