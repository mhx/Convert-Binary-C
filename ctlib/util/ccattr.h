/*******************************************************************************
*
* HEADER: ccattr
*
********************************************************************************
*
* DESCRIPTION: Define special features of C compilers.
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/23 21:21:24 +0000 $
* $Revision: 3 $
* $Snapshot: /Convert-Binary-C/0.41 $
* $Source: /ctlib/util/ccattr.h $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of either the Artistic License or the
* GNU General Public License as published by the Free Software
* Foundation; either version 2 of the License, or (at your option)
* any later version.
*
* THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
* IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
* WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
*
*******************************************************************************/

#ifndef _UTIL_CCATTR_H
#define _UTIL_CCATTR_H

/*--------*/
/* inline */
/*--------*/

#if __STDC__ && __STDC_VERSION__ >= 199901L
/* C99 compiler, inline is a valid keyword */
#elif defined(__GNUC__)
/* GNU compiler, inline is __inline__ */
# ifdef  inline
#  undef inline
# endif
# define inline __inline__
#else
/* Other compiler, forget about inline */
# ifdef  inline
#  undef inline
# endif
# define inline
#endif

/*---------------*/
/* __attribute__ */
/*---------------*/

#if defined(__GNUC__) && ( __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ >= 95) )
  /* we can use attributes */
#else
# ifdef  __attribute__
#  undef __attribute__
# endif
# define __attribute__( x )
#endif

#endif
