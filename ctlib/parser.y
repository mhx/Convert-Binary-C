%{
/*******************************************************************************
*
* MODULE: parser.y
*
********************************************************************************
*
* DESCRIPTION: C parser
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2003/01/14 20:13:03 +0000 $
* $Revision: 19 $
* $Snapshot: /Convert-Binary-C/0.08 $
* $Source: /ctlib/parser.y $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
* Portions Copyright (c) 1989, 1990 James A. Roskind.
* Also see the original copyright notice below.
*
*******************************************************************************/

/* Copyright (C) 1989,1990 James A. Roskind, All rights reserved.
This grammar was developed  and  written  by  James  A.  Roskind.
Copying  of  this  grammar  description, as a whole, is permitted
providing this notice is intact and applicable  in  all  complete
copies.   Translations as a whole to other parser generator input
languages  (or  grammar  description  languages)   is   permitted
provided  that  this  notice is intact and applicable in all such
copies,  along  with  a  disclaimer  that  the  contents  are   a
translation.   The reproduction of derived text, such as modified
versions of this grammar, or the output of parser generators,  is
permitted,  provided  the  resulting  work includes the copyright
notice "Portions Copyright (c)  1989,  1990  James  A.  Roskind".
Derived products, such as compilers, translators, browsers, etc.,
that  use  this  grammar,  must also provide the notice "Portions
Copyright  (c)  1989,  1990  James  A.  Roskind"  in   a   manner
appropriate  to  the  utility,  and in keeping with copyright law
(e.g.: EITHER displayed when first invoked/executed; OR displayed
continuously on display terminal; OR via placement in the  object
code  in  form  readable in a printout, with or near the title of
the work, or at the end of the file).  No royalties, licenses  or
commissions  of  any  kind are required to copy this grammar, its
translations, or derivative products, when the copies are made in
compliance with this notice. Persons or corporations that do make
copies in compliance with this notice may charge  whatever  price
is  agreeable  to  a  buyer, for such copies or derivative works.
THIS GRAMMAR IS PROVIDED ``AS IS'' AND  WITHOUT  ANY  EXPRESS  OR
IMPLIED  WARRANTIES,  INCLUDING,  WITHOUT LIMITATION, THE IMPLIED
WARRANTIES  OF  MERCHANTABILITY  AND  FITNESS  FOR  A  PARTICULAR
PURPOSE.

James A. Roskind
Independent Consultant
516 Latania Palm Drive
Indialantic FL, 32903
(407)729-4348
jar@ileaf.com


ACKNOWLEDGMENT:

Without the effort expended by the ANSI C standardizing committee,  I
would  have been lost.  Although the ANSI C standard does not include
a fully disambiguated syntax description, the committee has at  least
provided most of the disambiguating rules in narratives.

Several  reviewers  have also recently critiqued this grammar, and/or
assisted in discussions during it's preparation.  These reviewers are
certainly not responsible for the errors I have committed  here,  but
they  are responsible for allowing me to provide fewer errors.  These
colleagues include: Bruce Blodgett, and Mark Langley.

*/

/*===== GLOBAL INCLUDES ======================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "ctdebug.h"
#include "ctparse.h"
#include "fileinfo.h"
#include "parser.h"
#include "pragma.h"

#include "util/list.h"
#include "util/memalloc.h"

#include "ucpp/cpp.h"


/*===== DEFINES ==============================================================*/

/* ADDITIONAL BISON CONFIGURATION */

#define YYPARSE_PARAM pState
#define YYLEX_PARAM   pState
#define YYERROR_VERBOSE

/*
 * Bison version >= 1.31 is needed for YYFPRINTF
 */
#if YYDEBUG && defined CTYPE_DEBUGGING
#define YYFPRINTF BisonDebugFunc
#endif

#define c_error( msg )    \
        parser_error( PSTATE, msg )


/* MACROS */

#define PSTATE                  ((ParserState *) pState)

#if CTYPE_DEBUGGING
#define EX_OBJECT( id, list, obj ) ex_object( id, list, obj )
#else
#define EX_OBJECT( id, list, obj ) ex_object( list, obj )
#endif

#define EX_NODE( node )         EX_OBJECT( "Node",           PSTATE->nodeList,            node  )
#define EX_DECL( decl )         EX_OBJECT( "Declarator",     PSTATE->declaratorList,      decl  )
#define EX_ARRAY( array )       EX_OBJECT( "Array",          PSTATE->arrayList,           array )
#define EX_STRUCT_DECL( decl )  EX_OBJECT( "StructDecl",     PSTATE->structDeclList,      decl  )
#define EX_STRDECL_LIST( list ) EX_OBJECT( "StructDeclList", PSTATE->structDeclListsList, list  )

#define STORE_IN_HASH( table, key, obj )                                       \
        do {                                                                   \
          if( key.node == NULL )                                               \
            HT_store( PSTATE->pCPI->table, key.str, key.len, key.hash, obj );  \
          else                                                                 \
            HT_storenode( PSTATE->pCPI->table, EX_NODE( key.node ), obj );     \
        } while(0)

#define DELETE_NODE( key )                                                     \
        do {                                                                   \
          if( key.node != NULL )                                               \
            HN_delete( EX_NODE( key.node ) );                                  \
        } while(0)

#define POSTFIX_DECL( decl, postfix )                                          \
        do {                                                                   \
	  if( postfix ) {                                                      \
            EX_ARRAY( postfix );                                               \
	    if( decl->pointer_flag )                                           \
	      LL_destroy( postfix, (LLDestroyFunc) value_delete );             \
	    else                                                               \
	      LL_delete( LL_splice( decl->array, 0, 0, postfix ) );            \
	  }                                                                    \
        } while(0)

#define MAKE_TYPEDEF( list, decl )                                                \
        do {                                                                      \
	  Typedef *pTypedef = typedef_new( &(list->type), EX_DECL( decl ) );      \
	  CT_DEBUG( PARSER, ("making new typedef => %s (list 0x%08X)",            \
                             decl->identifier, list) );                           \
	  LL_push( list->typedefs, pTypedef );                                    \
	  HT_store( PSTATE->pCPI->htTypedefs, decl->identifier, 0, 0, pTypedef ); \
        } while(0)

#define UNDEF_VAL( x ) do { x.iv = 0; x.flags = V_IS_UNDEF; } while(0)

#define UNARY_OP( result, op, val ) \
          do { result.iv = op val.iv; result.flags = val.flags; } while(0)

#define BINARY_OP( result, val1, op, val2 )           \
          do {                                        \
            result.iv    = val1.iv   op val2.iv;      \
            result.flags = val1.flags | val2.flags;   \
          } while(0)

#define LLC_OR( t1, t2 )                              \
        (                                             \
          ((t1) & T_LONG) && ((t2) & T_LONG)          \
          ? (t1) | (t2) | T_LONGLONG : (t1) | (t2)    \
        )

#define F_LOCAL     0x00000001U
#define BEGIN_LOCAL (PSTATE->flags |= F_LOCAL)
#define END_LOCAL   (PSTATE->flags &= ~F_LOCAL)
#define IS_LOCAL    (PSTATE->flags & F_LOCAL)

/*===== TYPEDEFS =============================================================*/

struct _ParserState {

  const CParseConfig *pCPC;

  CParseInfo         *pCPI;

  LinkedList          curEnumList;
  LinkedList          nodeList,
                      arrayList,
                      declaratorList,
                      declListsList,
                      structDeclList,
                      structDeclListsList;

  PragmaState         pragma;

  struct lexer_state *pLexer;

  FileInfo           *pFI;

  u_32                flags;

};

typedef struct {
  char    *str;
  int      len;
  HashSum  hash;
  HashNode node;
} IdOrTypeName;


/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

static int   c_lex( void *pYYLVAL, ParserState *pState );

static int   get_char_value( char *s );
static int   string_size( char *s );
static int   check_type( void *pVVLVAL, ParserState *pState, char *s );
static void  parser_error( ParserState *pState, char *msg );

#ifdef CTYPE_DEBUGGING
static void *ex_object( char *type, LinkedList list, void *object );
#else
static void *ex_object( LinkedList list, void *object );
#endif


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

/* TOKEN MAPPING TABLE */

static const int tokentab[] = {
	0,		/* NONE, */		/* whitespace */
	0,		/* NEWLINE, */		/* newline */
	0,		/* COMMENT, */		/* comment */
	0,		/* NUMBER, */		/* number constant */
	0,		/* NAME, */		/* identifier */
	0,		/* BUNCH, */		/* non-C characters */
	0,		/* PRAGMA, */		/* a #pragma directive */
	0,		/* CONTEXT, */		/* new file or #line */
	0,		/* STRING, */		/* constant "xxx" */
	CONSTANT,	/* CHAR, */		/* constant 'xxx' */
	'/',		/* SLASH, */		/*	/	*/
	DIV_ASSIGN,	/* ASSLASH, */		/*	/=	*/
	'-',		/* MINUS, */		/*	-	*/
	DEC_OP,		/* MMINUS, */		/*	--	*/
	SUB_ASSIGN,	/* ASMINUS, */		/*	-=	*/
	PTR_OP,		/* ARROW, */		/*	->	*/
	'+',		/* PLUS, */		/*	+	*/
	INC_OP,		/* PPLUS, */		/*	++	*/
	ADD_ASSIGN,	/* ASPLUS, */		/*	+=	*/
	'<',		/* LT, */		/*	<	*/
	LE_OP,		/* LEQ, */		/*	<=	*/
	LEFT_OP,	/* LSH, */		/*	<<	*/
	LEFT_ASSIGN,	/* ASLSH, */		/*	<<=	*/
	'>',		/* GT, */		/*	>	*/
	GE_OP,		/* GEQ, */		/*	>=	*/
	RIGHT_OP,	/* RSH, */		/*	>>	*/
	RIGHT_ASSIGN,	/* ASRSH, */		/*	>>=	*/
	'=',		/* ASGN, */		/*	=	*/
	EQ_OP,		/* SAME, */		/*	==	*/
#ifdef CAST_OP
	0,		/* CAST, */		/*	=>	*/
#endif
	'~',		/* NOT, */		/*	~	*/
	NE_OP,		/* NEQ, */		/*	!=	*/
	'&',		/* AND, */		/*	&	*/
	AND_OP,		/* LAND, */		/*	&&	*/
	AND_ASSIGN,	/* ASAND, */		/*	&=	*/
	'|',		/* OR, */		/*	|	*/
	OR_OP,		/* LOR, */		/*	||	*/
	OR_ASSIGN,	/* ASOR, */		/*	|=	*/
	'%',		/* PCT, */		/*	%	*/
	MOD_ASSIGN,	/* ASPCT, */		/*	%=	*/
	'*',		/* STAR, */		/*	*	*/
	MUL_ASSIGN,	/* ASSTAR, */		/*	*=	*/
	'^',		/* CIRC, */		/*	^	*/
	XOR_ASSIGN,	/* ASCIRC, */		/*	^=	*/
	'!',		/* LNOT, */		/*	!	*/
	'{',		/* LBRA, */		/*	{	*/
	'}',		/* RBRA, */		/*	}	*/
	'[',		/* LBRK, */		/*	[	*/
	']',		/* RBRK, */		/*	]	*/
	'(',		/* LPAR, */		/*	(	*/
	')',		/* RPAR, */		/*	)	*/
	',',		/* COMMA, */		/*	,	*/
	'?',		/* QUEST, */		/*	?	*/
	';',		/* SEMIC, */		/*	;	*/
	':',		/* COLON, */		/*	:	*/
	'.',		/* DOT, */		/*	.	*/
	ELLIPSIS,	/* MDOTS, */		/*	...	*/
	0,		/* SHARP, */		/*	#	*/
	0,		/* DSHARP, */		/*	##	*/

	0,		/* OPT_NONE, */		/* optional space to separate tokens in text output */

	0,		/* DIGRAPH_TOKENS, */		/* there begin digraph tokens */

	/* for DIG_*, do not change order, unless checking undig() in cpp.c */
	'[',		/* DIG_LBRK, */		/*	<:	*/
	']',		/* DIG_RBRK, */		/*	:>	*/
	'{',		/* DIG_LBRA, */		/*	<%	*/
	'}',		/* DIG_RBRA, */		/*	%>	*/
	0,		/* DIG_SHARP, */	/*	%:	*/
	0,		/* DIG_DSHARP, */	/*	%:%:	*/

	0,		/* DIGRAPH_TOKENS_END, */	/* digraph tokens end here */

	0,		/* LAST_MEANINGFUL_TOKEN, */	/* reserved words will go there */

	0,		/* MACROARG, */		/* special token for representing macro arguments */

	0,		/* UPLUS = CPPERR, */	/* unary + */
	0,		/* UMINUS */		/* unary - */
};

%}

