/*******************************************************************************
*
* MODULE: pack.c
*
********************************************************************************
*
* DESCRIPTION: C::B::C pack/unpack routines
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2005/02/21 09:18:39 +0000 $
* $Revision: 12 $
* $Source: /cbc/pack.c $
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

#include "cbc/hook.h"
#include "cbc/pack.h"
#include "cbc/tag.h"
#include "cbc/util.h"


/*===== DEFINES ==============================================================*/

/*--------------------------------*/
/* macros for buffer manipulation */
/*--------------------------------*/

#define ALIGN_BUFFER(align)                                                    \
          STMT_START {                                                         \
            unsigned _align = (unsigned)(align) > PACK->alignment              \
                            ? PACK->alignment : (align);                       \
            assert(_align > 0);                                                \
            if (PACK->align_base % _align)                                     \
            {                                                                  \
              _align -= PACK->align_base % _align;                             \
              PACK->align_base += _align;                                      \
              PACK->buf.pos    += _align;                                      \
              PACK->bufptr     += _align;                                      \
            }                                                                  \
          } STMT_END

#define CHECK_BUFFER(size)                                                     \
          STMT_START {                                                         \
            if (PACK->buf.pos + (size) > PACK->buf.length)                     \
            {                                                                  \
              PACK->buf.pos = PACK->buf.length;                                \
              return newSV(0);                                                 \
            }                                                                  \
          } STMT_END

#define GROW_BUFFER(size, reason)                                              \
          STMT_START {                                                         \
            unsigned long _required_ = PACK->buf.pos + (size);                 \
            if (_required_ > PACK->buf.length)                                 \
            {                                                                  \
              CT_DEBUG(MAIN, ("Growing output SV from %ld to %ld bytes due "   \
                              "to %s", PACK->buf.length, _required_, reason)); \
              PACK->buf.buffer = SvGROW(PACK->bufsv, _required_ + 1);          \
              SvCUR_set(PACK->bufsv, _required_);                              \
              Zero(PACK->buf.buffer + PACK->buf.length,                        \
                   _required_ + 1 - PACK->buf.length, char);                   \
              PACK->buf.length = _required_;                                   \
              PACK->bufptr     = PACK->buf.buffer + PACK->buf.pos;             \
            }                                                                  \
          } STMT_END

#define INC_BUFFER(size)                                                       \
          STMT_START {                                                         \
            assert(PACK->buf.pos + (size) <= PACK->buf.length);                \
            PACK->align_base += size;                                          \
            PACK->buf.pos    += size;                                          \
            PACK->bufptr     += size;                                          \
          } STMT_END

/*----------------*/
/* ID list macros */
/*----------------*/

#define IDLP_PUSH(what)      IDLIST_PUSH(&(PACK->idl), what)
#define IDLP_POP             IDLIST_POP(&(PACK->idl))
#define IDLP_SET_ID(value)   IDLIST_SET_ID(&(PACK->idl), value)
#define IDLP_SET_IX(value)   IDLIST_SET_IX(&(PACK->idl), value)

/*------------*/
/* some flags */
/*------------*/

#define PACK_FLEXIBLE   0x00000001


/*===== TYPEDEFS =============================================================*/

typedef enum {
  FPT_UNKNOWN,
  FPT_FLOAT,
  FPT_DOUBLE,
  FPT_LONG_DOUBLE
} FPType;


/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

static FPType get_fp_type(u_32 flags);
static void store_float_sv(pPACKARGS, unsigned size, u_32 flags, SV *sv);
static SV *fetch_float_sv(pPACKARGS, unsigned size, u_32 flags);

static void store_int_sv(pPACKARGS, unsigned size, unsigned sign, SV *sv);
static SV *fetch_int_sv(pPACKARGS, unsigned size, unsigned sign);

static unsigned load_size(const CBC *THIS, u_32 *pFlags);

static void pack_pointer(pPACKARGS, SV *sv);
static void pack_struct(pPACKARGS, Struct *pStruct, SV *sv);
static void pack_enum(pPACKARGS, EnumSpecifier *pEnumSpec, SV *sv);
static void pack_basic(pPACKARGS, u_32 flags, SV *sv);
static void pack_format(pPACKARGS, CtTag *format, unsigned size, u_32 flags, SV *sv);

static SV *unpack_pointer(pPACKARGS);
static SV *unpack_struct(pPACKARGS, Struct *pStruct, HV *hash);
static SV *unpack_enum(pPACKARGS, EnumSpecifier *pEnumSpec);
static SV *unpack_basic(pPACKARGS, u_32 flags);
static SV *unpack_format(pPACKARGS, CtTag *format, unsigned size, u_32 flags);

static SV *hook_call_typespec(pTHX_ SV *self, const TypeSpec *pTS,
                              enum HookId hook_id, SV *in, int mortal);

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*******************************************************************************
*
*   ROUTINE: get_fp_type
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

static FPType get_fp_type(u_32 flags)
{
  /* mask out irrelevant flags */
  flags &= T_VOID | T_CHAR | T_SHORT | T_INT
         | T_LONG | T_FLOAT | T_DOUBLE | T_SIGNED
         | T_UNSIGNED | T_LONGLONG;

  /* only a couple of types are supported */
  switch (flags)
  {
    case T_LONG | T_DOUBLE: return FPT_LONG_DOUBLE;
    case T_DOUBLE         : return FPT_DOUBLE;
    case T_FLOAT          : return FPT_FLOAT;
  }

  return FPT_UNKNOWN;
}

