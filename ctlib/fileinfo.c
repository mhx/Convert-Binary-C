/*******************************************************************************
*
* MODULE: fileinfo.c
*
********************************************************************************
*
* DESCRIPTION: Retrieving information about files
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/11/25 11:29:00 +0000 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.05 $
* $Source: /ctlib/fileinfo.c $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <string.h>

#include <sys/stat.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "fileinfo.h"
#include "util/memalloc.h"


/*===== DEFINES ==============================================================*/

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: fileinfo_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Nov 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: FileInfo object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

FileInfo *fileinfo_new( FILE *file )
{
  FileInfo *pFileInfo;
  struct stat buf;

  if( file == NULL )
    return NULL;

  if( fstat( fileno( file ), &buf ) != 0 )
    return NULL;

  pFileInfo = (FileInfo *) Alloc( sizeof( FileInfo ) );

  pFileInfo->size        = buf.st_size;
  pFileInfo->access_time = buf.st_atime;
  pFileInfo->modify_time = buf.st_mtime;
  pFileInfo->change_time = buf.st_ctime;

  return pFileInfo;
}

/*******************************************************************************
*
*   ROUTINE: fileinfo_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Nov 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: FileInfo object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void fileinfo_delete( FileInfo *pFileInfo )
{
  if( pFileInfo )
    Free( pFileInfo );
}

/*******************************************************************************
*
*   ROUTINE: fileinfo_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Nov 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone FileInfo object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

FileInfo *fileinfo_clone( const FileInfo *pSrc )
{
  FileInfo *pDest;

  pDest = (FileInfo *) Alloc( sizeof( FileInfo ) );
  memcpy( pDest, pSrc, sizeof( FileInfo ) );

  return pDest;
}