/*===== YACC PARSER DEFINITION ================================================*/

/* This refined grammar resolves several typedef ambiguities  in  the
draft  proposed  ANSI  C  standard  syntax  down  to  1  shift/reduce
conflict, as reported by a YACC process.  Note  that  the  one  shift
reduce  conflicts  is the traditional if-if-else conflict that is not
resolved by the grammar.  This ambiguity can  be  removed  using  the
method  described in the Dragon Book (2nd edition), but this does not
appear worth the effort.

There was quite a bit of effort made to reduce the conflicts to  this
level,  and  an  additional effort was made to make the grammar quite
similar to the C++ grammar being developed in  parallel.   Note  that
this grammar resolves the following ANSI C ambiguity as follows:

ANSI  C  section  3.5.6,  "If  the [typedef name] is redeclared at an
inner scope, the type specifiers shall not be omitted  in  the  inner
declaration".   Supplying type specifiers prevents consideration of T
as a typedef name in this grammar.  Failure to supply type specifiers
forced the use of the TYPEDEFname as a type specifier.

ANSI C section 3.5.4.3, "In a parameter declaration, a single typedef
name in parentheses is  taken  to  be  an  abstract  declarator  that
specifies  a  function  with  a  single  parameter,  not as redundant
parentheses around the identifier".  This is extended  to  cover  the
following cases:

typedef float T;
int noo(const (T[5]));
int moo(const (T(int)));
...

Where  again the '(' immediately to the left of 'T' is interpreted as
being the start of a parameter type list,  and  not  as  a  redundant
paren around a redeclaration of T.  Hence an equivalent code fragment
is:

typedef float T;
int noo(const int identifier1 (T identifier2 [5]));
int moo(const int identifier1 (T identifier2 (int identifier3)));
...

*/

%union {
  HashNode           identifier;
  Declarator        *pDecl;
  AbstractDeclarator absDecl;
  StructDeclaration *pStructDecl;
  TypedefList       *pTypedefList;
  LinkedList         list;
  Enumerator        *pEnum;
  TypeSpec           tspec;
  Value              value;
  struct {
    unsigned long    uval;
    ContextInfo      ctx;
  }                  context;
  signed long        ival;
  unsigned long      uval;
  char               oper;
  IdOrTypeName       idOrType;
}

/* Define terminal tokens */

/* keywords */
%token AUTO_TOK         DOUBLE_TOK       INT_TOK          STRUCT_TOK
%token BREAK_TOK        ELSE_TOK         LONG_TOK         SWITCH_TOK
%token CASE_TOK         ENUM_TOK         REGISTER_TOK     TYPEDEF_TOK
%token CHAR_TOK         EXTERN_TOK       RETURN_TOK       UNION_TOK
%token CONST_TOK        FLOAT_TOK        SHORT_TOK        UNSIGNED_TOK
%token CONTINUE_TOK     FOR_TOK          SIGNED_TOK       VOID_TOK
%token DEFAULT_TOK      GOTO_TOK         SIZEOF_TOK       VOLATILE_TOK
%token DO_TOK           IF_TOK           STATIC_TOK       WHILE_TOK

/* keywords new in ANSI-C99 */
%token INLINE_TOK       RESTRICT_TOK

/* special tokens */
%token SKIP_TOK

/* Multi-Character operators */
%token  PTR_OP                     /*    ->                              */
%token  INC_OP DEC_OP              /*    ++      --                      */
%token  LEFT_OP RIGHT_OP           /*    <<      >>                      */
%token  LE_OP GE_OP EQ_OP NE_OP    /*    <=      >=      ==      !=      */
%token  AND_OP OR_OP               /*    &&      ||                      */
%token  ELLIPSIS                   /*    ...                             */

/* modifying assignment operators */
%token MUL_ASSIGN  DIV_ASSIGN   MOD_ASSIGN  /*   *=      /=      %=      */
%token ADD_ASSIGN  SUB_ASSIGN               /*   +=      -=              */
%token LEFT_ASSIGN RIGHT_ASSIGN             /*   <<=     >>=             */
%token AND_ASSIGN  XOR_ASSIGN   OR_ASSIGN   /*   &=      ^=      |=      */

/* ANSI Grammar suggestions */
%token <identifier>  IDENTIFIER
%token <value>       STRING_LITERAL
%token <value>       CONSTANT

/* New Lexical element, whereas ANSI suggested non-terminal */

%token <tspec>       TYPE_NAME
                       /* Lexer will tell the difference between this and
        an  identifier!   An  identifier  that is CURRENTLY in scope as a
        typedef name is provided to the parser as a TYPE_NAME.*/

%type <idOrType>     identifier_or_typedef_name

%type <oper>         unary_operator

%type <pEnum>        enumerator

%type <absDecl>      abstract_declarator
                     unary_abstract_declarator
                     postfix_abstract_declarator

%type <pTypedefList> declaring_list
                     default_declaring_list

%type <tspec>        declaration_specifier
                     sue_declaration_specifier
                     typedef_declaration_specifier
                     elaborated_type_name
                     su_type_specifier
                     sut_type_specifier
                     sue_type_specifier
                     typedef_type_specifier
                     aggregate_name
                     enum_name
                     type_specifier

%type <pStructDecl>  member_declaration
                     member_default_declaring_list
                     member_declaring_list
                     unnamed_su_declaration

%type <pDecl>        identifier_declarator
                     declarator
                     member_identifier_declarator
                     member_declarator
                     parameter_typedef_declarator
                     typedef_declarator
                     paren_typedef_declarator
                     clean_typedef_declarator
                     clean_postfix_typedef_declarator
                     paren_postfix_typedef_declarator
                     simple_paren_typedef_declarator
                     unary_identifier_declarator
                     paren_identifier_declarator
                     postfix_identifier_declarator

%type <list>         enumerator_list
                     postfixing_abstract_declarator
                     array_abstract_declarator
                     member_declaration_list

%type <uval>         basic_declaration_specifier
                     declaration_qualifier_list
                     basic_type_specifier
                     storage_class
                     basic_type_name
                     declaration_qualifier
                     aggregate_key

%type <context>      aggregate_key_context
                     enum_key_context

%type <value>        string_literal_list
                     primary_expression
                     postfix_expression
                     unary_expression
                     cast_expression
                     multiplicative_expression
                     additive_expression
                     shift_expression
                     relational_expression
                     equality_expression
                     AND_expression
                     exclusive_OR_expression
                     inclusive_OR_expression
                     logical_AND_expression
                     logical_OR_expression
                     conditional_expression
                     assignment_expression
                     comma_expression
                     constant_expression
                     type_name

%type <ival>
                     bit_field_size
                     bit_field_size_opt



/*************************************************************************/

%expect 1
%pure_parser

%start source_file

/*************************************************************************/

%%

string_literal_list
	: STRING_LITERAL { $$ = $1; }
	| string_literal_list STRING_LITERAL
	  { BINARY_OP( $$, $1, +, $2 ); }
	;


