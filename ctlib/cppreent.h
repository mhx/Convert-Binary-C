/*******************************************************************************
*
* HEADER: cppreent.h
*
********************************************************************************
*
* DESCRIPTION: Some macros to help with ucpp reentrancy
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2005/01/23 11:49:39 +0000 $
* $Revision: 5 $
* $Source: /ctlib/cppreent.h $
*
********************************************************************************
*
* Copyright (c) 2002-2005 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _CTLIB_CPPREENT_H
#define _CTLIB_CPPREENT_H

/*===== GLOBAL INCLUDES ======================================================*/

/*===== LOCAL INCLUDES =======================================================*/

#include "util/ccattr.h"

/*===== DEFINES ==============================================================*/

#ifdef pUCPP
# undef pUCPP
#endif

#ifdef pUCPP_
# undef pUCPP_
#endif

#ifdef aUCPP
# undef aUCPP
#endif

#ifdef aUCPP_
# undef aUCPP_
#endif

#ifdef dUCPP
# undef dUCPP
#endif

#ifdef UCPP_REENTRANT

# define pUCPP     struct CPP *cpp __attribute__((unused))
# define pUCPP_    pUCPP,
# define aUCPP     cpp
# define aUCPP_    aUCPP,
# define dUCPP(a)  pUCPP = (struct CPP *)a

/* ucpp global variables */
# define r_no_special_macros   ((struct CPP *) cpp)->no_special_macros
# define r_emit_defines        ((struct CPP *) cpp)->emit_defines
# define r_emit_assertions     ((struct CPP *) cpp)->emit_assertions
# define r_emit_dependencies   ((struct CPP *) cpp)->emit_dependencies
# define r_current_filename    ((struct CPP *) cpp)->current_filename

#else /* !UCPP_REENTRANT */

# define pUCPP     void
# define pUCPP_
# define aUCPP
# define aUCPP_
# define dUCPP(a)  extern int CTlib___notused __attribute__((unused))

# define r_no_special_macros   no_special_macros
# define r_emit_defines        emit_defines
# define r_emit_assertions     emit_assertions
# define r_emit_dependencies   emit_dependencies
# define r_current_filename    current_filename

#endif /* UCPP_REENTRANT */

/*===== TYPEDEFS =============================================================*/

struct CPP;

/*===== FUNCTION PROTOTYPES ==================================================*/

#endif
