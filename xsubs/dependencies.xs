################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/06 15:57:07 +0000 $
# $Revision: 1 $
# $Source: /xsubs/dependencies.xs $
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
#   METHOD: dependencies
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Sep 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::dependencies()
  PREINIT:
    CBC_METHOD(dependencies);
    const char *pKey;
    FileInfo   *pFI;

  PPCODE:
    CT_DEBUG_METHOD;

    CHECK_PARSE_DATA;
    CHECK_VOID_CONTEXT;

    if (GIMME_V == G_SCALAR)
    {
      HV *hv = newHV();

      HT_foreach(pKey, pFI, THIS->cpi.htFiles)
      {
        if (pFI && pFI->valid)
        {
          SV *attr;
          HV *hattr = newHV();

          HV_STORE_CONST(hattr, "size",  newSVuv(pFI->size));
          HV_STORE_CONST(hattr, "mtime", newSViv(pFI->modify_time));
          HV_STORE_CONST(hattr, "ctime", newSViv(pFI->change_time));

          attr = newRV_noinc((SV *) hattr);

          if (hv_store(hv, pFI->name, strlen(pFI->name), attr, 0) == NULL)
            SvREFCNT_dec(attr);
        }
      }

      XPUSHs(sv_2mortal(newRV_noinc((SV *) hv)));
      XSRETURN(1);
    }
    else
    {
      int keylen, count = 0;

      HT_reset(THIS->cpi.htFiles);
      while (HT_next(THIS->cpi.htFiles, (char **) &pKey, &keylen, (void **) &pFI))
        if (pFI && pFI->valid)
        {
          XPUSHs(sv_2mortal(newSVpvn(CONST_CHAR(pKey), keylen)));
          count++;
        }

      XSRETURN(count);
    }