/************************* EXPRESSIONS ********************************/
primary_expression
	: IDENTIFIER  /* We cannot use a typedef name as a variable */
	  {
	    if( $1 )
	      HN_delete( EX_NODE( $1 ) );
	    UNDEF_VAL( $$ );
	  }
	| CONSTANT { $$ = $1; }
	| string_literal_list { $$ = $1; $$.iv++; }
	| '(' comma_expression ')' { $$ = $2; }
	;

postfix_expression
	: primary_expression { $$ = $1; }
	| postfix_expression '[' comma_expression ']'    { UNDEF_VAL( $$ ); }
	| postfix_expression '(' ')'                     { UNDEF_VAL( $$ ); }
	| postfix_expression '(' argument_expression_list ')' { UNDEF_VAL( $$ ); }
	| postfix_expression {} '.'   member_name        { UNDEF_VAL( $$ ); }
	| postfix_expression {} PTR_OP member_name       { UNDEF_VAL( $$ ); }
	| postfix_expression INC_OP                      { UNDEF_VAL( $$ ); }
	| postfix_expression DEC_OP                      { UNDEF_VAL( $$ ); }
	| '(' type_name ')' '{' initializer_list '}'     { UNDEF_VAL( $$ ); } /* ANSI-C99 addition */
	| '(' type_name ')' '{' initializer_list ',' '}' { UNDEF_VAL( $$ ); } /* ANSI-C99 addition */
	;

member_name
	: IDENTIFIER { if( $1 ) HN_delete( EX_NODE( $1 ) ); }
	| TYPE_NAME {}
	;

argument_expression_list
	: assignment_expression {}
	| argument_expression_list ',' assignment_expression {}
	;

unary_expression
	: postfix_expression      { $$ = $1; }
	| INC_OP unary_expression { UNDEF_VAL( $$ ); }
	| DEC_OP unary_expression { UNDEF_VAL( $$ ); }
	| unary_operator cast_expression
	  {
	    switch( $1 ) {
	      case '-' : UNARY_OP( $$, -, $2 ); break;
	      case '~' : UNARY_OP( $$, ~, $2 ); break;
	      case '!' : UNARY_OP( $$, !, $2 ); break;
	      case '+' : $$ = $2;               break;

	      case '*' :
	      case '&' :
	        $$ = $2; $$.flags |= V_IS_UNSAFE_PTROP;
                break;

	      default:
	        UNDEF_VAL( $$ );
	        break;
	    }
	  }
	| SIZEOF_TOK unary_expression  { $$ = $2; }
	| SIZEOF_TOK '(' type_name ')' { $$ = $3; }
	;

unary_operator
	: '&' { $$ = '&'; }
	| '*' { $$ = '*'; }
	| '+' { $$ = '+'; }
	| '-' { $$ = '-'; }
	| '~' { $$ = '~'; }
	| '!' { $$ = '!'; }
	;

cast_expression
	: unary_expression { $$ = $1; }
	| '(' type_name ')' cast_expression { $$ = $4; $$.flags |= V_IS_UNSAFE_CAST; }
	;

multiplicative_expression
	: cast_expression { $$ = $1; }
	| multiplicative_expression '*' cast_expression
	  { BINARY_OP( $$, $1, *, $3 ); }
	| multiplicative_expression '/' cast_expression
	  {
	    if( $3.iv == 0 )
	      UNDEF_VAL( $$ );
	    else
	      BINARY_OP( $$, $1, /, $3 );
	  }
	| multiplicative_expression '%' cast_expression
	  {
	    if( $3.iv == 0 )
	      UNDEF_VAL( $$ );
	    else
	      BINARY_OP( $$, $1, %, $3 );
	  }
	;

additive_expression
	: multiplicative_expression { $$ = $1; }
	| additive_expression '+' multiplicative_expression
	  { BINARY_OP( $$, $1, +, $3 ); }
	| additive_expression '-' multiplicative_expression
	  { BINARY_OP( $$, $1, -, $3 ); }
	;

shift_expression
	: additive_expression { $$ = $1; }
	| shift_expression LEFT_OP additive_expression
	  { BINARY_OP( $$, $1, <<, $3 ); }
	| shift_expression RIGHT_OP additive_expression
	  { BINARY_OP( $$, $1, >>, $3 ); }
	;

relational_expression
	: shift_expression { $$ = $1; }
	| relational_expression '<' shift_expression
	  { BINARY_OP( $$, $1, <,  $3 ); }
	| relational_expression '>' shift_expression
	  { BINARY_OP( $$, $1, >,  $3 ); }
	| relational_expression LE_OP shift_expression
	  { BINARY_OP( $$, $1, <=, $3 ); }
	| relational_expression GE_OP shift_expression
	  { BINARY_OP( $$, $1, >=, $3 ); }
	;

equality_expression
	: relational_expression { $$ = $1; }
	| equality_expression EQ_OP relational_expression
	  { BINARY_OP( $$, $1, ==, $3 ); }
	| equality_expression NE_OP relational_expression
	  { BINARY_OP( $$, $1, !=, $3 ); }
	;

AND_expression
	: equality_expression { $$ = $1; }
	| AND_expression '&' equality_expression
	  { BINARY_OP( $$, $1, &, $3 ); }
	;

exclusive_OR_expression
	: AND_expression { $$ = $1; }
	| exclusive_OR_expression '^' AND_expression
	  { BINARY_OP( $$, $1, ^, $3 ); }
	;

inclusive_OR_expression
	: exclusive_OR_expression { $$ = $1; }
	| inclusive_OR_expression '|' exclusive_OR_expression
	  { BINARY_OP( $$, $1, |, $3 ); }
	;

logical_AND_expression
	: inclusive_OR_expression { $$ = $1; }
	| logical_AND_expression AND_OP inclusive_OR_expression
	  { BINARY_OP( $$, $1, &&, $3 ); }
	;

logical_OR_expression
	: logical_AND_expression { $$ = $1; }
	| logical_OR_expression OR_OP logical_AND_expression
	  { BINARY_OP( $$, $1, ||, $3 ); }
	;

conditional_expression
	: logical_OR_expression { $$ = $1; }
	| logical_OR_expression '?' comma_expression ':' conditional_expression
          { $$ = $1.iv ? $3 : $5; $$.flags |= $1.flags; }
	;

assignment_expression
	: conditional_expression { $$ = $1; }
	| unary_expression assignment_operator assignment_expression { UNDEF_VAL( $$ ); }
	;

assignment_operator
	: '=' {}
	| MUL_ASSIGN {}
	| DIV_ASSIGN {}
	| MOD_ASSIGN {}
	| ADD_ASSIGN {}
	| SUB_ASSIGN {}
	| LEFT_ASSIGN {}
	| RIGHT_ASSIGN {}
	| AND_ASSIGN {}
	| XOR_ASSIGN {}
	| OR_ASSIGN {}
	;

comma_expression
	: assignment_expression { $$ = $1; }
	| comma_expression ',' assignment_expression { $$ = $3; }
	;

constant_expression
	: conditional_expression { $$ = $1; }
	;

    /* The following was used for clarity */
comma_expression_opt
	: /* Nothing */
	| comma_expression {}
	;



/******************************* DECLARATIONS *********************************/

    /* The following is different from the ANSI C specified  grammar.
    The  changes  were  made  to  disambiguate  typedef's presence in
    declaration_specifiers (vs.  in the declarator for redefinition);
    to allow struct/union/enum tag declarations without  declarators,
    and  to  better  reflect the parsing of declarations (declarators
    must be combined with declaration_specifiers ASAP  so  that  they
    are visible in scope).

    Example  of  typedef  use  as either a declaration_specifier or a
    declarator:

      typedef int T;
      struct S { T T;}; / * redefinition of T as member name * /

    Example of legal and illegal statements detected by this grammar:

      int; / * syntax error: vacuous declaration * /
      struct S;  / * no error: tag is defined or elaborated * /

    Example of result of proper declaration binding:

	int a=sizeof(a); / * note that "a" is declared with a type  in
	    the name space BEFORE parsing the initializer * /

	int b, c[sizeof(b)]; / * Note that the first declarator "b" is
	     declared  with  a  type  BEFORE the second declarator is
	     parsed * /

    */

declaration
	: sue_declaration_specifier ';' {}
	| sue_type_specifier ';' {}
	| declaring_list ';' {}
	| default_declaring_list ';' {}
	;

    /* Note that if a typedef were  redeclared,  then  a  declaration
    specifier must be supplied */

default_declaring_list  /* Can't redeclare typedef names */
	: declaration_qualifier_list identifier_declarator initializer_opt
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      if( $1 & T_TYPEDEF ) {
	        TypeSpec ts;
	        ts.tflags = $1;
	        ts.ptr    = NULL;
                if( (ts.tflags & ANY_TYPE_NAME) == 0 )
                  ts.tflags |= T_INT;
	        $$ = typedef_list_new( ts, LL_new() );
	        LL_push( PSTATE->pCPI->typedef_lists, $$ );
	        MAKE_TYPEDEF( $$, $2 );
	      }
	      else {
	        $$ = NULL;
	        decl_delete( EX_DECL( $2 ) );
	      }
	    }
	  }
	| type_qualifier_list identifier_declarator initializer_opt
	  {
	    $$ = NULL;
	    if( $2 )
	      decl_delete( EX_DECL( $2 ) );
	  }
	| default_declaring_list ',' identifier_declarator initializer_opt
	  {
	    $$ = $1;
	    if( $$ != NULL )
	      MAKE_TYPEDEF( $$, $3 );
	    else if( $3 )
	      decl_delete( EX_DECL( $3 ) );
	  }
	;

