################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/21 09:18:42 +0000 $
# $Revision: 2 $
# $Source: /xsubs/sizeof.xs $
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

    if (!get_member_info(aTHX_ THIS, type, &mi))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    if (mi.pDecl && mi.pDecl->bitfield_size >= 0)
      Perl_croak(aTHX_ "Cannot use %s on bitfields", method);

    if (mi.flags)
      WARN_FLAGS(type, mi.flags);

    RETVAL = newSVuv(mi.size);

  OUTPUT:
    RETVAL

