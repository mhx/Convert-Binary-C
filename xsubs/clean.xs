################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2008/04/15 14:37:46 +0100 $
# $Revision: 4 $
# $Source: /xsubs/clean.xs $
#
################################################################################
#
# Copyright (c) 2002-2008 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
################################################################################


################################################################################
#
#   METHOD: clean
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::clean()
  PREINIT:
    CBC_METHOD(clean);

  CODE:
    CT_DEBUG_METHOD;

    free_parse_info(&THIS->cpi);

    if (GIMME_V != G_VOID)
      XSRETURN(1);

