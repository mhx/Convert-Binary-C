/*******************************************************************************
*
* HEADER: fileinfo.h
*
********************************************************************************
*
* DESCRIPTION: Retrieving information about files
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/15 16:39:27 +0000 $
* $Revision: 5 $
* $Snapshot: /Convert-Binary-C/0.10 $
* $Source: /ctlib/fileinfo.h $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_FILEINFO_H
#define _CTLIB_FILEINFO_H

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <time.h>


/*===== LOCAL INCLUDES =======================================================*/

/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

typedef struct {
  int    valid;
  size_t size;
  time_t access_time;
  time_t modify_time;
  time_t change_time;
  char   name[1];
} FileInfo;


/*===== FUNCTION PROTOTYPES ==================================================*/

FileInfo *fileinfo_new( FILE *file, char *name, size_t name_len );
void      fileinfo_delete( FileInfo *pFileInfo );
FileInfo *fileinfo_clone( const FileInfo *pSrc );

#endif