declaring_list
	: declaration_specifier declarator initializer_opt
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      if( $1.tflags & T_TYPEDEF ) {
                if( ($1.tflags & ANY_TYPE_NAME) == 0 )
                  $1.tflags |= T_INT;
                else if( $1.tflags & T_ENUM )
                  ((EnumSpecifier *) $1.ptr)->tflags |= T_HASTYPEDEF;
                else if( $1.tflags & (T_STRUCT | T_UNION) )
                  ((Struct *) $1.ptr)->tflags |= T_HASTYPEDEF;
	        $$ = typedef_list_new( $1, LL_new() );
	        LL_push( PSTATE->pCPI->typedef_lists, $$ );
	        MAKE_TYPEDEF( $$, $2 );
	      }
	      else {
	        $$ = NULL;
	        decl_delete( EX_DECL( $2 ) );
	      }
	    }
	  }
	| type_specifier declarator initializer_opt
	  {
	    $$ = NULL;
	    if( $2 )
	      decl_delete( EX_DECL( $2 ) );
	  }
	| declaring_list ',' declarator initializer_opt
	  {
	    $$ = $1;
	    if( $$ != NULL )
	      MAKE_TYPEDEF( $$, $3 );
	    else if( $3 )
	      decl_delete( EX_DECL( $3 ) );
	  }
	;

/* those are all potential typedefs */
declaration_specifier
	: basic_declaration_specifier                /* Arithmetic or void */
	  {
	    $$.ptr    = NULL;
	    $$.tflags = $1;
	  }
	| sue_declaration_specifier     { $$ = $1; } /* struct/union/enum */
	| typedef_declaration_specifier { $$ = $1; } /* typedef*/
	;

/* those can't be typedefs */
type_specifier
	: basic_type_specifier                    /* Arithmetic or void */
	  {
	    $$.ptr    = NULL;
	    $$.tflags = $1;
	  }
	| sue_type_specifier     { $$ = $1; }     /* Struct/Union/Enum */
	| typedef_type_specifier { $$ = $1; }     /* Typedef */
	;


/* those are all potential typedefs */
declaration_qualifier_list  /* const/volatile, AND storage class */
	: storage_class                                    { $$ = $1;      }
	| type_qualifier_list storage_class                { $$ = $2;      }
	| declaration_qualifier_list declaration_qualifier { $$ = $1 | $2; }
	;

type_qualifier_list
	: type_qualifier
	| type_qualifier_list type_qualifier
	;

declaration_qualifier
	: storage_class  { $$ = $1; }
	| type_qualifier { $$ = 0;  }     /* const or volatile */
	;

type_qualifier
	: CONST_TOK
	| RESTRICT_TOK
	| VOLATILE_TOK
	;

basic_declaration_specifier      /* Storage Class+Arithmetic or void */
	: declaration_qualifier_list basic_type_name        { $$ = LLC_OR( $1, $2 ); }
	| basic_type_specifier  storage_class               { $$ = LLC_OR( $1, $2 ); }
	| basic_declaration_specifier declaration_qualifier { $$ = LLC_OR( $1, $2 ); }
	| basic_declaration_specifier basic_type_name       { $$ = LLC_OR( $1, $2 ); }
	;

basic_type_specifier             /* Arithmetic or void */
	: basic_type_name                                   { $$ = $1;               }
	| type_qualifier_list  basic_type_name              { $$ = $2;               }
	| basic_type_specifier type_qualifier               { $$ = $1;               }
	| basic_type_specifier basic_type_name              { $$ = LLC_OR( $1, $2 ); }
	;

sue_declaration_specifier        /* Storage Class + struct/union/enum */
	: declaration_qualifier_list elaborated_type_name
	  {
	    $$.ptr    = $2.ptr;
	    $$.tflags = $2.tflags | $1;
	  }
	| sue_type_specifier storage_class
	  {
	    $$.ptr    = $1.ptr;
	    $$.tflags = $1.tflags | $2;
	  }
	| sue_declaration_specifier declaration_qualifier
	  {
	    $$.ptr    = $1.ptr;
	    $$.tflags = $1.tflags | $2;
	  }
	;

sue_type_specifier               /* struct/union/enum */
	: elaborated_type_name                              { $$ = $1; }
	| type_qualifier_list elaborated_type_name          { $$ = $2; } /* we don't care about */
	| sue_type_specifier type_qualifier                 { $$ = $1; } /* type qualifiers     */
	;

su_type_specifier                /* struct/union */
	: aggregate_name                                    { $$ = $1; }
	| type_qualifier_list aggregate_name                { $$ = $2; } /* we don't care about */
	| sue_type_specifier type_qualifier                 { $$ = $1; } /* type qualifiers     */
	;

sut_type_specifier               /* struct/union/typedef */
	: su_type_specifier                                 { $$ = $1; }
	| typedef_type_specifier                            { $$ = $1; }

typedef_declaration_specifier       /* Storage Class + typedef types */
	: typedef_type_specifier storage_class
	  {
	    $$.ptr    = $1.ptr;
	    $$.tflags = $1.tflags | $2;
	  }
	| declaration_qualifier_list TYPE_NAME
	  {
	    $$.ptr    = $2.ptr;
	    $$.tflags = $2.tflags | $1;
	  }
	| typedef_declaration_specifier declaration_qualifier
	  {
	    $$.ptr    = $1.ptr;
	    $$.tflags = $1.tflags | $2;
	  }
	;

typedef_type_specifier       /* typedef types */
	: TYPE_NAME                                         { $$ = $1; }
	| type_qualifier_list    TYPE_NAME                  { $$ = $2; } /* we don't care about */
	| typedef_type_specifier type_qualifier             { $$ = $1; } /* type qualifiers     */
	;

storage_class
	: TYPEDEF_TOK  { $$ = T_TYPEDEF;  }
	| EXTERN_TOK   { $$ = 0;          }
	| STATIC_TOK   { $$ = 0;          }
	| AUTO_TOK     { $$ = 0;          }  /* don't care about anything but typedefs */
	| REGISTER_TOK { $$ = 0;          }
	| INLINE_TOK   { $$ = 0;          }  /* ANSI-C99 */
	;

basic_type_name
	: INT_TOK      { $$ = T_INT;      }
	| CHAR_TOK     { $$ = T_CHAR;     }
	| SHORT_TOK    { $$ = T_SHORT;    }
	| LONG_TOK     { $$ = T_LONG;     }
	| FLOAT_TOK    { $$ = T_FLOAT;    }
	| DOUBLE_TOK   { $$ = T_DOUBLE;   }
	| SIGNED_TOK   { $$ = T_SIGNED;   }
	| UNSIGNED_TOK { $$ = T_UNSIGNED; }
	| VOID_TOK     { $$ = T_VOID;     }
	;

elaborated_type_name
	: aggregate_name { $$ = $1; }
	| enum_name      { $$ = $1; }
	;

aggregate_name
	: aggregate_key_context '{' member_declaration_list '}'
	  {
	    if( IS_LOCAL ) {
	      $$.tflags = 0;
	      $$.ptr = NULL;
	    }
	    else {
	      Struct *pStruct;
	      LinkedList strdecls = EX_STRDECL_LIST( $3 );
	      pStruct = struct_new( NULL, 0, $1.uval, PSTATE->pragma.pack.current, strdecls );
	      pStruct->context = $1.ctx;
	      LL_push( PSTATE->pCPI->structs, pStruct );
	      $$.tflags = $1.uval;
	      $$.ptr = pStruct;
	    }
	  }
	| aggregate_key_context identifier_or_typedef_name '{' member_declaration_list '}'
	  {
	    if( IS_LOCAL ) {
	      $$.tflags = 0;
	      $$.ptr = NULL;
	    }
	    else {
	      LinkedList strdecls = EX_STRDECL_LIST( $4 );
	      Struct *pStruct = HT_get( PSTATE->pCPI->htStructs, $2.str, $2.len, $2.hash );

	      if( pStruct == NULL ) {
	        pStruct = struct_new( $2.str, $2.len, $1.uval, PSTATE->pragma.pack.current, strdecls );
	        pStruct->context = $1.ctx;
	        LL_push( PSTATE->pCPI->structs, pStruct );
	        STORE_IN_HASH( htStructs, $2, pStruct );
	      }
	      else {
	        DELETE_NODE( $2 );

	        if( pStruct->declarations == NULL ) {
	          pStruct->context      = $1.ctx;
	          pStruct->declarations = strdecls;
	          pStruct->pack         = PSTATE->pragma.pack.current;
	        }
	        else
	          LL_destroy( strdecls, (LLDestroyFunc) structdecl_delete );
	      }
	      $$.tflags = $1.uval;
	      $$.ptr = pStruct;
	    }
	  }
	| aggregate_key_context identifier_or_typedef_name
	  {
	    if( IS_LOCAL ) {
	      $$.tflags = 0;
	      $$.ptr = NULL;
	    }
	    else {
	      Struct *pStruct = HT_get( PSTATE->pCPI->htStructs, $2.str, $2.len, $2.hash );

	      if( pStruct == NULL ) {
	        pStruct = struct_new( $2.str, $2.len, $1.uval, 0, NULL );
	        pStruct->context = $1.ctx;
	        LL_push( PSTATE->pCPI->structs, pStruct );
	        STORE_IN_HASH( htStructs, $2, pStruct );
	      }
	      else {
	        DELETE_NODE( $2 );
	      }

	      $$.tflags = $1.uval;
	      $$.ptr = pStruct;
	    }
	  }
	;

aggregate_key_context
	: aggregate_key
	  {
	    $$.uval     = $1;
	    $$.ctx.pFI  = PSTATE->pFI;
	    $$.ctx.line = PSTATE->pLexer->ctok->line;
	  }
	;

aggregate_key
	: STRUCT_TOK { $$ = T_STRUCT; }
	| UNION_TOK  { $$ = T_UNION;  }
	;

member_declaration_list
	: member_declaration
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = LL_new();
	      LL_push( $$, EX_STRUCT_DECL( $1 ) );
	      LL_unshift( PSTATE->structDeclListsList, $$ );
	      CT_DEBUG( PARSER, ("unshifting struct declaration list (0x%08X) (count=%d)",
	                         $$, LL_count(PSTATE->structDeclListsList)) );
	    }
	  }
	| member_declaration_list member_declaration
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = $1;
	      LL_push( $$, EX_STRUCT_DECL( $2 ) );
	    }
	  }
	;

