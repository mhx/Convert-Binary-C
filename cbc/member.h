/*******************************************************************************
*
* HEADER: member.h
*
********************************************************************************
*
* DESCRIPTION: C::B::C struct member utilities
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2006/01/04 22:21:25 +0000 $
* $Revision: 5 $
* $Source: /cbc/member.h $
*
********************************************************************************
*
* Copyright (c) 2002-2006 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CBC_MEMBER_H
#define _CBC_MEMBER_H

/*===== GLOBAL INCLUDES ======================================================*/


/*===== LOCAL INCLUDES =======================================================*/

#include "util/list.h"
#include "util/hash.h"
#include "ctlib/cttype.h"


/*===== DEFINES ==============================================================*/

#define CBC_GM_ACCEPT_DOTLESS_MEMBER  0x1
#define CBC_GM_DONT_CROAK             0x2
#define CBC_GM_NO_OFFSET_SIZE_CALC    0x4


/*===== TYPEDEFS =============================================================*/

typedef struct {
  LinkedList hit, off, pad;
  HashTable  htpad;
} GMSInfo;

typedef struct {
  TypeSpec    type;
  Declarator *pDecl;
  int         level;
  unsigned    offset;
  unsigned    size;
  u_32        flags;
} MemberInfo;


/*===== FUNCTION PROTOTYPES ==================================================*/

#define get_all_member_strings CBC_get_all_member_strings
int get_all_member_strings(pTHX_ MemberInfo *pMI, LinkedList list);

#define get_member_string CBC_get_member_string
SV *get_member_string(pTHX_ const MemberInfo *pMI, int offset, GMSInfo *pInfo);

#define get_member CBC_get_member
int get_member(pTHX_ const MemberInfo *pMI, const char *member,
               MemberInfo *pMIout, unsigned gm_flags);

#endif
