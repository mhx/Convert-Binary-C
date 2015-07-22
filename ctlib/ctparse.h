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
* $Date: 2002/08/18 17:07:48 +0100 $
* $Revision: 3 $
* $Snapshot: /Convert-Binary-C/0.03 $
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

#include "ctype.h"
#include "util/list.h"
#include "util/hash.h"


/*===== DEFINES ==============================================================*/

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
  unsigned enum_size;
  unsigned ptr_size;
  unsigned float_size;
  unsigned double_size;
  unsigned htSizeEnumerators;
  unsigned htSizeEnums;
  unsigned htSizeStructs;
  unsigned htSizeTypedefs;
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
  LinkedList typedefs;
  HashTable  htEnumerators;
  HashTable  htEnums;
  HashTable  htStructs;
  HashTable  htTypedefs;
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

ErrorGTI GetTypeInfo( CParseConfig *pCPC, TypeSpec *pTS, Declarator *pDecl,
                      unsigned *pSize, unsigned *pAlign, unsigned *pItemSize,
                      u_32 *pFlags );

void FormatError( CParseInfo *pCPI, char *format, ... );
void FreeError( CParseInfo *pCPI );

#endif