member_declaration
	: member_declaring_list ';'         { $$ = $1; }
	| member_default_declaring_list ';' { $$ = $1; }
	| unnamed_su_declaration ';'        { $$ = $1; }
	;

unnamed_su_declaration
	: sut_type_specifier
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = structdecl_new( $1, NULL );
	      LL_unshift( PSTATE->structDeclList, $$ );
	      CT_DEBUG( PARSER, ("unshifting unnamed struct declaration (0x%08X)", $$) );
	    }
	  }
	;

member_default_declaring_list     /* doesn't redeclare typedef*/
	: type_qualifier_list member_identifier_declarator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      TypeSpec ts = { NULL, T_INT };
	      $$ = structdecl_new( ts, LL_new() );
	      if( $2 )
	        LL_push( $$->declarators, EX_DECL( $2 ) );
	      LL_unshift( PSTATE->structDeclList, $$ );
	      CT_DEBUG( PARSER, ("unshifting struct declaration (0x%08X) (count=%d)",
	                         $$, LL_count(PSTATE->structDeclList)) );
	    }
	  }
	| member_default_declaring_list ',' member_identifier_declarator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = $1;
	      if( $3 )
	        LL_push( $$->declarators, EX_DECL( $3 ) );
	    }
	  }
	;

member_declaring_list
	: type_specifier member_declarator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      if( ($1.tflags & ANY_TYPE_NAME) == 0 )
	        $1.tflags |= T_INT;
	      $$ = structdecl_new( $1, LL_new() );
	      if( $2 )
	        LL_push( $$->declarators, EX_DECL( $2 ) );
	      LL_unshift( PSTATE->structDeclList, $$ );
	      CT_DEBUG( PARSER, ("unshifting struct declaration (0x%08X) (count=%d)",
	                         $$, LL_count(PSTATE->structDeclList)) );
	    }
	  }
	| member_declaring_list ',' member_declarator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = $1;
	      if( $3 )
	        LL_push( $$->declarators, EX_DECL( $3 ) );
	    }
	  }
	;

member_declarator
	: declarator bit_field_size_opt
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = $1;
	      $$->bitfield_size = $2;
	    }
	  }
	| bit_field_size
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = decl_new( "", 0 );
	      $$->bitfield_size = $1;
	    }
	  }
	;

member_identifier_declarator
	: identifier_declarator bit_field_size_opt
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = $1;
	      $$->bitfield_size = $2;
	    }
	  }
	| bit_field_size
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = decl_new( "", 0 );
	      $$->bitfield_size = $1;
	    }
	  }
	;

bit_field_size_opt
	: /* nothing */  { $$ = -1; }
	| bit_field_size { $$ = $1; }
	;

bit_field_size
	: ':' constant_expression { $$ = $2.iv; }
	;

enum_name
	: enum_key_context '{' enumerator_list '}'
	  {
	    if( IS_LOCAL ) {
	      $$.tflags = 0;
	      $$.ptr = NULL;
	      LL_destroy( $3, (LLDestroyFunc) enum_delete );
	    }
	    else {
	      EnumSpecifier *pEnum = enumspec_new( NULL, 0, $3 );
	      pEnum->context = $1.ctx;
	      LL_push( PSTATE->pCPI->enums, pEnum );
	      $$.tflags = T_ENUM;
	      $$.ptr = pEnum;
	    }
	    PSTATE->curEnumList = NULL;
	  }
	| enum_key_context identifier_or_typedef_name '{' enumerator_list '}'
	  {
	    if( IS_LOCAL ) {
	      $$.tflags = 0;
	      $$.ptr = NULL;
	    }
	    else {
	      EnumSpecifier *pEnum = HT_get( PSTATE->pCPI->htEnums, $2.str, $2.len, $2.hash );

	      if( pEnum == NULL ) {
	        pEnum = enumspec_new( $2.str, $2.len, $4 );
	        pEnum->context = $1.ctx;
	        LL_push( PSTATE->pCPI->enums, pEnum );
	        STORE_IN_HASH( htEnums, $2, pEnum );
	      }
	      else {
	        DELETE_NODE( $2 );

	        if( pEnum->enumerators == NULL ) {
	          enumspec_update( pEnum, $4 );
	          pEnum->context = $1.ctx;
	        }
	        else
	          LL_destroy( $4, (LLDestroyFunc) enum_delete );
	      }

	      $$.tflags = T_ENUM;
	      $$.ptr = pEnum;
	    }

	    PSTATE->curEnumList = NULL;
	  }
	| enum_key_context identifier_or_typedef_name
	  {
	    if( IS_LOCAL ) {
	      $$.tflags = 0;
	      $$.ptr = NULL;
	    }
	    else {
	      EnumSpecifier *pEnum = HT_get( PSTATE->pCPI->htEnums, $2.str, $2.len, $2.hash );

	      if( pEnum == NULL ) {
	        pEnum = enumspec_new( $2.str, $2.len, NULL );
	        pEnum->context = $1.ctx;
	        LL_push( PSTATE->pCPI->enums, pEnum );
	        STORE_IN_HASH( htEnums, $2, pEnum );
	      }
	      else {
	        DELETE_NODE( $2 );
	      }

	      $$.tflags = T_ENUM;
	      $$.ptr = pEnum;
	    }
	  }
	;

enum_key_context
	: ENUM_TOK
	  {
	    $$.ctx.pFI  = PSTATE->pFI;
	    $$.ctx.line = PSTATE->pLexer->ctok->line;
	  }
	;

enumerator_list
	: enumerator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = PSTATE->curEnumList = LL_new();
	      if( $1->value.flags & V_IS_UNDEF ) {
	        $1->value.flags &= ~V_IS_UNDEF;
	        $1->value.iv     = 0;
	      }
	      LL_push( $$, $1 );
	    }
	  }
	| enumerator_list ',' enumerator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      if( $3->value.flags & V_IS_UNDEF ) {
	        Enumerator *pEnum = LL_get( $1, -1 );
	        $3->value.flags = pEnum->value.flags;
	        $3->value.iv    = pEnum->value.iv + 1;
	      }
	      LL_push( $1, $3 );
	      $$ = $1;
	    }
	  }
	  /* XXX: most compilers allow a trailing comma */
	| enumerator_list ','
	  {
	    $$ = $1;
	  }
	;

enumerator
	: identifier_or_typedef_name
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = enum_new( $1.str, $1.len, NULL );
	      STORE_IN_HASH( htEnumerators, $1, $$ );
	    }
	  }
	| identifier_or_typedef_name '=' constant_expression
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = enum_new( $1.str, $1.len, &$3 );
	      STORE_IN_HASH( htEnumerators, $1, $$ );
	    }
	  }
	;

parameter_type_list
	: parameter_list
	| parameter_list ',' ELLIPSIS
	;

parameter_list
	: parameter_declaration
	| parameter_list ',' parameter_declaration
	;

parameter_declaration
	: declaration_specifier                               {}
	| declaration_specifier abstract_declarator           {}
	| declaration_specifier identifier_declarator         { if( $2 ) decl_delete( EX_DECL( $2 ) ); }
	| declaration_specifier parameter_typedef_declarator  { if( $2 ) decl_delete( EX_DECL( $2 ) ); }
	| declaration_qualifier_list                          {}
	| declaration_qualifier_list abstract_declarator      {}
	| declaration_qualifier_list identifier_declarator    { if( $2 ) decl_delete( EX_DECL( $2 ) ); }
	| type_specifier                                      {}
	| type_specifier abstract_declarator                  {}
	| type_specifier identifier_declarator                { if( $2 ) decl_delete( EX_DECL( $2 ) ); }
	| type_specifier parameter_typedef_declarator         { if( $2 ) decl_delete( EX_DECL( $2 ) ); }
	| type_qualifier_list                                 {}
	| type_qualifier_list abstract_declarator             {}
	| type_qualifier_list identifier_declarator           { if( $2 ) decl_delete( EX_DECL( $2 ) ); }
	;

    /*  ANSI  C  section  3.7.1  states  "An identifier declared as a
    typedef name shall not be redeclared as a parameter".  Hence  the
    following is based only on IDENTIFIERs */

identifier_list
	: IDENTIFIER                     { if( $1 ) HN_delete( EX_NODE( $1 ) ); }
	| identifier_list ',' IDENTIFIER { if( $3 ) HN_delete( EX_NODE( $3 ) ); }
	;

identifier_or_typedef_name
	: IDENTIFIER
	  {
	    if( $1 ) {
	      $$.str  = $1->key;
	      $$.len  = $1->keylen;
	      $$.hash = $1->hash;
	      $$.node = $1;
	    }
	    else {
	      $$.str  = NULL;
	      $$.len  = 0;
	      $$.hash = 0;
	      $$.node = NULL;
	    }
	  }
	| TYPE_NAME
	  {
	    if( IS_LOCAL ) {
	      $$.str  = NULL;
	      $$.len  = 0;
	      $$.hash = 0;
	    }
	    else {
	      $$.str = ((Typedef *) $1.ptr)->pDecl->identifier;
	      HASH_STR_LEN( $$.hash, $$.str, $$.len );
	    }
	    $$.node = NULL;
	  }
	;

