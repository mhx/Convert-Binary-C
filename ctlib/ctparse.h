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
* $Date: 2004/03/22 19:37:57 +0000 $
* $Revision: 21 $
* $Snapshot: /Convert-Binary-C/0.50 $
* $Source: /ctlib/ctparse.h $
*
********************************************************************************
*
* Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_CTPARSE_H
#define _CTLIB_CTPARSE_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "arch.h"
#include "cttype.h"
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
  char          *buffer;
  unsigned long  pos, length;
} Buffer;

typedef struct {
  unsigned alignment;
  unsigned int_size;
  unsigned short_size;
  unsigned long_size;
  unsigned long_long_size;
  int      enum_size;
  unsigned ptr_size;
  unsigned float_size;
  unsigned double_size;
  unsigned long_double_size;

  u_32     flags;

#define CHARS_ARE_UNSIGNED   0x00000001U
#define ISSUE_WARNINGS       0x00000002U

#define HAS_CPP_COMMENTS     0x00010000U
#define HAS_MACRO_VAARGS     0x00020000U

#define DISABLE_PARSER       0x80000000U

  u_32     keywords;

#define HAS_KEYWORD_AUTO     0x00000001U
#define HAS_KEYWORD_CONST    0x00000002U
#define HAS_KEYWORD_DOUBLE   0x00000004U
#define HAS_KEYWORD_ENUM     0x00000008U
#define HAS_KEYWORD_EXTERN   0x00000010U
#define HAS_KEYWORD_FLOAT    0x00000020U
#define HAS_KEYWORD_INLINE   0x00000040U
#define HAS_KEYWORD_LONG     0x00000080U
#define HAS_KEYWORD_REGISTER 0x00000100U
#define HAS_KEYWORD_RESTRICT 0x00000200U
#define HAS_KEYWORD_SHORT    0x00000400U
#define HAS_KEYWORD_SIGNED   0x00000800U
#define HAS_KEYWORD_STATIC   0x00001000U
#define HAS_KEYWORD_UNSIGNED 0x00002000U
#define HAS_KEYWORD_VOID     0x00004000U
#define HAS_KEYWORD_VOLATILE 0x00008000U
#define HAS_KEYWORD_ASM      0x00010000U

#define HAS_ALL_KEYWORDS     0x0001FFFFU

  LinkedList disabled_keywords;
  LinkedList includes;
  LinkedList defines;
  LinkedList assertions;

  HashTable  keyword_map;
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
  LinkedList errorStack;
} CParseInfo;

typedef enum {
  GTI_NO_ERROR = 0,
  GTI_TYPEDEF_IS_NULL,
  GTI_NO_ENUM_SIZE,
  GTI_NO_STRUCT_DECL,
  GTI_STRUCT_IS_NULL
} ErrorGTI;


/*===== FUNCTION PROTOTYPES ==================================================*/

#define parse_buffer CTlib_parse_buffer
int parse_buffer( const char *filename, const Buffer *pBuf,
                  const CParseConfig *pCPC, CParseInfo *pCPI );

#define init_parse_info CTlib_init_parse_info
void init_parse_info( CParseInfo *pCPI );

#define free_parse_info CTlib_free_parse_info
void free_parse_info( CParseInfo *pCPI );

#define reset_parse_info CTlib_reset_parse_info
void reset_parse_info( CParseInfo *pCPI );

#define update_parse_info CTlib_update_parse_info
void update_parse_info( CParseInfo *pCPI, const CParseConfig *pCPC );

#define clone_parse_info CTlib_clone_parse_info
void clone_parse_info( CParseInfo *pDest, CParseInfo *pSrc );

#define get_type_info CTlib_get_type_info
ErrorGTI get_type_info( const CParseConfig *pCPC, const TypeSpec *pTS,
                        const Declarator *pDecl, unsigned *pSize,
                        unsigned *pAlign, unsigned *pItemSize, u_32 *pFlags );

#endif
