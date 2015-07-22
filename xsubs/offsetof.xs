################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/21 09:18:43 +0000 $
# $Revision: 2 $
# $Source: /xsubs/offsetof.xs $
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
#   METHOD: offsetof
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################

SV *
CBC::offsetof(type, member)
  const char *type
  const char *member

  PREINIT:
    CBC_METHOD(offsetof);
    MemberInfo mi, mi2;
    const char *m = member;

  CODE:
    CT_DEBUG_METHOD2("'%s', '%s'", type, member);

    CHECK_PARSE_DATA;
    CHECK_VOID_CONTEXT;

    while (*m && isSPACE(*m))
      m++;

    if (*m == '\0')
      WARN((aTHX_ "Empty string passed as member expression"));

    if (!get_member_info(aTHX_ THIS, type, &mi))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    (void) get_member(aTHX_ THIS, &mi, member, &mi2, 1, 0);

    if (mi2.pDecl && mi2.pDecl->bitfield_size >= 0)
      Perl_croak(aTHX_ "Cannot use %s on bitfields", method);

    if (mi.flags)
      WARN_FLAGS(type, mi.flags);

    RETVAL = newSVuv(mi2.offset);

  OUTPUT:
    RETVAL