type_name
	: type_specifier
	  {
	    if( !IS_LOCAL ) {
	      unsigned size;
	      u_32 flags;
	      (void) GetTypeInfo( PSTATE->pCPC, &$1, NULL, &size, NULL, NULL, &flags );
	      $$.iv    = size;
	      $$.flags = 0;
	      if( flags & T_HASBITFIELD )
	        $$.flags |= V_IS_UNSAFE_BITFIELD;
	      if( flags & T_UNSAFE_VAL )
	        $$.flags |= V_IS_UNSAFE;
	    }
	  }
	| type_specifier abstract_declarator
	  {
	    if( !IS_LOCAL ) {
	      if( $2.pointer_flag ) {
	        $$.iv = PSTATE->pCPC->ptr_size * $2.multiplicator;
	      }
	      else {
	        unsigned size;
	        u_32 flags;
	        (void) GetTypeInfo( PSTATE->pCPC, &$1, NULL, &size, NULL, NULL, &flags );
	        $$.iv = size * $2.multiplicator;
	        $$.flags = 0;
	        if( flags & T_HASBITFIELD )
	          $$.flags |= V_IS_UNSAFE_BITFIELD;
	        if( flags & T_UNSAFE_VAL )
	          $$.flags |= V_IS_UNSAFE;
	      }
	    }
	  }
	| type_qualifier_list
	  {
	    if( !IS_LOCAL ) {
	      $$.iv = PSTATE->pCPC->int_size;
	      $$.flags = 0;
	    }
	  }
	| type_qualifier_list abstract_declarator
	  {
	    if( !IS_LOCAL ) {
	      $$.iv = $2.multiplicator * ( $2.pointer_flag ?
                      PSTATE->pCPC->int_size : PSTATE->pCPC->ptr_size );
	      $$.flags = 0;
	    }
	  }
	;

initializer_opt
	: /* nothing */
	| '=' initializer
	;

initializer
	: '{' initializer_list '}'
	| '{' initializer_list ',' '}'
	| assignment_expression {}
	;

initializer_list
	: designation_opt initializer
	| initializer_list ',' designation_opt initializer
	;

designation_opt
	: /* nothing */
	| designator_list '='
	;

designator_list
	: designator
	| designator_list designator
	;

designator
	: '[' constant_expression ']'
	| '.' identifier_or_typedef_name { DELETE_NODE( $2 ); }
	;

/*************************** STATEMENTS *******************************/
statement
	: labeled_statement
	| compound_statement
	| expression_statement
	| selection_statement
	| iteration_statement
	| jump_statement
	;

labeled_statement
	: identifier_or_typedef_name ':' statement   { DELETE_NODE( $1 ); }
	| CASE_TOK constant_expression ':' statement
	| DEFAULT_TOK ':' statement
	;

compound_statement
	: '{' '}'
	| '{' declaration_list '}'
	| '{' statement_list '}'
	| '{' declaration_list statement_list '}'
	;

declaration_list
	: declaration
	| declaration_list declaration
	;

statement_list
	: statement
	| statement_list statement
	;

expression_statement
	: comma_expression_opt ';'
	;

selection_statement
	: IF_TOK '(' comma_expression ')' statement
	| IF_TOK '(' comma_expression ')' statement ELSE_TOK statement
	| SWITCH_TOK '(' comma_expression ')' statement
	;

iteration_statement
	: WHILE_TOK '(' comma_expression ')' statement
	| DO_TOK statement WHILE_TOK '(' comma_expression ')' ';'
	| FOR_TOK '(' comma_expression_opt ';' comma_expression_opt ';' comma_expression_opt ')' statement
	;

jump_statement
	: GOTO_TOK identifier_or_typedef_name ';' { DELETE_NODE( $2 ); }
	| CONTINUE_TOK ';'
	| BREAK_TOK ';'
	| RETURN_TOK comma_expression_opt ';'
	;


/***************************** EXTERNAL DEFINITIONS *****************************/

source_file
	: /* empty file */
	| translation_unit
	;

translation_unit
	: external_definition
	| translation_unit external_definition
	;

external_definition
	: function_definition
	| declaration
	;

function_definition
	:                            identifier_declarator { BEGIN_LOCAL; }
	                             compound_statement    { END_LOCAL; decl_delete( EX_DECL( $1 ) ); }
	| declaration_specifier      identifier_declarator { BEGIN_LOCAL; }
	                             compound_statement    { END_LOCAL; decl_delete( EX_DECL( $2 ) ); }
	| type_specifier             identifier_declarator { BEGIN_LOCAL; }
	                             compound_statement    { END_LOCAL; decl_delete( EX_DECL( $2 ) ); }
	| declaration_qualifier_list identifier_declarator { BEGIN_LOCAL; }
	                             compound_statement    { END_LOCAL; decl_delete( EX_DECL( $2 ) ); }
	| type_qualifier_list        identifier_declarator { BEGIN_LOCAL; }
	                             compound_statement    { END_LOCAL; decl_delete( EX_DECL( $2 ) ); }

	|                            old_function_declarator { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| declaration_specifier      old_function_declarator { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| type_specifier             old_function_declarator { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| declaration_qualifier_list old_function_declarator { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| type_qualifier_list        old_function_declarator { BEGIN_LOCAL; } compound_statement { END_LOCAL; }

	|                            old_function_declarator declaration_list { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| declaration_specifier      old_function_declarator declaration_list { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| type_specifier             old_function_declarator declaration_list { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| declaration_qualifier_list old_function_declarator declaration_list { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	| type_qualifier_list        old_function_declarator declaration_list { BEGIN_LOCAL; } compound_statement { END_LOCAL; }
	;

declarator
	: identifier_declarator { $$ = $1; }
	| typedef_declarator    { $$ = $1; }
	;

typedef_declarator
	: paren_typedef_declarator     { $$ = $1; }   /* would be ambiguous as parameter*/
	| parameter_typedef_declarator { $$ = $1; }   /* not ambiguous as param*/
	;

parameter_typedef_declarator
	: TYPE_NAME
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = decl_new( ((Typedef *) $1.ptr)->pDecl->identifier, 0 );
	      LL_unshift( PSTATE->declaratorList, $$ );
	      CT_DEBUG( PARSER, ("unshifting declarator \"%s\" (0x%08X) (count=%d)",
	                         $$->identifier, $$, LL_count(PSTATE->declaratorList)) );
	    }
	  }
	| TYPE_NAME postfixing_abstract_declarator
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = decl_new( ((Typedef *) $1.ptr)->pDecl->identifier, 0 );
	      if( $2 )
	        LL_delete( LL_splice( $$->array, 0, 0, EX_ARRAY( $2 ) ) );
	      LL_unshift( PSTATE->declaratorList, $$ );
	      CT_DEBUG( PARSER, ("unshifting declarator \"%s\" (0x%08X) (count=%d)",
	                         $$->identifier, $$, LL_count(PSTATE->declaratorList)) );
	    }
	  }
	| clean_typedef_declarator { $$ = $1; }
	;

    /*  The  following have at least one '*'. There is no (redundant)
    '(' between the '*' and the TYPE_NAME. */

clean_typedef_declarator
	: clean_postfix_typedef_declarator { $$ = $1; }
	| '*' parameter_typedef_declarator
	  {
	    if( $2 )
	      $2->pointer_flag = 1;
	    $$ = $2;
	  }
	| '*' type_qualifier_list parameter_typedef_declarator
	  {
	    if( $3 )
	      $3->pointer_flag = 1;
	    $$ = $3;
	  }
	;

clean_postfix_typedef_declarator
	: '(' clean_typedef_declarator ')' { $$ = $2; }
	| '(' clean_typedef_declarator ')' postfixing_abstract_declarator
	  {
	    POSTFIX_DECL( $2, $4 );
	    $$ = $2;
	  }
	;

    /* The following have a redundant '(' placed immediately  to  the
    left of the TYPE_NAME */

paren_typedef_declarator
	: paren_postfix_typedef_declarator { $$ = $1; }
	| '*' '(' simple_paren_typedef_declarator ')'
	  {
	    if( $3 )
	      $3->pointer_flag = 1;
	    $$ = $3;
	  }
	| '*' type_qualifier_list '(' simple_paren_typedef_declarator ')'
	  {
	    if( $4 )
	      $4->pointer_flag = 1;
	    $$ = $4;
	  }
	| '*' paren_typedef_declarator
	  {
	    if( $2 )
	      $2->pointer_flag = 1;
	    $$ = $2;
	  }
	| '*' type_qualifier_list paren_typedef_declarator
	  {
	    if( $3 )
	      $3->pointer_flag = 1;
	    $$ = $3;
	  }
	;

paren_postfix_typedef_declarator
	: '(' paren_typedef_declarator ')' { $$ = $2; }
	| '(' simple_paren_typedef_declarator postfixing_abstract_declarator ')'
	  {
	    POSTFIX_DECL( $2, $3 );
	    $$ = $2;
	  }
	| '(' paren_typedef_declarator ')' postfixing_abstract_declarator
	  {
	    POSTFIX_DECL( $2, $4 );
	    $$ = $2;
	  }
	;

simple_paren_typedef_declarator
	: TYPE_NAME
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = decl_new( ((Typedef *) $1.ptr)->pDecl->identifier, 0 );
	      LL_unshift( PSTATE->declaratorList, $$ );
	      CT_DEBUG( PARSER, ("unshifting declarator \"%s\" (0x%08X) (count=%d)",
	                         $$->identifier, $$, LL_count(PSTATE->declaratorList)) );
	    }
	  }
	| '(' simple_paren_typedef_declarator ')' { $$ = $2; }
	;

identifier_declarator
	: unary_identifier_declarator { $$ = $1; }
	| paren_identifier_declarator { $$ = $1; }
	;

unary_identifier_declarator
	: postfix_identifier_declarator { $$ = $1; }
	| '*' identifier_declarator
	  {
	    if( $2 )
	      $2->pointer_flag = 1;
	    $$ = $2;
	  }
	| '*' type_qualifier_list identifier_declarator
	  {
	    if( $3 )
	      $3->pointer_flag = 1;
	    $$ = $3;
	  }
	;

postfix_identifier_declarator
	: paren_identifier_declarator postfixing_abstract_declarator
	  {
	    POSTFIX_DECL( $1, $2 );
	    $$ = $1;
	  }
	| '(' unary_identifier_declarator ')' { $$ = $2; }
	| '(' unary_identifier_declarator ')' postfixing_abstract_declarator
	  {
	    POSTFIX_DECL( $2, $4 );
	    $$ = $2;
	  }
	;

paren_identifier_declarator
	: IDENTIFIER
	  {
	    if( $1 ) {
	      $$ = decl_new( $1->key, $1->keylen );
	      HN_delete( EX_NODE( $1 ) );
	      LL_unshift( PSTATE->declaratorList, $$ );
	      CT_DEBUG( PARSER, ("unshifting declarator \"%s\" (0x%08X) (count=%d)",
	                         $$->identifier, $$, LL_count(PSTATE->declaratorList)) );
	    }
	    else {
	      $$ = NULL;
	    }
	  }
	| '(' paren_identifier_declarator ')' { $$ = $2; }
	;

old_function_declarator
	: postfix_old_function_declarator {}
	| '*' old_function_declarator {}
	| '*' type_qualifier_list old_function_declarator {}
	;

postfix_old_function_declarator
	: paren_identifier_declarator '(' identifier_list ')'
	  {
	    if( $1 )
	      decl_delete( EX_DECL( $1 ) );
	  }
	| '(' old_function_declarator ')' {}
	| '(' old_function_declarator ')' postfixing_abstract_declarator
	  {
	    if( $4 )
	      LL_destroy( EX_ARRAY( $4 ), (LLDestroyFunc) value_delete );
	  }
	;

abstract_declarator
	: unary_abstract_declarator { $$ = $1; }
	| postfix_abstract_declarator { $$ = $1; }
	| postfixing_abstract_declarator
	  {
	    $$.pointer_flag  = 0;
	    $$.multiplicator = 1;
	    if( $1 ) {
	      Value *pValue;
	      LL_foreach( pValue, $1 )
	        $$.multiplicator *= pValue->iv;
	      LL_destroy( EX_ARRAY( $1 ), (LLDestroyFunc) value_delete );
	    }
	  }
	;

postfixing_abstract_declarator
	: array_abstract_declarator   { $$ = $1;   }
	| '(' ')'                     { $$ = NULL; }
	| '(' parameter_type_list ')' { $$ = NULL; }
	;

array_abstract_declarator
	: '[' ']' { $$ = NULL; }
	| '[' assignment_expression ']'
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = LL_new();
	      LL_unshift( PSTATE->arrayList, $$ );
	      CT_DEBUG( PARSER, ("unshifting array (0x%08X) (count=%d)",
	                         $$, LL_count(PSTATE->arrayList)) );
	      LL_push( $$, value_new( $2.iv, $2.flags ) );
	      CT_DEBUG( PARSER, ("array dimension => %d", $2) );
	    }
	  }
	| '[' '*' ']'
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      $$ = LL_new();
	      LL_unshift( PSTATE->arrayList, $$ );
	      CT_DEBUG( PARSER, ("unshifting array (0x%08X) (count=%d)",
	                         $$, LL_count(PSTATE->arrayList)) );
	      LL_push( $$, value_new( 0, 0 ) );
	      CT_DEBUG( PARSER, ("array dimension => *") );
	    }
	  }
	| array_abstract_declarator '[' assignment_expression ']'
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      if( $1 ) {
                $$ = $1;
	      }
	      else {
                $$ = LL_new();
	        LL_unshift( PSTATE->arrayList, $$ );
	        CT_DEBUG( PARSER, ("unshifting array (0x%08X) (count=%d)",
	                           $$, LL_count(PSTATE->arrayList)) );
	      }
	      LL_push( $$, value_new( $3.iv, $3.flags ) );
	      CT_DEBUG( PARSER, ("array dimension => %d", $3) );
	    }
	  }
	| array_abstract_declarator '[' '*' ']'
	  {
	    if( IS_LOCAL ) {
	      $$ = NULL;
	    }
	    else {
	      if( $1 ) {
                $$ = $1;
	      }
	      else {
                $$ = LL_new();
	        LL_unshift( PSTATE->arrayList, $$ );
	        CT_DEBUG( PARSER, ("unshifting array (0x%08X) (count=%d)",
	                           $$, LL_count(PSTATE->arrayList)) );
	      }
	      LL_push( $$, value_new( 0, 0 ) );
	      CT_DEBUG( PARSER, ("array dimension => *" ) );
	    }
	  }
	;

