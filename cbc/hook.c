/*******************************************************************************
*
* MODULE: hook.c
*
********************************************************************************
*
* DESCRIPTION: C::B::C hooks
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2005/05/26 12:01:22 +0100 $
* $Revision: 10 $
* $Source: /cbc/hook.c $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"


/*===== LOCAL INCLUDES =======================================================*/

#include "cbc/cbc.h"
#include "cbc/hook.h"
#include "cbc/util.h"


/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

static void hook_fill(pTHX_ const char *hook, const char *type, SingleHook *sth, SV *sub);


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

#include "token/t_hookid.c"

/*******************************************************************************
*
*   ROUTINE: hook_fill
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void hook_fill(pTHX_ const char *hook, const char *type, SingleHook *sth, SV *sub)
{
  if (!DEFINED(sub))
  {
    sth->sub = NULL;
    sth->arg = NULL;
  }
  else if (SvROK(sub))
  {
    SV *sv = SvRV(sub);

    switch (SvTYPE(sv))
    {
      case SVt_PVCV:
        sth->sub = sv;
        sth->arg = NULL;
        break;

      case SVt_PVAV:
        {
          AV *in = (AV *) sv;
          I32 len = av_len(in);

          if (len < 0)
            Perl_croak(aTHX_ "Need at least a code reference in %s hook for "
                             "type '%s'", hook, type);
          else
          {
            SV **pSV = av_fetch(in, 0, 0);

            if (pSV == NULL || !SvROK(*pSV) ||
                SvTYPE(sv = SvRV(*pSV)) != SVt_PVCV)
              Perl_croak(aTHX_ "%s hook defined for '%s' is not "
                               "a code reference", hook, type);
            else
            {
              I32 ix;
              AV *out = newAV();

              sth->sub = sv;
              av_extend(out, len-1);

              for (ix = 0; ix < len; ++ix)
              {
                pSV = av_fetch(in, ix+1, 0);

                if (pSV == NULL)
                  fatal("NULL returned by av_fetch() in hook_fill()");

                SvREFCNT_inc(*pSV);

                if (av_store(out, ix, *pSV) == NULL)
                  SvREFCNT_dec(*pSV);
              }

              sth->arg = (AV *) sv_2mortal((SV *) out);
            }
          }
        }
        break;

      default:
        goto not_code_or_array_ref;
    }
  }
  else
  {
not_code_or_array_ref:
    Perl_croak(aTHX_ "%s hook defined for '%s' is not "
                     "a code or array reference", hook, type);
  }
}


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: hook_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

TypeHooks *hook_new(const TypeHooks *h)
{
  dTHX;
  TypeHooks *r;
  SingleHook *dst;
  int i;

  New(0, r, 1, TypeHooks);

  dst = &r->hooks[0];

  if (h)
  {
    const SingleHook *src = &h->hooks[0];

    for (i = 0; i < HOOKID_COUNT; i++, src++, dst++)
    {
      *dst = *src;
      if (src->sub)
        SvREFCNT_inc(src->sub);
      if (src->arg)
        SvREFCNT_inc(src->arg);
    }
  }
  else
  {
    for (i = 0; i < HOOKID_COUNT; i++, dst++)
    {
      dst->sub = NULL;
      dst->arg = NULL;
    }
  }

  return r;
}

/*******************************************************************************
*
*   ROUTINE: hook_update
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void hook_update(TypeHooks *dst, const TypeHooks *src)
{
  dTHX;
  const SingleHook *hook_src = &src->hooks[0];
  SingleHook *hook_dst = &dst->hooks[0];
  int i;

  assert(src != NULL);
  assert(dst != NULL);

  for (i = 0; i < HOOKID_COUNT; i++, hook_dst++, hook_src++)
  {
    if (hook_dst->sub != hook_src->sub)
    {
      if (hook_src->sub)
        SvREFCNT_inc(hook_src->sub);
      if (hook_dst->sub)
        SvREFCNT_dec(hook_dst->sub);
    }

    if (hook_dst->arg != hook_src->arg)
    {
      if (hook_src->arg)
        SvREFCNT_inc(hook_src->arg);
      if (hook_dst->arg)
        SvREFCNT_dec(hook_dst->arg);
    }

    *hook_dst = *hook_src;
  }
}

/*******************************************************************************
*
*   ROUTINE: hook_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void hook_delete(TypeHooks *h)
{
  if (h)
  {
    dTHX;
    SingleHook *hook = &h->hooks[0];
    int i;

    for (i = 0; i < HOOKID_COUNT; i++, hook++)
    {
      if (hook->sub)
        SvREFCNT_dec(hook->sub);
      if (hook->arg)
        SvREFCNT_dec(hook->arg);
    }

    Safefree(h);
  }
}

/*******************************************************************************
*
*   ROUTINE: hook_call
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

SV *hook_call(pTHX_ SV *self, const char *id_pre, const char *id,
              const TypeHooks *pTH, enum HookId hook_id, SV *in, int mortal)
{
  dSP;
  int count;
  SV *out;
  const SingleHook *hook;

  CT_DEBUG(MAIN, ("hook_call(id='%s%s', pTH=%p, in=%p(%d), mortal=%d)",
                  id_pre, id, pTH, in, SvREFCNT(in), mortal));

  assert(self != NULL);
  assert(pTH  != NULL);
  assert(id   != NULL);
  assert(in   != NULL);

  hook = &pTH->hooks[hook_id];

  if (hook->sub == NULL)
    return in;

  ENTER;
  SAVETMPS;

  PUSHMARK(SP);

  if (hook->arg)
  {
    I32 ix, len;
    len = av_len(hook->arg);

    for (ix = 0; ix <= len; ++ix)
    {
      SV **pSV = av_fetch(hook->arg, ix, 0);
      SV *sv;

      if (pSV == NULL)
        fatal("NULL returned by av_fetch() in hook_call()");

      if (SvROK(*pSV) && sv_isa(*pSV, ARGTYPE_PACKAGE))
      {
        HookArgType type = (HookArgType) SvIV(SvRV(*pSV));

        switch (type)
        {
          case HOOK_ARG_SELF:
            sv = sv_mortalcopy(self);
            break;

          case HOOK_ARG_DATA:
            sv = sv_mortalcopy(in);
            break;

          case HOOK_ARG_TYPE:
            sv = sv_newmortal();
            if (id_pre)
            {
              sv_setpv(sv, id_pre);
              sv_catpv(sv, CONST_CHAR(id));
            }
            else
              sv_setpv(sv, id);
            break;

          case HOOK_ARG_HOOK:
            sv = sv_newmortal();
            sv_setpv(sv, gs_HookIdStr[hook_id]);
            break;

          default:
            fatal("Invalid hook argument type (%d) in hook_call()", type);
            break;
        }
      }
      else
        sv = sv_mortalcopy(*pSV);

      XPUSHs(sv);
    }
  }
  else
  {
    /* only push the data argument */
    XPUSHs(in);
  }

  PUTBACK;

  count = call_sv(hook->sub, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    fatal("Hook returned %d elements instead of 1", count);

  out = POPs;

  CT_DEBUG(MAIN, ("hook_call: in=%p(%d), out=%p(%d)",
                  in, SvREFCNT(in), out, SvREFCNT(out)));

  if (!mortal)
    SvREFCNT_dec(in);
  SvREFCNT_inc(out);

  PUTBACK;
  FREETMPS;
  LEAVE;

  if (mortal)
    sv_2mortal(out);

  CT_DEBUG(MAIN, ("hook_call: out=%p(%d)", out, SvREFCNT(out)));

  return out;
}

