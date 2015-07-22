/*******************************************************************************
*
* MODULE: cttype.c
*
********************************************************************************
*
* DESCRIPTION: ANSI C data type objects
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/14 20:14:31 +0000 $
* $Revision: 10 $
* $Snapshot: /Convert-Binary-C/0.08 $
* $Source: /ctlib/cttype.c $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stddef.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "cttype.h"
#include "ctdebug.h"
#include "util/memalloc.h"


/*===== DEFINES ==============================================================*/

#define CONSTRUCT_OBJECT( type, name )                                         \
  type *name;                                                                  \
  name = (type *) Alloc( sizeof( type ) )

#define CLONE_OBJECT( type, dest, src )                                        \
  type *dest;                                                                  \
  if( (src) == NULL )                                                          \
    return NULL;                                                               \
  dest = (type *) Alloc( sizeof( type ) );                                     \
  memcpy( dest, src, sizeof( type ) )

#define CONSTRUCT_OBJECT_IDENT( type, name )                                   \
  type *name;                                                                  \
  if( identifier && id_len == 0 )                                              \
    id_len = strlen( identifier );                                             \
  name = (type *) Alloc( offsetof( type, identifier ) + id_len + 1 );          \
  if( identifier )                                                             \
    strcpy( name->identifier, identifier );                                    \
  else                                                                         \
    name->identifier[0] = '\0'

#define CLONE_OBJECT_IDENT( type, dest, src )                                  \
  type *dest;                                                                  \
  size_t count = offsetof( type, identifier ) + 1;                             \
  if( (src) == NULL )                                                          \
    return NULL;                                                               \
  if( src->identifier[0] )                                                     \
    count += strlen( src->identifier );                                        \
  dest = (type *) Alloc( count );                                              \
  memcpy( dest, src, count )
  

/*===== TYPEDEFS =============================================================*/

/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/*===== STATIC FUNCTIONS =====================================================*/

/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: value_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Value object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Value *value_new( signed long iv, u_32 flags )
{
  CONSTRUCT_OBJECT( Value, pValue );

  pValue->iv    = iv;
  pValue->flags = flags;

  CT_DEBUG( TYPE, ("type::value_new( iv=%d flags=%0x08X ) = 0x%08X",
                   iv, flags, pValue) );

  return pValue;
}

