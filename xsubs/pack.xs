################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/21 09:18:42 +0000 $
# $Revision: 2 $
# $Source: /xsubs/pack.xs $
#
################################################################################
#
# Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################


################################################################################
#
#   METHOD: pack
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################

SV *
CBC::pack(type, data = &PL_sv_undef, string = NULL)
  const char *type
  SV *data
  SV *string

  PREINIT:
    CBC_METHOD(pack);
    char *buffer;
    MemberInfo mi;
    PackInfo pack;

  CODE:
    CT_DEBUG_METHOD1("'%s'", type);

    if (string == NULL && GIMME_V == G_VOID)
    {
      WARN_VOID_CONTEXT;
      XSRETURN_EMPTY;
    }

    if (string != NULL)
    {
      SvGETMAGIC(string);
      if ((SvFLAGS(string) & (SVf_POK|SVp_POK)) == 0)
        Perl_croak(aTHX_ "Type of arg 3 to pack must be string");
      if (GIMME_V == G_VOID && SvREADONLY(string))
        Perl_croak(aTHX_ "Modification of a read-only value "
                         "attempted");
    }

    if (!get_member_info(aTHX_ THIS, type, &mi))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    if (mi.flags)
      WARN_FLAGS(type, mi.flags);

    if (string == NULL)
    {
      RETVAL = newSV(mi.size);

      /* force RETVAL into a PV when mi.size is zero (bug #3753) */
      if (mi.size == 0)
        sv_grow(RETVAL, 1);

      SvPOK_only(RETVAL);
      SvCUR_set(RETVAL, mi.size);
      buffer = SvPVX(RETVAL);

      /* We get an mi.size+1 buffer from newSV. So the following */
      /* call will properly \0-terminate our return value.       */
      Zero(buffer, mi.size+1, char);
    }
    else
    {
      STRLEN len = SvCUR(string);
      STRLEN max = mi.size > len ? mi.size : len;

      if (GIMME_V == G_VOID)
      {
        RETVAL = &PL_sv_undef;
        buffer = SvGROW(string, max+1);
        SvCUR_set(string, max);
      }
      else
      {
        RETVAL = newSV(max);
        SvPOK_only(RETVAL);
        buffer = SvPVX(RETVAL);
        SvCUR_set(RETVAL, max);
        Copy(SvPVX(string), buffer, len, char);
      }

      if(max > len)
        Zero(buffer+len, max+1-len, char);
    }

    /* may be used to grow the buffer */
    pack.self       = ST(0);
    pack.bufsv      = RETVAL;

    pack.bufptr     =
    pack.buf.buffer = buffer;
    pack.buf.length = mi.size;
    pack.buf.pos    = 0;

    pack.align_base = 0;
    pack.alignment  = CPC_ALIGNMENT(&THIS->cfg);

    IDLIST_INIT(&pack.idl);
    IDLIST_PUSH(&pack.idl, ID);
    IDLIST_SET_ID(&pack.idl, type);

    SvGETMAGIC(data);

    pack_type(aTHX_ THIS, &pack, &mi.type, mi.pDecl, mi.level, data);

    IDLIST_FREE(&pack.idl);

    /* this makes substr() as third argument work */
    if (string)
      SvSETMAGIC(string);

  OUTPUT:
    RETVAL


################################################################################
#
#   METHOD: unpack
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::unpack(type, string)
  const char *type
  SV *string

  PREINIT:
    CBC_METHOD(unpack);
    STRLEN len;
    MemberInfo mi;
    PackInfo pack;
    unsigned long i, count;

  PPCODE:
    CT_DEBUG_METHOD1("'%s'", type);

    CHECK_VOID_CONTEXT;

    if ((SvFLAGS(string) & (SVf_POK|SVp_POK)) == 0)
      Perl_croak(aTHX_ "Type of arg 2 to unpack must be string");

    if (!get_member_info(aTHX_ THIS, type, &mi))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    if (mi.flags)
      WARN_FLAGS(type, mi.flags);

    pack.self       = ST(0);
    pack.buf.buffer = SvPV(string, len);
    pack.buf.length = len;
    pack.alignment  = CPC_ALIGNMENT(&THIS->cfg);

    if (GIMME_V == G_SCALAR)
    {
      if (mi.size > len)
        WARN((aTHX_ "Data too short"));

      count = 1;
    }
    else
      count = mi.size == 0 ? 1 : len / mi.size;

    if (count > 0)
    {
      SV **sva;

      /* newHV_indexed() messes with the stack, so we cannot
       * store the return values on the stack immediately...
       */

      New(0, sva, count, SV *);

      for (i = 0; i < count; i++)
      {
        pack.buf.pos    = i*mi.size;
        pack.bufptr     = pack.buf.buffer + pack.buf.pos;
        pack.align_base = 0;

        sva[i] = unpack_type(aTHX_ THIS, &pack, &mi.type,
                             mi.pDecl, mi.level);
      }

      EXTEND(SP, count);

      for (i = 0; i < count; i++)
        PUSHs(sv_2mortal(sva[i]));

      Safefree(sva);
    }

    XSRETURN(count);