/*******************************************************************************
*
*   ROUTINE: find_hooks
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

int find_hooks(pTHX_ const char *type, HV *hooks, TypeHooks *pTH)
{
  HE *h;
  int i, num;

  assert(type != NULL);
  assert(hooks != NULL);
  assert(pTH != NULL);

  (void) hv_iterinit(hooks);

  while ((h = hv_iternext(hooks)) != NULL)
  {
    const char *key;
    I32 keylen;
    SV *sub;
    enum HookId id;

    key = hv_iterkey(h, &keylen);
    sub = hv_iterval(hooks, h);

    id = get_hook_id(key);

    if (id >= HOOKID_COUNT)
    {
      if (id == HOOKID_INVALID)
        Perl_croak(aTHX_ "Invalid hook type '%s'", key);
      else
        fatal("Invalid hook id %d for hook '%s'", id, key);
    }

    hook_fill(aTHX_ key, type, &pTH->hooks[id], sub);
  }

  for (i = num = 0; i < HOOKID_COUNT; i++)
    if (pTH->hooks[i].sub)
      num++;

  return num;
}

/*******************************************************************************
*
*   ROUTINE: get_hooks
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2004
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

HV *get_hooks(pTHX_ const TypeHooks *pTH)
{
  int i;
  HV *hv = newHV();

  assert(pTH != NULL);

  for (i = 0; i < HOOKID_COUNT; i++)
  {
    SV *sv = pTH->hooks[i].sub;
    const char *id;

    if (sv == NULL)
      continue;

    sv = newRV_inc(sv);

    if (pTH->hooks[i].arg)
    {
      AV *av = newAV();
      int j, len = 1 + av_len(pTH->hooks[i].arg);

      av_extend(av, len);
      if (av_store(av, 0, sv) == NULL)
        fatal("av_store() failed in get_hooks()");

      for (j = 0; j < len; j++)
      {
        SV **pSV = av_fetch(pTH->hooks[i].arg, j, 0);

        if (pSV == NULL)
          fatal("NULL returned by av_fetch() in get_hooks()");

        SvREFCNT_inc(*pSV);

        if (av_store(av, j+1, *pSV) == NULL)
          fatal("av_store() failed in get_hooks()");
      }

      sv = newRV_noinc((SV *) av);
    }

    id = gs_HookIdStr[i];

    if (hv_store(hv, id, strlen(id), sv, 0) == 0)
      fatal("hv_store() failed in get_hooks()");
  }

  return hv;
}