/*******************************************************************************
*
*   ROUTINE: store_float_sv
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

#ifdef CBC_HAVE_IEEE_FP

#define STORE_FLOAT(ftype)                                                     \
        STMT_START {                                                           \
          union {                                                              \
            ftype f;                                                           \
            u_8   c[sizeof(ftype)];                                            \
          } _u;                                                                \
          int _i;                                                              \
          u_8 *_p = (u_8 *) PACK->bufptr;                                      \
          _u.f = (ftype) SvNV(sv);                                             \
          if (THIS->as.bo == CBC_NATIVE_BYTEORDER)                             \
          {                                                                    \
            for (_i = 0; _i < sizeof(ftype); _i++)                             \
              *_p++ = _u.c[_i];                                                \
          }                                                                    \
          else   /* swap */                                                    \
          {                                                                    \
            for (_i = sizeof(ftype)-1; _i >= 0; _i--)                          \
              *_p++ = _u.c[_i];                                                \
          }                                                                    \
        } STMT_END

#else /* ! CBC_HAVE_IEEE_FP */

#define STORE_FLOAT(ftype)                                                     \
        STMT_START {                                                           \
          if (size == sizeof(ftype))                                           \
          {                                                                    \
            u_8 *_p = (u_8 *) PACK->bufptr;                                    \
            ftype _v = (ftype) SvNV(sv);                                       \
            Copy(&_v, _p, 1, ftype);                                           \
          }                                                                    \
          else                                                                 \
            goto non_native;                                                   \
        } STMT_END

#endif /* CBC_HAVE_IEEE_FP */

static void store_float_sv(pPACKARGS, unsigned size, u_32 flags, SV *sv)
{
  FPType type = get_fp_type(flags);

  if (type == FPT_UNKNOWN)
  {
    SV *str = NULL;
    get_basic_type_spec_string(aTHX_ &str, flags);
    WARN((aTHX_ "Unsupported floating point type '%s' in pack", SvPV_nolen(str)));
    SvREFCNT_dec(str);
    goto finish;
  }

#ifdef CBC_HAVE_IEEE_FP

  if (size == sizeof(float))
    STORE_FLOAT(float);
  else if (size == sizeof(double))
    STORE_FLOAT(double);
#if ARCH_HAVE_LONG_DOUBLE
  else if (size == sizeof(long double))
    STORE_FLOAT(long double);
#endif
  else
    WARN((aTHX_ "Cannot pack %d byte floating point values", size));

#else /* ! CBC_HAVE_IEEE_FP */

  if (THIS->as.bo != CBC_NATIVE_BYTEORDER)
    goto non_native;

  switch (type)
  {
    case FPT_FLOAT          : STORE_FLOAT(float);       break;
    case FPT_DOUBLE         : STORE_FLOAT(double);      break;
#if ARCH_HAVE_LONG_DOUBLE
    case FPT_LONG_DOUBLE    : STORE_FLOAT(long double); break;
#endif
    default:
      goto non_native;
  }

  goto finish;

non_native:
  WARN((aTHX_ "Cannot pack non-native floating point values", size));

#endif /* CBC_HAVE_IEEE_FP */

finish:
  return;
}

#undef STORE_FLOAT

/*******************************************************************************
*
*   ROUTINE: fetch_float_sv
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

#ifdef CBC_HAVE_IEEE_FP

#define FETCH_FLOAT(ftype)                                                     \
        STMT_START {                                                           \
          union {                                                              \
            ftype f;                                                           \
            u_8   c[sizeof(ftype)];                                            \
          } _u;                                                                \
          int _i;                                                              \
          u_8 *_p = (u_8 *) PACK->bufptr;                                      \
          if (THIS->as.bo == CBC_NATIVE_BYTEORDER)                             \
          {                                                                    \
            for (_i = 0; _i < sizeof(ftype); _i++)                             \
              _u.c[_i] = *_p++;                                                \
          }                                                                    \
          else   /* swap */                                                    \
          {                                                                    \
            for (_i = sizeof(ftype)-1; _i >= 0; _i--)                          \
              _u.c[_i] = *_p++;                                                \
          }                                                                    \
          value = (NV) _u.f;                                                   \
        } STMT_END

#else /* ! CBC_HAVE_IEEE_FP */

#define FETCH_FLOAT(ftype)                                                     \
        STMT_START {                                                           \
          if (size == sizeof(ftype))                                           \
          {                                                                    \
            u_8 *_p = (u_8 *) PACK->bufptr;                                    \
            ftype _v;                                                          \
            Copy(_p, &_v, 1, ftype);                                           \
            value = (NV) _v;                                                   \
          }                                                                    \
          else                                                                 \
            goto non_native;                                                   \
        } STMT_END

#endif /* CBC_HAVE_IEEE_FP */

static SV *fetch_float_sv(pPACKARGS, unsigned size, u_32 flags)
{
  FPType type = get_fp_type(flags);
  NV value = 0.0;

  if (type == FPT_UNKNOWN)
  {
    SV *str = NULL;
    get_basic_type_spec_string(aTHX_ &str, flags);
    WARN((aTHX_ "Unsupported floating point type '%s' in unpack", SvPV_nolen(str)));
    SvREFCNT_dec(str);
    goto finish;
  }

#ifdef CBC_HAVE_IEEE_FP

  if (size == sizeof(float))
    FETCH_FLOAT(float);
  else if (size == sizeof(double))
    FETCH_FLOAT(double);
#if ARCH_HAVE_LONG_DOUBLE
  else if (size == sizeof(long double))
    FETCH_FLOAT(long double);
#endif
  else
    WARN((aTHX_ "Cannot unpack %d byte floating point values", size));

#else /* ! CBC_HAVE_IEEE_FP */

  if (THIS->as.bo != CBC_NATIVE_BYTEORDER)
    goto non_native;

  switch (type)
  {
    case FPT_FLOAT          : FETCH_FLOAT(float);       break;
    case FPT_DOUBLE         : FETCH_FLOAT(double);      break;
#if ARCH_HAVE_LONG_DOUBLE
    case FPT_LONG_DOUBLE    : FETCH_FLOAT(long double); break;
#endif
    default:
      goto non_native;
  }

  goto finish;

non_native:
  WARN((aTHX_ "Cannot unpack non-native floating point values", size));

#endif /* CBC_HAVE_IEEE_FP */

finish:
  return newSVnv(value);
}

