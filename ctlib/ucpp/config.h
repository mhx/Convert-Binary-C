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
* $Date: 2002/04/15 22:26:49 +0100 $
* $Revision: 1 $
* $Snapshot: /Convert-Binary-C/0.02 $
* $Source: /ctlib/ucpp/config.h $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

#ifndef _UCPP_CONFIG_H
#define _UCPP_CONFIG_H

#include "../arch.h"

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

#else

#define SIMUL_UINTMAX

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

#define NO_UCPP_ERROR_FUNCTIONS

#define MAX_CHAR_VAL 256

#endif /* _UCPP_CONFIG_H */
