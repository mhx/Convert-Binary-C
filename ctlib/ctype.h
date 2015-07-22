/*******************************************************************************
*
* HEADER: ctype.h
*
********************************************************************************
*
* DESCRIPTION: ANSI C data type objects
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/04/15 22:26:46 +0100 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.02 $
* $Source: /ctlib/ctype.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _TYPE_H
#define _TYPE_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "arch.h"
#include "util/list.h"


/*===== DEFINES ==============================================================*/

/* value flags */

#define V_IS_UNDEF                     0x00000001
#define V_IS_UNSAFE                    0x08000000
#define V_IS_UNSAFE_UNDEF              0x10000000
#define V_IS_UNSAFE_CAST               0x20000000
#define V_IS_UNSAFE_PTROP              0x40000000
#define V_IS_UNSAFE_BITFIELD           0x80000000

#define IS_UNSAFE_VAL( val ) ( (val).flags & ( V_IS_UNSAFE            \
                                             | V_IS_UNSAFE_UNDEF      \
                                             | V_IS_UNSAFE_CAST       \
                                             | V_IS_UNSAFE_PTROP      \
                                             | V_IS_UNSAFE_BITFIELD ) )

/* type flags */

#define T_VOID                         0x00000001
#define T_CHAR                         0x00000002
#define T_SHORT                        0x00000004
#define T_INT                          0x00000008

#define T_LONG                         0x00000010
#define T_FLOAT                        0x00000020
#define T_DOUBLE                       0x00000040
#define T_SIGNED                       0x00000080

#define T_UNSIGNED                     0x00000100
#define T_ENUM                         0x00000200
#define T_STRUCT                       0x00000400
#define T_UNION                        0x00000800

#define T_TYPE                         0x00001000
#define T_TYPEDEF                      0x00002000

/* this flag indicates the usage of bitfields in structures as they're unsupported */
#define T_HASBITFIELD                  0x40000000

/* this flag indicates the use of unsafe values (e.g. sizes of bitfields) */
#define T_UNSAFE_VAL                   0x80000000

#define ANY_TYPE_NAME ( T_VOID | T_CHAR | T_SHORT | T_INT | T_LONG | T_FLOAT | T_DOUBLE \
                        | T_SIGNED | T_UNSIGNED | T_ENUM | T_STRUCT | T_UNION | T_TYPE )


/*===== TYPEDEFS =============================================================*/

typedef struct {
  signed long iv;
  u_32        flags;
} Value;

typedef struct {
  void       *ptr;
  u_32        tflags;
} TypeSpec;

typedef struct {
  Value       value;
  char        identifier[1];
} Enumerator;

typedef struct {
  LinkedList  enumerators;
  u_32        tflags;
  int         size;
  char        identifier[1];
} EnumSpecifier;

typedef struct {
  int         pointer_flag;
  int         bitfield_size;
  int         offset, size;
  LinkedList  array;
  char        identifier[1];
} Declarator;

typedef struct {
  int         pointer_flag;
  int         multiplicator;
} AbstractDeclarator;

typedef struct {
  TypeSpec    type;
  LinkedList  declarators;
} StructDeclaration;

typedef struct {
  unsigned    tflags;
  unsigned    align;
  unsigned    size;
  unsigned    pack;
  LinkedList  declarations;
  char        identifier[1];
} Struct;

typedef struct {
  TypeSpec    type;
  Declarator *pDecl;
} Typedef;


/*===== FUNCTION PROTOTYPES ==================================================*/

Value *value_new( signed long iv, u_32 flags );
void value_delete( Value *pValue );

Enumerator *enum_new( char *identifier, int id_len, Value *pValue );
void enum_delete( Enumerator *pEnum );

EnumSpecifier *enumspec_new( char *identifier, int id_len, LinkedList enumerators );
void enumspec_update( EnumSpecifier *pEnumSpec, LinkedList enumerators );
void enumspec_delete( EnumSpecifier *pEnumSpec );

Declarator *decl_new( char *identifier, int id_len );
void decl_delete( Declarator *pDecl );

StructDeclaration *structdecl_new( TypeSpec type, LinkedList declarators );
void structdecl_delete( StructDeclaration *pStructDecl );

Struct *struct_new( char *identifier, int id_len, u_32 tflags, unsigned pack,
                    LinkedList declarations );
void struct_delete( Struct *pStruct );

Typedef *typedef_new( TypeSpec type, Declarator *pDecl );
void typedef_delete( Typedef *pTypedef );

#endif