/*******************************************************************************
*
*   ROUTINE: value_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Value object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void value_delete( Value *pValue )
{
  CT_DEBUG( TYPE, ("type::value_delete( pValue=0x%08X )", pValue) );

  if( pValue )
    Free( pValue );
}

/*******************************************************************************
*
*   ROUTINE: value_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Value object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Value *value_clone( const Value *pSrc )
{
  CLONE_OBJECT( Value, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::value_clone( 0x%08X ) = 0x%08X", pSrc, pDest) );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: enum_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Enumeration object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Enumerator *enum_new( char *identifier, int id_len, Value *pValue )
{
  CONSTRUCT_OBJECT_IDENT( Enumerator, pEnum );

  if( pValue ) {
    pEnum->value = *pValue;
    if( pValue->flags & V_IS_UNDEF )
      pEnum->value.flags |= V_IS_UNSAFE_UNDEF;
  }
  else {
    pEnum->value.iv    = 0;
    pEnum->value.flags = V_IS_UNDEF;
  }

  CT_DEBUG( TYPE, ("type::enum_new( identifier=\"%s\", pValue=0x%08X "
                   "[iv=%d, flags=%0x08X] ) = 0x%08X",
                   pEnum->identifier, pValue, pEnum->value.iv,
                   pEnum->value.flags, pEnum) );

  return pEnum;
}

/*******************************************************************************
*
*   ROUTINE: enum_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Enumeration object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void enum_delete( Enumerator *pEnum )
{
  CT_DEBUG( TYPE, ("type::enum_delete( pEnum=0x%08X [identifier=\"%s\"] )",
                   pEnum, pEnum ? pEnum->identifier : "") );

  if( pEnum )
    Free( pEnum );
}

/*******************************************************************************
*
*   ROUTINE: enum_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Enumeration object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Enumerator *enum_clone( const Enumerator *pSrc )
{
  CLONE_OBJECT_IDENT( Enumerator, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::enum_clone( identifier=\"%s\" ) = 0x%08X",
                   pSrc->identifier, pDest) );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: enumspec_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Enumeration Specifier object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

EnumSpecifier *enumspec_new( char *identifier, int id_len, LinkedList enumerators )
{
  CONSTRUCT_OBJECT_IDENT( EnumSpecifier, pEnumSpec );

  pEnumSpec->ctype  = TYP_ENUM;
  pEnumSpec->tflags = T_ENUM;

  if( enumerators == NULL )
    pEnumSpec->enumerators = NULL;
  else
    enumspec_update( pEnumSpec, enumerators );

  CT_DEBUG( TYPE, ("type::enumspec_new( identifier=\"%s\", enumerators=%08X [count=%d] ) = 0x%08X",
                   pEnumSpec->identifier, enumerators, LL_count( enumerators ), pEnumSpec) );

  return pEnumSpec;
}

/*******************************************************************************
*
*   ROUTINE: enumspec_update
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Update an Enumeration Specifier object after all enumerators
*              have been added. This routine will update the sign and size
*              properties.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void enumspec_update( EnumSpecifier *pEnumSpec, LinkedList enumerators )
{
  Enumerator *pEnum;
  long min, max;

  CT_DEBUG( TYPE, ("type::enumspec_update( pEnumSpec=0x%08X [identifier=\"%s\"], enumerators=%08X [count=%d] )",
                   pEnumSpec, pEnumSpec->identifier, enumerators, LL_count( enumerators )) );

  pEnumSpec->tflags      = 0;
  pEnumSpec->enumerators = enumerators;
  min = max = 0;

  LL_foreach( pEnum, enumerators ) {
    if( pEnum->value.iv > max )
      max = pEnum->value.iv;
    else if( pEnum->value.iv < min )
      min = pEnum->value.iv;

    if( IS_UNSAFE_VAL( pEnum->value ) )
      pEnumSpec->tflags |= T_UNSAFE_VAL;
  }

  if( min < 0 ) {
    pEnumSpec->tflags |= T_SIGNED;

    if( min >= -128 && max < 128 ) {
      pEnumSpec->sizes[ES_SIGNED_SIZE]   = 1U;
      pEnumSpec->sizes[ES_UNSIGNED_SIZE] = 1U;
    }
    else if( min >= -32768 && max < 32768 ) {
      pEnumSpec->sizes[ES_SIGNED_SIZE]   = 2U;
      pEnumSpec->sizes[ES_UNSIGNED_SIZE] = 2U;
    }
    else {
      pEnumSpec->sizes[ES_SIGNED_SIZE]   = 4U;
      pEnumSpec->sizes[ES_UNSIGNED_SIZE] = 4U;
    }
  }
  else {
    pEnumSpec->tflags |= T_UNSIGNED;

    if( max < 256 )
      pEnumSpec->sizes[ES_UNSIGNED_SIZE] = 1U;
    else if( max < 65536 )
      pEnumSpec->sizes[ES_UNSIGNED_SIZE] = 2U;
    else
      pEnumSpec->sizes[ES_UNSIGNED_SIZE] = 4U;

    if( max < 128 )
      pEnumSpec->sizes[ES_SIGNED_SIZE] = 1U;
    else if( max < 32768 )
      pEnumSpec->sizes[ES_SIGNED_SIZE] = 2U;
    else
      pEnumSpec->sizes[ES_SIGNED_SIZE] = 4U;
  }
}

/*******************************************************************************
*
*   ROUTINE: enumspec_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Enumeration Specifier object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void enumspec_delete( EnumSpecifier *pEnumSpec )
{
  CT_DEBUG( TYPE, ("type::enumspec_delete( pEnumSpec=0x%08X [identifier=\"%s\"] )",
                   pEnumSpec, pEnumSpec ? pEnumSpec->identifier : "") );

  if( pEnumSpec ) {
    LL_destroy( pEnumSpec->enumerators, (LLDestroyFunc) enum_delete );
    Free( pEnumSpec );
  }
}

/*******************************************************************************
*
*   ROUTINE: enumspec_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Enumeration Specifier object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

EnumSpecifier *enumspec_clone( const EnumSpecifier *pSrc )
{
  CLONE_OBJECT_IDENT( EnumSpecifier, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::enumspec_clone( identifier=\"%s\" ) = 0x%08X",
                   pSrc->identifier, pDest) );

  pDest->enumerators = LL_clone( pSrc->enumerators, (LLCloneFunc) enum_clone );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: decl_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Declarator object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Declarator *decl_new( char *identifier, int id_len )
{
  CONSTRUCT_OBJECT_IDENT( Declarator, pDecl );

  pDecl->array         = LL_new();
  pDecl->pointer_flag  =  0;
  pDecl->bitfield_size = -1;

  CT_DEBUG( TYPE, ("type::decl_new( identifier=\"%s\" ) = 0x%08X", pDecl->identifier, pDecl) );

  return pDecl;
}

/*******************************************************************************
*
*   ROUTINE: decl_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Declarator object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void decl_delete( Declarator *pDecl )
{
  CT_DEBUG( TYPE, ("type::decl_delete( pDecl=0x%08X [identifier=\"%s\"] )",
                   pDecl, pDecl ? pDecl->identifier : "") );

  if( pDecl ) {
    LL_destroy( pDecl->array, (LLDestroyFunc) value_delete );
    Free( pDecl );
  }
}

/*******************************************************************************
*
*   ROUTINE: decl_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Declarator object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Declarator *decl_clone( const Declarator *pSrc )
{
  CLONE_OBJECT_IDENT( Declarator, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::decl_clone( identifier=\"%s\" ) = 0x%08X",
                   pSrc->identifier, pDest) );

  pDest->array = LL_clone( pSrc->array, (LLCloneFunc) value_clone );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: structdecl_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Struct Declaration object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

StructDeclaration *structdecl_new( TypeSpec type, LinkedList declarators )
{
  CONSTRUCT_OBJECT( StructDeclaration, pStructDecl );

  pStructDecl->type        = type;
  pStructDecl->declarators = declarators;
  pStructDecl->offset      = 0;
  pStructDecl->size        = 0;

  CT_DEBUG( TYPE, ("type::structdecl_new( type=[tflags=0x%08X,ptr=0x%08X], declarators=%08X [count=%d] ) = 0x%08X",
                   type.tflags, type.ptr, declarators, LL_count( declarators ), pStructDecl) );

  return pStructDecl;
}

/*******************************************************************************
*
*   ROUTINE: structdecl_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Struct Declaration object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void structdecl_delete( StructDeclaration *pStructDecl )
{
  CT_DEBUG( TYPE, ("type::structdecl_delete( pStructDecl=0x%08X )", pStructDecl) );

  if( pStructDecl ) {
    LL_destroy( pStructDecl->declarators, (LLDestroyFunc) decl_delete );
    Free( pStructDecl );
  }
}

/*******************************************************************************
*
*   ROUTINE: structdecl_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Struct Declaration object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

StructDeclaration *structdecl_clone( const StructDeclaration *pSrc )
{
  CLONE_OBJECT( StructDeclaration, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::structdecl_clone( pStructDecl=0x%08X ) = 0x%08X",
                   pSrc, pDest) );

  pDest->declarators = LL_clone( pSrc->declarators, (LLCloneFunc) decl_clone );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: struct_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Struct/Union object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Struct *struct_new( char *identifier, int id_len, u_32 tflags, unsigned pack, LinkedList declarations )
{
  CONSTRUCT_OBJECT_IDENT( Struct, pStruct );

  pStruct->ctype = TYP_STRUCT;

  pStruct->tflags       = tflags;
  pStruct->declarations = declarations;
  pStruct->align        = 0;
  pStruct->size         = 0;
  pStruct->pack         = pack;

  CT_DEBUG( TYPE, ("type::struct_new( identifier=\"%s\", tflags=0x%08X, pack=%d, declarations=0x%08X [count=%d] ) = 0x%08X",
                   pStruct->identifier, tflags, pack, declarations, LL_count(declarations), pStruct) );

  return pStruct;
}

/*******************************************************************************
*
*   ROUTINE: struct_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Struct/Union object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void struct_delete( Struct *pStruct )
{
  CT_DEBUG( TYPE, ("type::struct_delete( pStruct=0x%08X )", pStruct) );

  if( pStruct ) {
    LL_destroy( pStruct->declarations, (LLDestroyFunc) structdecl_delete );
    Free( pStruct );
  }
}

/*******************************************************************************
*
*   ROUTINE: struct_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Struct object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Struct *struct_clone( const Struct *pSrc )
{
  CLONE_OBJECT_IDENT( Struct, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::struct_clone( identifier=\"%s\" ) = 0x%08X",
                   pSrc->identifier, pDest) );

  pDest->declarations = LL_clone( pSrc->declarations, (LLCloneFunc) structdecl_clone );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: typedef_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Typedef object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Typedef *typedef_new( TypeSpec *pType, Declarator *pDecl )
{
  CONSTRUCT_OBJECT( Typedef, pTypedef );

  pTypedef->ctype = TYP_TYPEDEF;

  pTypedef->pType = pType;
  pTypedef->pDecl = pDecl;

  CT_DEBUG( TYPE, ("type::typedef_new( type=[tflags=0x%08X,ptr=0x%08X], pDecl=%08X [identifier=\"%s\"] ) = 0x%08X",
                   pType->tflags, pType->ptr, pDecl, pDecl ? pDecl->identifier : "", pTypedef) );

  return pTypedef;
}

/*******************************************************************************
*
*   ROUTINE: typedef_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Typedef object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void typedef_delete( Typedef *pTypedef )
{
  CT_DEBUG( TYPE, ("type::typedef_delete( pTypedef=0x%08X )", pTypedef) );

  if( pTypedef ) {
    decl_delete( pTypedef->pDecl );
    Free( pTypedef );
  }
}

/*******************************************************************************
*
*   ROUTINE: typedef_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Typedef object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

Typedef *typedef_clone( const Typedef *pSrc )
{
  CLONE_OBJECT( Typedef, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::typedef_clone( 0x%08X ) = 0x%08X", pSrc, pDest) );

  pDest->pDecl = decl_clone( pSrc->pDecl );

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: typedef_list_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Sep 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Typedef List object constructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

TypedefList *typedef_list_new( TypeSpec type, LinkedList typedefs )
{
  CONSTRUCT_OBJECT( TypedefList, pTypedefList );

  pTypedefList->ctype    = TYP_TYPEDEF_LIST;

  pTypedefList->type     = type;
  pTypedefList->typedefs = typedefs;

  CT_DEBUG( TYPE, ("type::typedef_list_new( type=[tflags=0x%08X,ptr=0x%08X], typedefs=0x%08X ) = 0x%08X",
                   type.tflags, type.ptr, typedefs, pTypedefList) );

  return pTypedefList;
}

/*******************************************************************************
*
*   ROUTINE: typedef_list_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Sep 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Typedef List object destructor.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void typedef_list_delete( TypedefList *pTypedefList )
{
  CT_DEBUG( TYPE, ("type::typedef_list_delete( pTypedefList=0x%08X )", pTypedefList) );

  if( pTypedefList ) {
    LL_destroy( pTypedefList->typedefs, (LLDestroyFunc) typedef_delete );
    Free( pTypedefList );
  }
}

/*******************************************************************************
*
*   ROUTINE: typedef_list_clone
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Clone Typedef List object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

TypedefList *typedef_list_clone( const TypedefList *pSrc )
{
  CLONE_OBJECT( TypedefList, pDest, pSrc );

  CT_DEBUG( TYPE, ("type::typedef_list_clone( 0x%08X ) = 0x%08X", pSrc, pDest) );

  if( pSrc->typedefs ) {
    Typedef *pTypedef;

    pDest->typedefs = LL_new();

    LL_foreach( pTypedef, pSrc->typedefs ) {
      Typedef *pClone = typedef_clone( pTypedef );
      pClone->pType = &pDest->type;
      LL_push( pDest->typedefs, pClone );
    }
  }

  return pDest;
}

/*******************************************************************************
*
*   ROUTINE: get_typedef_list
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Get typedef list object from a typedef object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

TypedefList *get_typedef_list( Typedef *pTypedef )
{
  TypedefList *pTDL;

  CT_DEBUG( TYPE, ("type::get_typedef_list( pTypedef=0x%08X )", pTypedef) );

  if(   pTypedef        == NULL
     || pTypedef->ctype != TYP_TYPEDEF
     || pTypedef->pType == NULL
    )
    return NULL;

  /* assume that pType points to type member of typedef list */
  pTDL = (TypedefList *)
         ( ((u_8 *) pTypedef->pType) - offsetof(TypedefList, type) );

  if( pTDL->ctype != TYP_TYPEDEF_LIST )
    return NULL;

  return pTDL;
}

