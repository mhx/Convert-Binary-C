################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2005/02/21 09:18:42 +0000 $
# $Revision: 2 $
# $Source: /xsubs/parse.xs $
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
#   METHOD: parse
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::parse(code)
  SV *code

  PREINIT:
    CBC_METHOD(parse);
    SV *temp = NULL;
    STRLEN len;
    Buffer buf;

  CODE:
    CT_DEBUG_METHOD;

    buf.buffer = SvPV(code, len);

    if (!((len == 0) || (len >= 1 && (buf.buffer[len-1] == '\n' ||
                                      buf.buffer[len-1] == '\r'))))
    {
      /* append a newline to a temporary copy */
      temp = newSVsv(code);
      sv_catpvn(temp, "\n", 1);
      buf.buffer = SvPV(temp, len);
    }

    buf.length = len;
    buf.pos    = 0;
#if defined(CBC_THREAD_SAFE) && !defined(UCPP_REENTRANT)
    MUTEX_LOCK(&gs_parse_mutex);
#endif
    (void) parse_buffer(NULL, &buf, &THIS->cfg, &THIS->cpi);
#if defined(CBC_THREAD_SAFE) && !defined(UCPP_REENTRANT)
    MUTEX_UNLOCK(&gs_parse_mutex);
#endif
    if (temp)
      SvREFCNT_dec(temp);

    /* make sure the update is done even if there are errors */
    update_parse_info(&THIS->cpi, &THIS->cfg);

    /* this may croak */
    handle_parse_errors(aTHX_ THIS->cpi.errorStack);

    if (GIMME_V != G_VOID)
      XSRETURN(1);


################################################################################
#
#   METHOD: parse_file
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::parse_file(file)
  const char *file

  PREINIT:
    CBC_METHOD(parse_file);

  CODE:
    CT_DEBUG_METHOD1("'%s'", file);
#if defined(CBC_THREAD_SAFE) && !defined(UCPP_REENTRANT)
    MUTEX_LOCK(&gs_parse_mutex);
#endif
    (void) parse_buffer(file, NULL, &THIS->cfg, &THIS->cpi);
#if defined(CBC_THREAD_SAFE) && !defined(UCPP_REENTRANT)
    MUTEX_UNLOCK(&gs_parse_mutex);
#endif
    /* make sure the update is done even if there are errors */
    update_parse_info(&THIS->cpi, &THIS->cfg);

    /* this may croak */
    handle_parse_errors(aTHX_ THIS->cpi.errorStack);

    if (GIMME_V != G_VOID)
      XSRETURN(1);