unary_abstract_declarator
	: '*'
	  {
	    $$.pointer_flag = 1;
	    $$.multiplicator = 1;
	  }
	| '*' type_qualifier_list
	  {
	    $$.pointer_flag = 1;
	    $$.multiplicator = 1;
	  }
	| '*' abstract_declarator
	  {
	    $2.pointer_flag = 1;
	    $$ = $2;
	  }
	| '*' type_qualifier_list abstract_declarator
	  {
	    $3.pointer_flag = 1;
	    $$ = $3;
	  }
	;

postfix_abstract_declarator
	: '(' unary_abstract_declarator ')' { $$ = $2; }
	| '(' postfix_abstract_declarator ')' { $$ = $2; }
	| '(' postfixing_abstract_declarator ')'
	  {
	    $$.pointer_flag  = 0;
	    $$.multiplicator = 1;
	    if( $2 ) {
	      Value *pValue;
	      LL_foreach( pValue, $2 )
	        $$.multiplicator *= pValue->iv;
	      LL_destroy( EX_ARRAY( $2 ), (LLDestroyFunc) value_delete );
	    }
	  }
	| '(' unary_abstract_declarator ')' postfixing_abstract_declarator
	  {
	    $$ = $2;
	    if( $4 )
	      LL_destroy( EX_ARRAY( $4 ), (LLDestroyFunc) value_delete );
	  }
	;

%%


/*===== STATIC FUNCTIONS =====================================================*/

