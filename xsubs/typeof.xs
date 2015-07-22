################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2006/01/04 22:27:19 +0000 $
# $Revision: 5 $
# $Source: /xsubs/typeof.xs $
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
#   METHOD: typeof
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2003
#   CHANGED BY:                                   ON:
#
################################################################################

SV *
CBC::typeof(type)
  const char *type

  PREINIT:
    CBC_METHOD(typeof);
    MemberInfo mi;

  CODE:
    CT_DEBUG_METHOD1("'%s'", type);

    CHECK_VOID_CONTEXT;

    if (!get_member_info(aTHX_ THIS, type, &mi, CBC_GMI_NO_CALC))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    RETVAL = get_type_name_string(aTHX_ &mi);

  OUTPUT:
    RETVAL

