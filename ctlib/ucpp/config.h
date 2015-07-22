/*******************************************************************************
*
* HEADER: config.h
*
********************************************************************************
*
* DESCRIPTION: Configuration for ucpp
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2004/03/22 19:37:58 +0000 $
* $Revision: 6 $
* $Snapshot: /Convert-Binary-C/0.52 $
* $Source: /ctlib/ucpp/config.h $
*
********************************************************************************
*
* Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _UCPP_CONFIG_H
#define _UCPP_CONFIG_H

#include "../arch.h"

/*------------------------*/
/* build a reentrant ucpp */
/*------------------------*/

/* #define UCPP_REENTRANT */

/*------------------------*/
/* configure ucpp pragmas */
/*------------------------*/

#define PRAGMA_TOKENIZE
#define PRAGMA_TOKEN_END ((unsigned char)'\n')

/*-------------*/
/* no defaults */
/*-------------*/

#define STD_INCLUDE_PATH 0
#define STD_ASSERT       0
#define STD_MACROS       0

/*-------------------------*/
/* 64-bit integer handling */
/*-------------------------*/

#ifdef NATIVE_64_BIT_INTEGER

#define NATIVE_UINTMAX u_64
#define NATIVE_INTMAX  i_64

#define NATIVE_SIGNED           i_64
#define NATIVE_UNSIGNED         u_64
#define NATIVE_UNSIGNED_BITS    64
#define NATIVE_SIGNED_MIN       (-9223372036854775807LL - 1)
#define NATIVE_SIGNED_MAX       9223372036854775807LL

#else

#define SIMUL_UINTMAX

#undef NATIVE_SIGNED
#define SIMUL_ARITH_SUBTYPE     u_32
#define SIMUL_SUBTYPE_BITS      32
#define SIMUL_NUMBITS           64

#endif

/*----------------------------------*/
/* configure preprocessor and lexer */
/*----------------------------------*/

#define DEFAULT_CPP_FLAGS	(DISCARD_COMMENTS | WARN_STANDARD \
				| WARN_PRAGMA | FAIL_SHARP | MACRO_VAARG \
				| CPLUSPLUS_COMMENTS | LINE_NUM | TEXT_OUTPUT \
				| KEEP_OUTPUT | HANDLE_TRIGRAPHS \
				| HANDLE_ASSERTIONS)

#define DEFAULT_LEXER_FLAGS	(DISCARD_COMMENTS | FAIL_SHARP | LEXER \
				| HANDLE_TRIGRAPHS | HANDLE_ASSERTIONS)

/*-------------*/
/* other stuff */
/*-------------*/

#define ARITHMETIC_CHECKS

/* #define LOW_MEM */

#define NO_UCPP_ERROR_FUNCTIONS

#define MAX_CHAR_VAL 256

#define UCPP_PUBLIC_PREFIX	ucpp_public_
#define UCPP_PRIVATE_PREFIX	ucpp_private_

#endif /* _UCPP_CONFIG_H */