#undef FETCH_FLOAT


/*******************************************************************************
*
*   ROUTINE: store_int_sv
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void store_int_sv(pPACKARGS, unsigned size, unsigned sign, SV *sv)
{
  IntValue iv;

  iv.sign = sign;

  if (SvPOK(sv) && string_is_integer(SvPVX(sv)))
    iv.string = SvPVX(sv);
  else {
    iv.string = NULL;

    if (sign)
    {
      IV val = SvIV(sv);
      CT_DEBUG(MAIN, ("SvIV( sv ) = %" IVdf, val));
#if ARCH_NATIVE_64_BIT_INTEGER
      iv.value.s = val;
#else
      iv.value.s.h = 0;
      iv.value.s.l = val;
#endif
    }
    else
    {
      UV val = SvUV(sv);
      CT_DEBUG(MAIN, ("SvUV( sv ) = %" UVuf, val));
#if ARCH_NATIVE_64_BIT_INTEGER
      iv.value.u = val;
#else
      iv.value.u.h = 0;
      iv.value.u.l = val;
#endif
    }
  }

  store_integer(size, PACK->bufptr, &THIS->as, &iv);
}

/*******************************************************************************
*
*   ROUTINE: fetch_int_sv
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

#if ARCH_NATIVE_64_BIT_INTEGER
#define __SIZE_LIMIT sizeof(IV)
#else
#define __SIZE_LIMIT sizeof(iv.value.u.l)
#endif

#ifdef newSVuv
#define __TO_UV(x) newSVuv((UV) (x))
#else
#define __TO_UV(x) newSViv((IV) (x))
#endif

static SV *fetch_int_sv(pPACKARGS, unsigned size, unsigned sign)
{
  IntValue iv;
  char buffer[32];

  /*
   *  Whew, I guess that could be done better,
   *  but at least it's working...
   */

#ifdef newSVuv

  iv.string = size > __SIZE_LIMIT ? buffer : NULL;

#else  /* older perls don't have newSVuv */

  iv.string = size  > __SIZE_LIMIT ||
              (size == __SIZE_LIMIT && !sign)
              ? buffer : NULL;

#endif

  fetch_integer(size, sign, PACK->bufptr, &THIS->as, &iv);

  if (iv.string)
    return newSVpv(iv.string, 0);

#if ARCH_NATIVE_64_BIT_INTEGER
  return sign ? newSViv(iv.value.s         ) : __TO_UV(iv.value.u  );
#else
  return sign ? newSViv((i_32) iv.value.s.l) : __TO_UV(iv.value.u.l);
#endif
}

#undef __SIZE_LIMIT
#undef __TO_UV

/*******************************************************************************
*
*   ROUTINE: load_size
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Nov 2004
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

static unsigned load_size(const CBC *THIS, u_32 *pFlags)
{
  u_32 flags;
  unsigned size;

  flags = *pFlags;

#define LOAD_SIZE(type)                                                        \
        size = THIS->cfg.type ## _size ? THIS->cfg.type ## _size               \
                                       : CTLIB_ ## type ## _SIZE

  if (flags & T_VOID)  /* XXX: do we want void ? */
    size = 1;
  else if (flags & T_CHAR)
  {
    LOAD_SIZE(char);
    if ((flags & (T_SIGNED | T_UNSIGNED)) == 0 &&
        (THIS->cfg.flags & CHARS_ARE_UNSIGNED))
      flags |= T_UNSIGNED;
  }
  else if ((flags & (T_LONG | T_DOUBLE)) == (T_LONG | T_DOUBLE))
    LOAD_SIZE(long_double);
  else if (flags & T_LONGLONG) LOAD_SIZE(long_long);
  else if (flags & T_FLOAT)    LOAD_SIZE(float);
  else if (flags & T_DOUBLE)   LOAD_SIZE(double);
  else if (flags & T_SHORT)    LOAD_SIZE(short);
  else if (flags & T_LONG)     LOAD_SIZE(long);
  else                         LOAD_SIZE(int);

#undef LOAD_SIZE

  *pFlags = flags;

  return size;
}

