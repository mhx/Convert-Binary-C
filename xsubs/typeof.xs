################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/21 09:18:41 +0000 $
# $Revision: 2 $
# $Source: /xsubs/typeof.xs $
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

    if (!get_member_info(aTHX_ THIS, type, &mi))
      Perl_croak(aTHX_ "Cannot find '%s'", type);

    RETVAL = get_type_name_string(aTHX_ &mi);

  OUTPUT:
    RETVAL