/*******************************************************************************
*
*   ROUTINE: c_lex
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: C lexer.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int c_lex( void *pYYLVAL, ParserState *pState )
{
  YYSTYPE *plval = (YYSTYPE *) pYYLVAL;
  int rval, token;
  struct lexer_state *pLexer = pState->pLexer;

  CT_DEBUG( CLEXER, ("parser.y::c_lex()") );

  while( (rval = lex( pLexer )) < CPPERR_EOF ) {
    if( rval ) {
      CT_DEBUG( CLEXER, ("lex() returned %d", rval) );
      continue;
    }

    token = pLexer->ctok->type;

    switch( token ) {
      case NONE:
        CT_DEBUG( CLEXER, ("token-type => NONE") );
        break;

      case COMMENT:
        CT_DEBUG( CLEXER, ("token-type => COMMENT => [%s]", pLexer->ctok->name) );
        break;

      case NEWLINE:
        CT_DEBUG( CLEXER, ("token-type => NEWLINE") );
        break;

      case BUNCH:
        CT_DEBUG( CLEXER, ("token-type => BUNCH => [%s]", pLexer->ctok->name) );
        break;

      case CONTEXT:
        CT_DEBUG( CLEXER, ("token-type => CONTEXT => [%s]", pLexer->ctok->name) );
        {
          FileInfo *pFI;
          size_t len = strlen( pLexer->ctok->name );

          CT_DEBUG( CLEXER, ("new context: file '%s', line %ld",
                             pLexer->ctok->name, pLexer->ctok->line) );

          pFI = HT_get( pState->pCPI->htFiles, pLexer->ctok->name, len, 0 );

          if( pFI == NULL ) {
            pFI = fileinfo_new( pLexer->input, pLexer->ctok->name, len );
	    HT_store( pState->pCPI->htFiles, pLexer->ctok->name, len, 0, pFI );
          }

          pState->pFI = pFI;
        }
        break;

      case NUMBER:
        CT_DEBUG( CLEXER, ("token-type => NUMBER => [%s]", pLexer->ctok->name) );
        plval->value.iv = strtol( pLexer->ctok->name, NULL, 0 );
        plval->value.flags = 0;
        CT_DEBUG( CLEXER, ("constant: %s -> %d", pLexer->ctok->name, plval->value.iv) );
        return CONSTANT;

      case STRING:
        CT_DEBUG( CLEXER, ("token-type => STRING => [%s]", pLexer->ctok->name) );
        plval->value.iv = string_size( pLexer->ctok->name );
        plval->value.flags = 0;
        CT_DEBUG( CLEXER, ("string literal: %s -> %d", pLexer->ctok->name, plval->value.iv) );
        return STRING_LITERAL;

      case CHAR:
        CT_DEBUG( CLEXER, ("token-type => CHAR => [%s]", pLexer->ctok->name) );
        plval->value.iv = get_char_value( pLexer->ctok->name );
        plval->value.flags = 0;
        CT_DEBUG( CLEXER, ("constant: %s -> %d", pLexer->ctok->name, plval->value.iv) );
        return CONSTANT;

      case PRAGMA:
        CT_DEBUG( CLEXER, ("token-type => PRAGMA") );
        CT_DEBUG( CLEXER, ("line %ld: <#pragma>", pLexer->line) );

        pState->pragma.str = pLexer->ctok->name;
        pragma_parse( &pState->pragma );

        CT_DEBUG( CLEXER, ("current packing: %d\n", pState->pragma.pack.current) );

        break;

      case NAME:
        CT_DEBUG( CLEXER, ("token-type => NAME => [%s]", pLexer->ctok->name) );
        {
          char *tokstr = pLexer->ctok->name;
          const CKeywordToken *ckt;

#include "t_parser.c"

          unknown:

          if( (ckt = HT_get( pState->pCPC->keyword_map, tokstr, 0, 0 )) != NULL ) {
            if( ckt->token == SKIP_TOK ) {
              CT_DEBUG( CLEXER, ("skipping token '%s' in line %ld", tokstr, pLexer->line) );
              break;
            }

            return ckt->token;
          }

          return check_type( pYYLVAL, pState, tokstr );
        }

      default:
        CT_DEBUG( CLEXER, ("token-type => %d", token) );
        if( (rval = tokentab[token]) != 0 ) {
          return rval;
        }
        else {
          CT_DEBUG( CLEXER, ("unhandled token in line %ld: <%2d>", pLexer->line, token) );
        }
        break;
    }
  }

  CT_DEBUG( CLEXER, ("EOF!") );

  return 0;
}

/*******************************************************************************
*
*   ROUTINE: ex_object
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#ifdef CTYPE_DEBUGGING
static void *ex_object( char *type, LinkedList list, void *object )
#else
static void *ex_object( LinkedList list, void *object )
#endif
{
  void *obj;
  int   item = 0;

  CT_DEBUG( PARSER, ("ex_object( type=\"%s\", list=0x%08X, object=0x%08X )",
                     type, list, object) );

  LL_foreach( obj, list ) {
    if( obj == object )
      break;
    item++;
  }

  if( obj != object ) {
    CT_DEBUG( PARSER, ("%s (0x%08X) not found in ex_object()", type, object, item) );
    return object;
  }

  CT_DEBUG( PARSER, ("%s found (item=%d) in ex_object()", type, item) );

  return LL_extract( list, item );
}

/*******************************************************************************
*
*   ROUTINE: parser_error
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void parser_error( ParserState *pState, char *msg )
{
  FormatError( pState->pCPI, "%s, line %d: %s",
               pState->pFI ? pState->pFI->name : "[unknown]",
               pState->pLexer->ctok->line, msg );
}

/*******************************************************************************
*
*   ROUTINE: get_char_value
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int get_char_value( char *s )
{
  while( *s && *s != '\'' ) s++;

  if( *++s != '\\' )
    return (int)*s;

  switch( *++s ) {
    case '0' :
    case '1' :
    case '2' :
    case '3' : return (int) strtol( s, NULL, 8 );
    case 'a' : return (int) '\a';
    case 'b' : return (int) '\b';
    case 'f' : return (int) '\f';
    case 'h' : return (int) strtol( ++s, NULL, 16 );
    case 'n' : return (int) '\n';
    case 'r' : return (int) '\r';
    case 't' : return (int) '\t';
    case 'v' : return (int) '\v';

    default:   return (int) *s;
  }
}

/*******************************************************************************
*
*   ROUTINE: string_size
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int string_size( char *s )
{
  int size, count;

  while( *s && *s != '\"' ) s++;

  for( s++, size=0; *s; size++ ) {
    if( *s == '\"' )
      break;

    if( *s++ != '\\' )
      continue;

    if( *s == 'x' ) {
      count = 0;
      do s++; while( count++ < 2
                     && ( (*s >= '0' && *s <= '9')
                       || (*s >= 'a' && *s <= 'f')
                       || (*s >= 'A' && *s <= 'F') ) );
      continue;
    }

    if( *s >= '0' && *s <= '7' ) {
      count = 0;
      do s++; while( count++ < 2 && *s >= '0' && *s <= '7' );
    }
    else
      s++;
  }

  return size;
}

/*******************************************************************************
*
*   ROUTINE: check_type
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int check_type( void *pYYLVAL, ParserState *pState, char *s )
{
  YYSTYPE    *plval = (YYSTYPE *) pYYLVAL;
  Enumerator *pEnum;
  Typedef    *pTypedef;
  HashSum     hash;
  int         len;

  CT_DEBUG( CLEXER, ("check_type( \"%s\" )", s) );

  HASH_STR_LEN( hash, s, len );

  pEnum = HT_get( pState->pCPI->htEnumerators, s, len, hash );

  if( pEnum ) {
    CT_DEBUG( CLEXER, ("enum found!") );
    plval->value = pEnum->value;
    return CONSTANT;
  }

  pTypedef = HT_get( pState->pCPI->htTypedefs, s, len, hash );

  if( pTypedef ) {
    CT_DEBUG( CLEXER, ("typedef found!") );
    plval->tspec.tflags = T_TYPE;
    plval->tspec.ptr    = pTypedef;
    return TYPE_NAME;
  }

  if( pState->flags & F_LOCAL ) {
    plval->identifier = NULL;
  }
  else {
    plval->identifier = HN_new( s, len, hash );

    LL_unshift( pState->nodeList, plval->identifier );
    CT_DEBUG( CLEXER, ("unshifting identifier \"%s\" (0x%08X) (count=%d)",
                       plval->identifier->key, plval->identifier,
                       LL_count(pState->nodeList)) );
  }

  return IDENTIFIER;
}


/*===== FUNCTIONS ============================================================*/

/*******************************************************************************
*
*   ROUTINE: get_c_keyword_token
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Create a new C parser.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

const CKeywordToken *get_c_keyword_token( const char *name )
{
#include "t_ckeytok.c"
unknown:
  return NULL;
}

/*******************************************************************************
*
*   ROUTINE: get_skip_token
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Create a new C parser.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

const CKeywordToken *get_skip_token( void )
{
  static const CKeywordToken ckt = { SKIP_TOK, NULL };
  return &ckt;
}

/*******************************************************************************
*
*   ROUTINE: c_parser_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Create a new C parser.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

ParserState *c_parser_new( const CParseConfig *pCPC, CParseInfo *pCPI,
                           struct lexer_state *pLexer )
{
  ParserState *pState;

#ifdef CTYPE_DEBUGGING
#ifdef YYDEBUG
  extern int pragma_debug;
  c_debug = pragma_debug = DEBUG_FLAG( YACC ) ? 1 : 0;
#endif
#endif

  if( pCPC == NULL || pCPI == NULL || pLexer == NULL )
    return NULL;

  pState = (ParserState *) Alloc( sizeof( ParserState ) );

  pState->pCPI                = pCPI;
  pState->pCPC                = pCPC;
  pState->pLexer              = pLexer;

  pState->flags               = 0;
  pState->pFI                 = NULL;
  pState->curEnumList         = NULL;

  pState->nodeList            = LL_new();
  pState->declaratorList      = LL_new();
  pState->arrayList           = LL_new();
  pState->structDeclList      = LL_new();
  pState->structDeclListsList = LL_new();

  pragma_init( &pState->pragma );
 
  return pState;
}

/*******************************************************************************
*
*   ROUTINE: c_parser_run
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Run the C parser.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

int c_parser_run( ParserState *pState )
{
  return c_parse( (void *) pState );
}

/*******************************************************************************
*
*   ROUTINE: c_parser_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Delete a C parser object.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

void c_parser_delete( ParserState *pState )
{
  LinkedList list;

#ifdef CTYPE_DEBUGGING
  int count;
#endif

  if( pState == NULL )
    return;

  /*-----------------------*/
  /* Cleanup pragma parser */
  /*-----------------------*/

  pragma_free( &pState->pragma );

  /*---------------------*/
  /* Cleanup Enumerators */
  /*---------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( PARSER ) ) {
    CT_DEBUG( PARSER, ("cleanup enumerator(s)") );
    if( pState->curEnumList && (count = LL_count( pState->curEnumList )) > 0 )
      CT_DEBUG( PARSER, ("%d enumerator(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_destroy( pState->curEnumList, (LLDestroyFunc) enum_delete );

  /*---------------*/
  /* Cleanup Nodes */
  /*---------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( PARSER ) ) {
    CT_DEBUG( PARSER, ("cleanup node(s)") );
    if( (count = LL_count( pState->nodeList )) > 0 ) {
      HashNode hn;
      CT_DEBUG( PARSER, ("%d node(s) still in memory, cleaning up...", count) );
      LL_foreach( hn, pState->nodeList )
        CT_DEBUG( PARSER, ("[%s]", hn->key) );
    }
  }
#endif

  LL_destroy( pState->nodeList, (LLDestroyFunc) HN_delete );

  /*---------------------*/
  /* Cleanup Declarators */
  /*---------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( PARSER ) ) {
    CT_DEBUG( PARSER, ("cleanup declarator(s)") );
    if( (count = LL_count( pState->declaratorList )) > 0 )
      CT_DEBUG( PARSER, ("%d declarator(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_destroy( pState->declaratorList, (LLDestroyFunc) decl_delete );

  /*----------------*/
  /* Cleanup Arrays */
  /*----------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( PARSER ) ) {
    Value *pVal;
    CT_DEBUG( PARSER, ("cleanup array(s)") );
    if( (count = LL_count( pState->arrayList )) > 0 ) {
      CT_DEBUG( PARSER, ("%d array(s) still in memory, cleaning up...", count) );
      LL_foreach( list, pState->arrayList ) {
        CT_DEBUG( PARSER, ("[ARRAY=0x%08X]", list) );
        LL_foreach( pVal, list )
          CT_DEBUG( PARSER, ("[value=%d,flags=0x%08X]", pVal->iv, pVal->flags) );
      }
    }
  }
#endif

  LL_foreach( list, pState->arrayList )
    LL_destroy( list, (LLDestroyFunc) value_delete );

  LL_destroy( pState->arrayList, NULL );

  /*----------------------------*/
  /* Cleanup Struct Declarators */
  /*----------------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( PARSER ) ) {
    CT_DEBUG( PARSER, ("cleanup struct declarator(s)") );
    if( (count = LL_count( pState->structDeclList )) > 0 )
      CT_DEBUG( PARSER, ("%d struct declarator(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_destroy( pState->structDeclList, (LLDestroyFunc) structdecl_delete );

  /*---------------------------------*/
  /* Cleanup Struct Declarator Lists */
  /*---------------------------------*/

#ifdef CTYPE_DEBUGGING
  if( DEBUG_FLAG( PARSER ) ) {
    CT_DEBUG( PARSER, ("cleanup struct declarator list(s)") );
    if( (count = LL_count( pState->structDeclListsList )) > 0 )
      CT_DEBUG( PARSER, ("%d struct declarator list(s) still in memory, cleaning up...", count) );
  }
#endif

  LL_foreach( list, pState->structDeclListsList )
    LL_destroy( list, (LLDestroyFunc) structdecl_delete );

  LL_destroy( pState->structDeclListsList, NULL );

  Free( pState );
}
