################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/01/04 22:26:51 +0000 $
# $Revision: 7 $
# $Source: /xsubs/sizeof.xs $
#
################################################################################
#
# Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################


################################################################################
#
#   METHOD: sizeof
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################

SV *
CBC::sizeof(type)
  const char *type

  PREINIT:
    CBC_METHOD(sizeof);
    MemberInfo mi;

  CODE:
    CT_DEBUG_METHOD1("'%s'", type);

    CHECK_VOID_CONTEXT;

    NEED_PARSE_DATA;

    if (!get_member_info(aTHX_ THIS, type, &mi, 0))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    if (mi.pDecl && mi.pDecl->bitfield_flag)
      Perl_croak(aTHX_ "Cannot use %s on bitfields", method);

    if (mi.flags)
      WARN_FLAGS(type, mi.flags);

    RETVAL = newSVuv(mi.size);

  OUTPUT:
    RETVAL