/*******************************************************************************
*
*   ROUTINE: pack_pointer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static void pack_pointer(pPACKARGS, SV *sv)
{
  unsigned size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof(void *);

  CT_DEBUG(MAIN, (XSCLASS "::pack_pointer( THIS=%p, sv=%p )", THIS, sv));

  ALIGN_BUFFER(size);
  GROW_BUFFER(size, "insufficient space");

  if (DEFINED(sv) && !SvROK(sv))
    store_int_sv(aPACKARGS, size, 0, sv);

  INC_BUFFER(size);
}

/*******************************************************************************
*
*   ROUTINE: pack_struct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static void pack_struct(pPACKARGS, Struct *pStruct, SV *sv)
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  long               pos;
  unsigned           old_align, old_base;

  CT_DEBUG(MAIN, (XSCLASS "::pack_struct( THIS=%p, pStruct=%p, sv=%p )",
           THIS, pStruct, sv));

  ALIGN_BUFFER(pStruct->align);

  if (pStruct->tags)
  {
    CtTag *tag;

    if ((tag = find_tag(pStruct->tags, CBC_TAG_HOOKS)) != NULL)
      sv = hook_call(aTHX_ PACK->self, pStruct->tflags & T_STRUCT ? "struct " : "union ",
                     pStruct->identifier, tag->any, HOOKID_pack, sv, 1);

    if ((tag = find_tag(pStruct->tags, CBC_TAG_FORMAT)) != NULL)
    {
      pack_format(aPACKARGS, tag, pStruct->size, 0, sv);
      return;
    }
  }

  pos              = PACK->buf.pos;
  old_align        = PACK->alignment;
  old_base         = PACK->align_base;
  PACK->alignment  = pStruct->pack ? pStruct->pack : CPC_ALIGNMENT(&THIS->cfg);
  PACK->align_base = 0;

  if (DEFINED(sv))
  {
    SV *hash;

    if (SvROK(sv) && SvTYPE(hash = SvRV(sv)) == SVt_PVHV)
    {
      HV *h = (HV *) hash;

      IDLP_PUSH(ID);

      LL_foreach(pStructDecl, pStruct->declarations)
      {
        if (pStructDecl->declarators)
        {
          LL_foreach(pDecl, pStructDecl->declarators)
          {
            size_t id_len = strlen(pDecl->identifier);

            if (id_len > 0)
            {
              SV **e = hv_fetch(h, pDecl->identifier, id_len, 0);

              if (e)
                SvGETMAGIC(*e);

              IDLP_SET_ID(pDecl->identifier);

              pack_type(aPACKARGS, &pStructDecl->type, pDecl, 0, e ? *e : NULL);
            }

            if (pStruct->tflags & T_UNION)
            {
              PACK->bufptr  = PACK->buf.buffer + pos;
              PACK->buf.pos = pos;
              PACK->align_base = 0;
            }
          }
        }
        else
        {
          TypeSpec *pTS = &pStructDecl->type;

          FOLLOW_AND_CHECK_TSPTR(pTS);

          IDLP_POP;

          pack_struct(aPACKARGS, (Struct *) pTS->ptr, sv);

          IDLP_PUSH(ID);

          if (pStruct->tflags & T_UNION)
          {
            PACK->bufptr     = PACK->buf.buffer + pos;
            PACK->buf.pos    = pos;
            PACK->align_base = 0;
          }
        }
      }

      IDLP_POP;
    }
    else
      WARN((aTHX_ "'%s' should be a hash reference",
            IDListToStr(aTHX_ &(PACK->idl))));
  }

  PACK->alignment  = old_align;
  PACK->align_base = old_base + pStruct->size;
  PACK->buf.pos    = pos + pStruct->size;
  PACK->bufptr     = PACK->buf.buffer + PACK->buf.pos;
}

/*******************************************************************************
*
*   ROUTINE: pack_enum
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static void pack_enum(pPACKARGS, EnumSpecifier *pEnumSpec, SV *sv)
{
  unsigned size = GET_ENUM_SIZE(pEnumSpec);
  IV value = 0;

  CT_DEBUG(MAIN, (XSCLASS "::pack_enum( THIS=%p, pEnumSpec=%p, sv=%p )",
           THIS, pEnumSpec, sv));

  ALIGN_BUFFER(size);

  if (pEnumSpec->tags)
  {
    CtTag *tag;

    if ((tag = find_tag(pEnumSpec->tags, CBC_TAG_HOOKS)) != NULL)
      sv = hook_call(aTHX_ PACK->self, "enum ", pEnumSpec->identifier,
                     tag->any, HOOKID_pack, sv, 1);

    if ((tag = find_tag(pEnumSpec->tags, CBC_TAG_FORMAT)) != NULL)
    {
      pack_format(aPACKARGS, tag, size, 0, sv);
      return;
    }
  }

  /* TODO: add some checks (range, perhaps even value) */

  GROW_BUFFER(size, "insufficient space");

  if (DEFINED(sv) && !SvROK(sv))
  {
    IntValue iv;

    if (SvIOK(sv))
      value = SvIVX(sv);
    else
    {
      Enumerator *pEnum = NULL;

      if (SvPOK(sv))
      {
        STRLEN len;
        char *str = SvPV(sv, len);

        pEnum = HT_get(THIS->cpi.htEnumerators, str, len, 0);

        if (pEnum)
        {
          if (IS_UNSAFE_VAL(pEnum->value))
            WARN((aTHX_ "Enumerator value '%s' is unsafe", str));
          value = pEnum->value.iv;
        }
      }

      if (pEnum == NULL)
        value = SvIV(sv);
    }

    CT_DEBUG(MAIN, ("value(sv) = %" IVdf, value));

    iv.string = NULL;
    iv.sign   = value < 0;

#if ARCH_NATIVE_64_BIT_INTEGER
    iv.value.s = value;
#else
    iv.value.s.h = value < 0 ? -1 : 0;
    iv.value.s.l = value;
#endif

    store_integer(size, PACK->bufptr, &THIS->as, &iv);
  }

  INC_BUFFER(size);
}

