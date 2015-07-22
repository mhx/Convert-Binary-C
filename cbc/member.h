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
* $Date: 2005/10/19 10:31:14 +0100 $
* $Revision: 3 $
* $Source: /cbc/member.h $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
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
               MemberInfo *pMIout, int accept_dotless_member, int dont_croak);

#endif
