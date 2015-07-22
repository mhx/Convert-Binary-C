/*******************************************************************************
*
* HEADER: ctparse.h
*
********************************************************************************
*
* DESCRIPTION: Parser interface routines
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/11/23 17:06:27 +0000 $
* $Revision: 7 $
* $Snapshot: /Convert-Binary-C/0.05 $
* $Source: /ctlib/ctparse.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTPARSE_H
#define _CTPARSE_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "arch.h"
#include "ctype.h"
#include "util/list.h"
#include "util/hash.h"


/*===== DEFINES ==============================================================*/

#ifdef HAVE_LONG_LONG
#define CTLIB_long_long_SIZE sizeof( long long )
#else
#define CTLIB_long_long_SIZE 8
#endif

#ifdef HAVE_LONG_DOUBLE
#define CTLIB_long_double_SIZE sizeof( long double )
#else
#define CTLIB_long_double_SIZE 12
#endif

#define CTLIB_double_SIZE  sizeof( double )
#define CTLIB_float_SIZE   sizeof( float )
#define CTLIB_short_SIZE   sizeof( short )
#define CTLIB_long_SIZE    sizeof( long )
#define CTLIB_int_SIZE     sizeof( int )

#define CTLIB_POINTER_SIZE sizeof( void * )

/*===== TYPEDEFS =============================================================*/

typedef struct {
  char *buffer;
  long  pos, length;
} Buffer;

typedef struct {
  unsigned alignment;
  unsigned int_size;
  unsigned short_size;
  unsigned long_size;
  unsigned long_long_size;
  unsigned enum_size;
  unsigned ptr_size;
  unsigned float_size;
  unsigned double_size;
  unsigned long_double_size;
  unsigned flags;

#define HAS_VOID_KEYWORD     0x00000001U
#define CHARS_ARE_UNSIGNED   0x00000002U
#define ISSUE_WARNINGS       0x00000004U

#ifdef ANSIC99_EXTENSIONS
#define HAS_C99_KEYWORDS     0x00010000U
#define HAS_CPP_COMMENTS     0x00020000U
#define HAS_MACRO_VAARGS     0x00040000U
#endif

  LinkedList includes;
  LinkedList defines;
  LinkedList assertions;
} CParseConfig;

typedef struct {
  LinkedList enums;
  LinkedList structs;
  LinkedList typedef_lists;
  HashTable  htEnumerators;
  HashTable  htEnums;
  HashTable  htStructs;
  HashTable  htTypedefs;
  HashTable  htFiles;
  char      *errstr;
} CParseInfo;

typedef enum {
  GTI_NO_ERROR = 0,
  GTI_TYPEDEF_IS_NULL,
  GTI_NO_ENUM_SIZE,
  GTI_NO_STRUCT_DECL,
  GTI_STRUCT_IS_NULL
} ErrorGTI;


/*===== FUNCTION PROTOTYPES ==================================================*/

int ParseBuffer( char *filename, Buffer *pBuf, CParseInfo *pCPI, CParseConfig *pCPC );

void InitParseInfo( CParseInfo *pCPI );
void FreeParseInfo( CParseInfo *pCPI );
void ResetParseInfo( CParseInfo *pCPI );
void UpdateParseInfo( CParseInfo *pCPI, CParseConfig *pCPC );
void CloneParseInfo( CParseInfo *pDest, CParseInfo *pSrc );

ErrorGTI GetTypeInfo( CParseConfig *pCPC, TypeSpec *pTS, Declarator *pDecl,
                      unsigned *pSize, unsigned *pAlign, unsigned *pItemSize,
                      u_32 *pFlags );

void FormatError( CParseInfo *pCPI, char *format, ... );
void FreeError( CParseInfo *pCPI );

#endif