/*******************************************************************************
*
*   ROUTINE: pack_basic
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static void pack_basic(pPACKARGS, u_32 flags, SV *sv)
{
  unsigned size;

  CT_DEBUG(MAIN, (XSCLASS "::pack_basic( THIS=%p, flags=0x%08lX, sv=%p )",
           THIS, (unsigned long) flags, sv));

  CT_DEBUG(MAIN, ("buffer.pos=%lu, buffer.length=%lu",
           PACK->buf.pos, PACK->buf.length));

  size = load_size(THIS, &flags);

  ALIGN_BUFFER(size);
  GROW_BUFFER(size, "insufficient space");

  if (DEFINED(sv) && !SvROK(sv))
  {
    if (flags & (T_DOUBLE | T_FLOAT))
      store_float_sv(aPACKARGS, size, flags, sv);
    else
      store_int_sv(aPACKARGS, size, (flags & T_UNSIGNED) == 0, sv);
  }

  INC_BUFFER(size);
}

/*******************************************************************************
*
*   ROUTINE: pack_format
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2005
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

static void pack_format(pPACKARGS, CtTag *format, unsigned size, u_32 flags, SV *sv)
{
  CT_DEBUG(MAIN, (XSCLASS "::pack_format( THIS=%p, format->flags=0x%lX, size=%u, "
                  "flags=0x%lX, sv=%p )", THIS, (unsigned long) format->flags,
                  size, (unsigned long) flags, sv));

  if (flags & PACK_FLEXIBLE)
  {
    if (!DEFINED(sv))
      size = 0;
  }
  else
    GROW_BUFFER(size, "insufficient space");

  if (DEFINED(sv))
  {
    STRLEN len;
    const char *p = SvPV(sv, len);

    if (flags & PACK_FLEXIBLE)
    {
      if (format->flags == CBC_TAG_FORMAT_STRING)
      {
        STRLEN tmp = 0;

        while (p[tmp] && tmp < len)
          tmp++;

        len = tmp + 1;  /* null-termination */
      }

      size = len % size ? (unsigned) (len + size - (len % size))
                        : (unsigned) len;

      GROW_BUFFER(size, "incomplete array type");
    }

    if (len > size)
    {
      WARN((aTHX_ "Source string is longer than '%s' (%d > %d)",
            IDListToStr(aTHX_ &(PACK->idl)), len, size));

      len = size;
    }

    switch (format->flags)
    {
      case CBC_TAG_FORMAT_BINARY:
        Copy(p, PACK->bufptr, len, char);
        break;

      case CBC_TAG_FORMAT_STRING:
        strncpy(PACK->bufptr, p, len);
        break;

      default:
        fatal("Unknown format (%d)", format->flags);
    }
  }

  INC_BUFFER(size);
}

/*******************************************************************************
*
*   ROUTINE: unpack_pointer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static SV *unpack_pointer(pPACKARGS)
{
  SV *sv;
  unsigned size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof(void *);

  CT_DEBUG(MAIN, (XSCLASS "::unpack_pointer( THIS=%p )", THIS));

  ALIGN_BUFFER(size);
  CHECK_BUFFER(size);

  sv = fetch_int_sv(aPACKARGS, size, 0);

  INC_BUFFER(size);

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: unpack_struct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static SV *unpack_struct(pPACKARGS, Struct *pStruct, HV *hash)
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  HV                *h = hash;
  long               pos;
  int                ordered;
  unsigned           old_align, old_base;
  SV                *sv;
  CtTag             *hooks = NULL;

  CT_DEBUG(MAIN, (XSCLASS "::unpack_struct( THIS=%p, pStruct=%p, hash=%p )",
           THIS, pStruct, hash));

  ALIGN_BUFFER(pStruct->align);

  if (pStruct->tags)
  {
    CtTag *format;

    hooks = find_tag(pStruct->tags, CBC_TAG_HOOKS);

    if ((format = find_tag(pStruct->tags, CBC_TAG_FORMAT)) != NULL)
    {
      sv = unpack_format(aPACKARGS, format, pStruct->size, 0);
      goto handle_unpack_hook;
    }
  }

  ordered = THIS->flags & CBC_ORDER_MEMBERS && THIS->ixhash != NULL;

  if (h == NULL)
    h = ordered ? newHV_indexed(aTHX_ THIS) :  newHV();

  pos              = PACK->buf.pos;
  old_align        = PACK->alignment;
  old_base         = PACK->align_base;
  PACK->alignment  = pStruct->pack ? pStruct->pack : CPC_ALIGNMENT(&THIS->cfg);
  PACK->align_base = 0;

  LL_foreach(pStructDecl, pStruct->declarations)
  {
    if (pStructDecl->declarators)
    {
      LL_foreach(pDecl, pStructDecl->declarators)
      {
        U32 klen = strlen(pDecl->identifier);

        if (klen > 0)
        {
          if (hv_exists(h, pDecl->identifier, klen))
          {
            WARN((aTHX_ "Member '%s' used more than once in %s%s%s defined in %s(%d)",
                  pDecl->identifier,
                  pStruct->tflags & T_UNION ? "union" : "struct",
                  pStruct->identifier[0] != '\0' ? " " : "",
                  pStruct->identifier[0] != '\0' ? pStruct->identifier : "",
                  pStruct->context.pFI->name, pStruct->context.line));
          }
          else
          {
            SV *value = unpack_type(aPACKARGS, &pStructDecl->type, pDecl, 0);
            SV **didstore = hv_store(h, pDecl->identifier, klen, value, 0);
            if (ordered)
              SvSETMAGIC(value);
            if (!didstore)
              SvREFCNT_dec(value);
          }
        }

        if (pStruct->tflags & T_UNION)
        {
          PACK->bufptr     = PACK->buf.buffer + pos;
          PACK->buf.pos    = pos;
          PACK->align_base = 0;
        }
      }
    }
    else
    {
      TypeSpec *pTS = &pStructDecl->type;

      FOLLOW_AND_CHECK_TSPTR(pTS);

      (void) unpack_struct(aPACKARGS, (Struct *) pTS->ptr, h);

      if (pStruct->tflags & T_UNION)
      {
        PACK->bufptr     = PACK->buf.buffer + pos;
        PACK->buf.pos    = pos;
        PACK->align_base = 0;
      }
    }
  }

  PACK->alignment  = old_align;
  PACK->align_base = old_base + pStruct->size;
  PACK->buf.pos    = pos + pStruct->size;
  PACK->bufptr     = PACK->buf.buffer + PACK->buf.pos;

  if (hash)
    return NULL;

  sv = newRV_noinc((SV*)h);

handle_unpack_hook:

  if (hooks)
    sv = hook_call(aTHX_ PACK->self, pStruct->tflags & T_STRUCT ? "struct " : "union ",
                   pStruct->identifier, hooks->any, HOOKID_unpack, sv, 0);

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: unpack_enum
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static SV *unpack_enum(pPACKARGS, EnumSpecifier *pEnumSpec)
{
  Enumerator *pEnum;
  unsigned size = GET_ENUM_SIZE(pEnumSpec);
  IV value;
  SV *sv;
  CtTag *hooks = NULL;

  CT_DEBUG(MAIN, (XSCLASS "::unpack_enum( THIS=%p, pEnumSpec=%p )",
                 THIS, pEnumSpec));

  ALIGN_BUFFER(size);

  if (pEnumSpec->tags)
  {
    CtTag *format;

    hooks = find_tag(pEnumSpec->tags, CBC_TAG_HOOKS);

    if ((format = find_tag(pEnumSpec->tags, CBC_TAG_FORMAT)) != NULL)
    {
      sv = unpack_format(aPACKARGS, format, size, 0);
      goto handle_unpack_hook;
    }
  }

  CHECK_BUFFER(size);

  if (pEnumSpec->tflags & T_SIGNED) /* TODO: handle (un)/signed correctly */
  {
    IntValue iv;
    iv.string = NULL;
    fetch_integer(size, 1, PACK->bufptr, &THIS->as, &iv);
#if ARCH_NATIVE_64_BIT_INTEGER
    value = iv.value.s;
#else
    value = (i_32) iv.value.s.l;
#endif
  }
  else
  {
    IntValue iv;
    iv.string = NULL;
    fetch_integer(size, 0, PACK->bufptr, &THIS->as, &iv);
#if ARCH_NATIVE_64_BIT_INTEGER
    value = iv.value.u;
#else
    value = iv.value.u.l;
#endif
  }

  INC_BUFFER(size);

  if (THIS->enumType == ET_INTEGER)
    sv = newSViv(value);
  else
  {
    LL_foreach(pEnum, pEnumSpec->enumerators)
      if(pEnum->value.iv == value)
        break;

    if (pEnumSpec->tflags & T_UNSAFE_VAL)
    {
      if (pEnumSpec->identifier[0] != '\0')
        WARN((aTHX_ "Enumeration '%s' contains unsafe values",
                    pEnumSpec->identifier));
      else
        WARN((aTHX_ "Enumeration contains unsafe values"));
    }

    switch (THIS->enumType)
    {
      case ET_BOTH:
        sv = newSViv(value);
        if (pEnum)
          sv_setpv(sv, pEnum->identifier);
        else
          sv_setpvf(sv, "<ENUM:%" IVdf ">", value);
        SvIOK_on(sv);
        break;

      case ET_STRING:
        if (pEnum)
          sv = newSVpv(pEnum->identifier, 0);
        else
          sv = newSVpvf("<ENUM:%" IVdf ">", value);
        break;

      default:
        fatal("Invalid enum type (%d) in unpack_enum()!", THIS->enumType);
        break;
    }
  }

