################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/05/19 18:54:04 +0100 $
# $Revision: 4 $
# $Source: /xsubs/configure.xs $
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
#   METHOD: configure
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################

SV *
CBC::configure(...)
  PREINIT:
    CBC_METHOD(configure);

  CODE:
    CT_DEBUG_METHOD;

    if (items <= 2 && GIMME_V == G_VOID)
    {
      WARN_VOID_CONTEXT;
      XSRETURN_EMPTY;
    }
    else if (items == 1)
      RETVAL = get_configuration(aTHX_ THIS);
    else if (items == 2)
      (void) handle_option(aTHX_ THIS, ST(1), NULL, &RETVAL);
    else if (items % 2)
    {
      int i, changes = 0;

      for (i = 1; i < items; i += 2)
        if (handle_option(aTHX_ THIS, ST(i), ST(i+1), NULL))
          changes = 1;

      if (changes && CBC_HAVE_PARSE_DATA(THIS))
      {
        post_configure_update(aTHX_ THIS);
        basic_types_reset(THIS->basic);
        reset_parse_info(&THIS->cpi);
        update_parse_info(&THIS->cpi, &THIS->cfg);
      }

      XSRETURN(1);
    }
    else
      Perl_croak(aTHX_ "Invalid number of arguments to %s", method);

  OUTPUT:
    RETVAL

