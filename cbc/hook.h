/*******************************************************************************
*
* HEADER: hook.h
*
********************************************************************************
*
* DESCRIPTION: C::B::C hooks
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2006/01/01 09:37:57 +0000 $
* $Revision: 8 $
* $Source: /cbc/hook.h $
*
********************************************************************************
*
* Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CBC_HOOK_H
#define _CBC_HOOK_H

/*===== GLOBAL INCLUDES ======================================================*/


/*===== LOCAL INCLUDES =======================================================*/


/*===== DEFINES ==============================================================*/


/*===== TYPEDEFS =============================================================*/

typedef enum {
  HOOK_ARG_SELF,
  HOOK_ARG_TYPE,
  HOOK_ARG_DATA,
  HOOK_ARG_HOOK
} HookArgType;

typedef struct {
  SV *sub;
  AV *arg;
} SingleHook;

#include "token/t_hookid.h"

typedef struct {
  SingleHook hooks[HOOKID_COUNT];
} TypeHooks;


/*===== FUNCTION PROTOTYPES ==================================================*/

#define hook_new CBC_hook_new
TypeHooks *hook_new(const TypeHooks *h);

#define hook_update CBC_hook_update
void hook_update(TypeHooks *dst, const TypeHooks *src);

#define hook_delete CBC_hook_delete
void hook_delete(TypeHooks *h);

#define hook_call CBC_hook_call
SV *hook_call(pTHX_ SV *self, const char *id_pre, const char *id,
              const TypeHooks *pTH, enum HookId hook_id, SV *in, int mortal);

#define find_hooks CBC_find_hooks
int find_hooks(pTHX_ const char *type, HV *hooks, TypeHooks *pTH);

#define get_hooks CBC_get_hooks
HV *get_hooks(pTHX_ const TypeHooks *pTH);

#endif