handle_unpack_hook:

  if (hooks)
    sv = hook_call(aTHX_ PACK->self, "enum ", pEnumSpec->identifier,
                   hooks->any, HOOKID_unpack, sv, 0);

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: unpack_basic
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

static SV *unpack_basic(pPACKARGS, u_32 flags)
{
  unsigned size;
  SV *sv;

  CT_DEBUG(MAIN, (XSCLASS "::unpack_basic( THIS=%p, flags=0x%08lX )",
                  THIS, (unsigned long) flags));

  CT_DEBUG(MAIN, ("buffer.pos=%lu, buffer.length=%lu",
                  PACK->buf.pos, PACK->buf.length));

  size = load_size(THIS, &flags);

  ALIGN_BUFFER(size);
  CHECK_BUFFER(size);

  if (flags & (T_FLOAT | T_DOUBLE))
    sv = fetch_float_sv(aPACKARGS, size, flags);
  else
    sv = fetch_int_sv(aPACKARGS, size, (flags & T_UNSIGNED) == 0);

  INC_BUFFER(size);

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: unpack_format
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

static SV *unpack_format(pPACKARGS, CtTag *format, unsigned size, u_32 flags)
{
  SV *sv;

  CT_DEBUG(MAIN, (XSCLASS "::unpack_format( THIS=%p, format->flags=0x%lX, "
                  "size=%u, flags=0x%lX )", THIS, (unsigned long) format->flags,
                  size, (unsigned long) flags));

  if (PACK->buf.pos + size > PACK->buf.length)
    return newSVpvn("", 0);

  if (flags & PACK_FLEXIBLE)
  {
    unsigned remain;

    assert(PACK->buf.pos <= PACK->buf.length);

    remain = PACK->buf.length - PACK->buf.pos;

    if (remain % size)
      remain -= remain % size;

    size = remain;
  }

  switch (format->flags)
  {
    case CBC_TAG_FORMAT_BINARY:
      sv = newSVpvn(PACK->bufptr, size);
      break; 

    case CBC_TAG_FORMAT_STRING:
      {
        unsigned n;

        for (n = 0; n < size; n++)
          if (PACK->bufptr[n] == '\0')
            break;

        sv = newSVpvn(PACK->bufptr, n);
      }
      break;

    default:
      fatal("Unknown format (%d)", format->flags);
  }

  INC_BUFFER(size);

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: hook_call_typespec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2005
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

static SV *hook_call_typespec(pTHX_ SV *self, const TypeSpec *pTS,
                              enum HookId hook_id, SV *in, int mortal)
{
  const char *id, *pre;
  CtTagList tags = NULL;

  if (pTS->tflags & T_TYPE)
  {
    const Typedef *p = pTS->ptr;

    id   = p->pDecl->identifier;
    tags = p->pDecl->tags;
    pre  = "";
  }
  else if (pTS->tflags & (T_STRUCT|T_UNION))
  {
    const Struct *p = pTS->ptr;

    id   = p->identifier;
    tags = p->tags;
    pre  = pTS->tflags & T_STRUCT ? "struct " : "union ";
  }
  else if (pTS->tflags & T_ENUM)
  {
    const EnumSpecifier *p = pTS->ptr;

    id   = p->identifier;
    tags = p->tags;
    pre  = "enum ";
  }

  if (tags)
  {
    CtTag *hooks = find_tag(tags, CBC_TAG_HOOKS);

    if (hooks)
      return hook_call(aTHX_ self, pre, id, hooks->any, hook_id, in, mortal);
  }

  return in;
}


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: pack_type
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

void pack_type(pPACKARGS, TypeSpec *pTS, Declarator *pDecl, int dimension, SV *sv)
{
  CT_DEBUG(MAIN, (XSCLASS "::pack_type( THIS=%p, pTS=%p, pDecl=%p, "
           "dimension=%d, sv=%p )", THIS, pTS, pDecl, dimension, sv));

  if (pDecl && dimension == 0 && pDecl->tags)
  {
    CtTag *tag;

    if ((tag = find_tag(pDecl->tags, CBC_TAG_HOOKS)) != NULL)
      sv = hook_call(aTHX_ PACK->self, "", pDecl->identifier,
                     tag->any, HOOKID_pack, sv, 1);

    if ((tag = find_tag(pDecl->tags, CBC_TAG_FORMAT)) != NULL)
    {
      unsigned size, align, item;
      u_32 flags = 0;
      int dim;
      ErrorGTI err;

      err = get_type_info(&THIS->cfg, pTS, pDecl, &size, &align, &item, NULL);
      if (err != GTI_NO_ERROR)
        croak_gti(aTHX_ err, IDListToStr(aTHX_ &(PACK->idl)), 1);

      ALIGN_BUFFER(align);

      dim = LL_count(pDecl->array);

      /* check if it's an incomplete array type */
      if (dim > 0 && ((Value *) LL_get(pDecl->array, 0))->flags & V_IS_UNDEF)
      {
        while (dim-- > 1)
          item *= ((Value *) LL_get(pDecl->array, dim))->iv;

        size   = item;
        flags |= PACK_FLEXIBLE;
      }

      pack_format(aPACKARGS, tag, size, flags, sv);

      return;
    }
  }

  if (pDecl && dimension < LL_count(pDecl->array))
  {
    SV *ary;

    if (DEFINED(sv) && SvROK(sv) && SvTYPE(ary = SvRV(sv)) == SVt_PVAV)
    {
      Value *v = (Value *) LL_get(pDecl->array, dimension);
      long i, s;
      AV *a = (AV *) ary;

      if (v->flags & V_IS_UNDEF)
      {
        unsigned size, align;
        int dim;
        ErrorGTI err;

        assert(dimension == 0);

        s = av_len(a)+1;

        /* eventually we need to grow the SV buffer */

        err = get_type_info(&THIS->cfg, pTS, pDecl, NULL, &align, &size, NULL);
        if (err != GTI_NO_ERROR)
          croak_gti(aTHX_ err, IDListToStr(aTHX_ &(PACK->idl)), 1);

        ALIGN_BUFFER(align);

        dim = LL_count(pDecl->array);

        while (dim-- > 1)
          size *= ((Value *) LL_get(pDecl->array, dim))->iv;

        GROW_BUFFER(s*size, "incomplete array type");
      }
      else
        s = v->iv;

      IDLP_PUSH(IX);

      for (i = 0; i < s; ++i)
      {
        SV **e = av_fetch(a, i, 0);

        if (e)
          SvGETMAGIC(*e);

        IDLP_SET_IX(i);

        pack_type(aPACKARGS, pTS, pDecl, dimension+1, e ? *e : NULL);
      }

      IDLP_POP;
    }
    else
    {
      unsigned size, align;
      int dim;
      ErrorGTI err;

      if (DEFINED(sv))
        WARN((aTHX_ "'%s' should be an array reference",
                    IDListToStr(aTHX_ &(PACK->idl))));

      err = get_type_info(&THIS->cfg, pTS, pDecl, NULL, &align, &size, NULL);
      if (err != GTI_NO_ERROR)
        croak_gti(aTHX_ err, IDListToStr(aTHX_ &(PACK->idl)), 1);

      ALIGN_BUFFER(align);

      dim = LL_count(pDecl->array);

      /* this is safe with flexible array members */
      while (dim-- > dimension)
        size *= ((Value *) LL_get(pDecl->array, dim))->iv;

      GROW_BUFFER(size, "insufficient space");
      INC_BUFFER(size);
    }
  }
  else
  {
    if (pDecl && pDecl->pointer_flag)
    {
      if (DEFINED(sv) && SvROK(sv))
        WARN((aTHX_ "'%s' should be a scalar value",
                    IDListToStr(aTHX_ &(PACK->idl))));
      sv = hook_call_typespec(aTHX_ PACK->self, pTS, HOOKID_pack_ptr, sv, 1);
      pack_pointer(aPACKARGS, sv);
    }
    else if (pDecl && pDecl->bitfield_size >= 0)
    {
      /* unsupported */
    }
    else if (pTS->tflags & T_TYPE)
    {
      Typedef *pTD = pTS->ptr;
      pack_type(aPACKARGS, pTD->pType, pTD->pDecl, 0, sv);
    }
    else if(pTS->tflags & (T_STRUCT | T_UNION))
    {
      Struct *pStruct = (Struct *) pTS->ptr;
      if (pStruct->declarations == NULL)
        WARN_UNDEF_STRUCT(pStruct);
      else
        pack_struct(aPACKARGS, pStruct, sv);
    }
    else
    {
      if (DEFINED(sv) && SvROK(sv))
        WARN((aTHX_ "'%s' should be a scalar value",
                    IDListToStr(aTHX_ &(PACK->idl))));

      CT_DEBUG(MAIN, ("SET '%s' @ %lu", pDecl ? pDecl->identifier : "",
                                        PACK->buf.pos ));

      if (pTS->tflags & T_ENUM)
        pack_enum(aPACKARGS, pTS->ptr, sv);
      else
        pack_basic(aPACKARGS, pTS->tflags, sv);
    }
  }
}

/*******************************************************************************
*
*   ROUTINE: unpack_type
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
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

SV *unpack_type(pPACKARGS, TypeSpec *pTS, Declarator *pDecl, int dimension)
{
  SV *rv = NULL;
  CtTag *hooks = NULL;

  CT_DEBUG(MAIN, (XSCLASS "::unpack_type( THIS=%p, pTS=%p, pDecl=%p, "
                          "dimension=%d )", THIS, pTS, pDecl, dimension));

  if (pDecl && dimension == 0 && pDecl->tags)
  {
    CtTag *format;

    hooks = find_tag(pDecl->tags, CBC_TAG_HOOKS);

    if ((format = find_tag(pDecl->tags, CBC_TAG_FORMAT)) != NULL)
    {
      unsigned size, align, item;
      u_32 flags = 0;
      int dim;
      ErrorGTI err;

      err = get_type_info(&THIS->cfg, pTS, pDecl, &size, &align, &item, NULL);
      if (err != GTI_NO_ERROR)
        croak_gti(aTHX_ err, IDListToStr(aTHX_ &(PACK->idl)), 1);

      ALIGN_BUFFER(align);

      dim = LL_count(pDecl->array);

      /* check if it's an incomplete array type */
      if (dim > 0 && ((Value *) LL_get(pDecl->array, 0))->flags & V_IS_UNDEF)
      {
        while (dim-- > 1)
          item *= ((Value *) LL_get(pDecl->array, dim))->iv;

        size   = item;
        flags |= PACK_FLEXIBLE;
      }

      assert(size > 0);

      rv = unpack_format(aPACKARGS, format, size, flags);

      goto handle_unpack_hook;
    }
  }

  if (pDecl && dimension < LL_count(pDecl->array))
  {
    AV *a = newAV();
    Value *v = (Value *) LL_get(pDecl->array, dimension);
    long i, s;

    if (v->flags & V_IS_UNDEF)
    {
      unsigned size, align;
      int dim;
      ErrorGTI err;

      assert(dimension == 0);

      err = get_type_info(&THIS->cfg, pTS, pDecl, NULL, &align, &size, NULL);
      if (err != GTI_NO_ERROR)
        croak_gti(aTHX_ err, IDListToStr(aTHX_ &(PACK->idl)), 1);

      ALIGN_BUFFER(align);

      dim = LL_count(pDecl->array);

      while (dim-- > 1)
        size *= ((Value *) LL_get(pDecl->array, dim))->iv;

      s = ((PACK->buf.length - PACK->buf.pos) + (size - 1)) / size;

      CT_DEBUG(MAIN, ("s=%ld (buf.length=%ld, buf.pos=%ld, size=%ld)",
                      s, PACK->buf.length, PACK->buf.pos, size));
    }
    else
      s = v->iv;

    av_extend(a, s-1);

    for (i=0; i<s; ++i)
      av_store(a, i, unpack_type(aPACKARGS, pTS, pDecl, dimension+1));

    rv = newRV_noinc((SV *) a);
  }
  else if (pDecl && pDecl->pointer_flag)
  {
    rv = unpack_pointer(aPACKARGS);
    rv = hook_call_typespec(aTHX_ PACK->self, pTS, HOOKID_unpack_ptr, rv, 0);
  }
  else if (pDecl && pDecl->bitfield_size >= 0)  /* unsupported */
    rv = newSV(0);
  else if (pTS->tflags & T_TYPE)
  {
    Typedef *pTD = pTS->ptr;
    rv = unpack_type(aPACKARGS, pTD->pType, pTD->pDecl, 0);
  }
  else if (pTS->tflags & (T_STRUCT | T_UNION))
  {
    Struct *pStruct = pTS->ptr;
    if (pStruct->declarations == NULL)
    {
      WARN_UNDEF_STRUCT( pStruct );
      rv = newSV(0);
    }
    else
      rv = unpack_struct(aPACKARGS, pTS->ptr, NULL);
  }
  else
  {
    CT_DEBUG(MAIN, ("GET '%s' @ %lu", pDecl ? pDecl->identifier : "", PACK->buf.pos));

    if (pTS->tflags & T_ENUM)
      rv = unpack_enum(aPACKARGS, pTS->ptr);
    else
      rv = unpack_basic(aPACKARGS, pTS->tflags);
  }

  assert(rv != NULL);

handle_unpack_hook:

  if (hooks)
  {
    assert(pDecl != NULL);

    rv = hook_call(aTHX_ PACK->self, "", pDecl->identifier,
                   hooks->any, HOOKID_unpack, rv, 0);
  }

  return rv;
}

