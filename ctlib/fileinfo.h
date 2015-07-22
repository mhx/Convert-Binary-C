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
* $Date: 2002/11/25 11:29:01 +0000 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.06 $
* $Source: /ctlib/fileinfo.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _FILEINFO_H
#define _FILEINFO_H

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <time.h>


/*===== LOCAL INCLUDES =======================================================*/

/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

typedef struct {
  size_t size;
  time_t access_time;
  time_t modify_time;
  time_t change_time;
} FileInfo;


/*===== FUNCTION PROTOTYPES ==================================================*/

FileInfo *fileinfo_new( FILE *file );
void      fileinfo_delete( FileInfo *pFileInfo );
FileInfo *fileinfo_clone( const FileInfo *pSrc );

#endif
