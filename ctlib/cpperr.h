/*******************************************************************************
*
* HEADER: cpperr.h
*
********************************************************************************
*
* DESCRIPTION: Error reporting for the preprocessor
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/01 11:29:54 +0000 $
* $Revision: 3 $
* $Snapshot: /Convert-Binary-C/0.07 $
* $Source: /ctlib/cpperr.h $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_CPPERR_H
#define _CTLIB_CPPERR_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

typedef struct {
  void * (*newstr)( void );
  void   (*scatf)( void *, char *, ... );
  void   (*vscatf)( void *, char *, va_list );
  void   (*warn)( void * );
  void   (*error)( void * );
  void   (*fatal)( void * );
} PrintFunctions;

/*===== FUNCTION PROTOTYPES ==================================================*/

void SetPrintFunctions( PrintFunctions *pPF );

#endif
