%{
# include "types.h"    
typedef char* yystype_def;
#   define YYSTYPE yystype_def
%}

%token BAD_TOKEN
%token INTEGER_CONSTANT CHARACTER_CONSTANT FLOATING_CONSTANT
       ENUMERATION_CONSTANT IDENTIFIER STRING

%token SIZEOF
%token PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token XOR_ASSIGN OR_ASSIGN TYPEDEF_NAME

%token TYPEDEF EXTERN STATIC AUTO REGISTER
%token CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE CONST VOLATILE VOID
%token STRUCT UNION ENUM ELIPSIS

%token CASE DEFAULT IF SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%left  THEN
%left  ELSE

%start translation_unit
%%

/****************************************************************
 ********* Name-Space and scanner-feedback productions **********
 ****************************************************************/

/* The occurance of a type_specifier in the input turns off
 * scanner-recognition of typedef-names as such, so that they can
 * be re-defined within a declarator-list. The switch is called
 * "name_space_types".
 *
 * The call to lex_sync() assures that the switch gets toggled after
 * the next token is pre-fetched as a lookahead.
 */

NS_ntd  : { lex_sync(); ntd(); }
        ;

/* Once the declarators (if any) are parsed, the scanner is returned
 * to the state where typedef-names are recognized.
 */
NS_td   : { lex_sync(); td(); }
        ;

/* NS_scope_push creates a new scope in the id/typedef/enum-const
 * name-space. New levels are created by function-declarators
 * and are created and destroyed by compound-statements.
 * Thus, every occurance of a function-declarator must be
 * followed, at the end of the scope of that declarator,
 * by an NS_scope_pop.
 */
NS_scope_push  : { scope_push(); td(); }
               ;
NS_scope_pop : { scope_pop(); }
        ;

/* NS_struct_push creates a new name-space for a struct or union
 * NS_struct_pop finishes one.
 */
NS_struct_push : { struct_push(); td(); }
;

NS_struct_pop:   { struct_pop(); }
;

NS_id: { new_declaration(name_space_decl); }
;

/* Begin a new declaration of a parameter */
NS_new_parm: { new_declaration(name_space_decl); }
;

/* Remember that declarators while define typedef-names. */
NS_is_typedef:  { set_typedef(); }
;

/* Finish a direct-declarator */
NS_direct_decl:           { direct_declarator(); }
;

/* Finish a pointer-declarator */
NS_ptr_decl: { pointer_declarator(); }
;

/* The scanner must be aware of the name-space which
 * differentiates typedef-names from identifiers. But the
 * distinction is only useful within limited scopes. In other
 * scopes the distinction may be invalid, or in cases where
 * typedef-names are not legal, the semantic-analysis phase
 * may be able to generate a better error message if the parser
 * does not flag a syntax error. We therefore use the following
 * production...
 */
 
identifier
        : NS_ntd TYPEDEF_NAME NS_td
        | IDENTIFIER
        | ENUMERATION_CONSTANT
        ;
 
/************************************************************
 *****************  The C grammar per se. *******************
 ************************************************************/

/* 
 * What follows is based on the gammar in _The C Programming Language_,
 * Kernighan & Ritchie, Prentice Hall 1988. See the README file.
 */

translation_unit
	: external_declaration
	| translation_unit external_declaration
	;

external_declaration
	: NS_id function_definition
	| NS_id declaration
        | NS_id untyped_declaration
	;

function_definition
	: function_declarator
              compound_statement
          NS_scope_pop

	| function_declarator
            declaration_list
            compound_statement
          NS_scope_pop

	| declaration_specifiers
          function_declarator NS_td
            compound_statement
          NS_scope_pop

	| declaration_specifiers
          function_declarator NS_td
             declaration_list
             compound_statement
          NS_scope_pop
	;

declaration
	: declaration_specifiers NS_td ';'
	| declaration_specifiers init_declarator_list NS_td ';'
	;

untyped_declaration
        : init_declarator_list ';'
        ;

declaration_list
	: declaration
	| declaration_list declaration
	;

declaration_specifiers
	: storage_class_specifier
	| storage_class_specifier declaration_specifiers
	| type_specifier
	| type_specifier declaration_specifiers
	| type_qualifier
	| type_qualifier declaration_specifiers
	;

storage_class_specifier
	: NS_is_typedef TYPEDEF
        | EXTERN
        | STATIC
        | AUTO
        | REGISTER
	;

/* Once an actual type-specifier is seen, it acts as a "trigger" to
 * turn typedef-recognition off while scanning declarators, etc.
 */
type_specifier
        : NS_ntd actual_type_specifier
        | type_adjective
        ;

actual_type_specifier
	: VOID
        | CHAR
        | INT
	| FLOAT
        | DOUBLE
	| TYPEDEF_NAME
	| struct_or_union_specifier
	| enum_specifier
	;

type_adjective
        : SHORT
        | LONG
        | SIGNED
        | UNSIGNED
        ;

type_qualifier
	: CONST 
        | VOLATILE
	;

struct_or_union_specifier
	: struct_or_union NS_struct_push
           '{' struct_declaration_list NS_struct_pop '}'
	| struct_or_union identifier NS_struct_push
            '{' struct_declaration_list NS_struct_pop '}'
	| struct_or_union identifier
	;

struct_or_union
	: STRUCT
	| UNION
	;

struct_declaration_list
	: struct_declaration
	| struct_declaration_list struct_declaration
	;

init_declarator_list
	: init_declarator
	| init_declarator_list ',' init_declarator
	;

init_declarator
	: declarator
	| declarator NS_td '=' initializer NS_ntd
	;

struct_declaration
	: { new_declaration(struct_decl); }
          specifier_qualifier_list struct_declarator_list NS_td ';'
	;

specifier_qualifier_list
	: type_specifier
	| type_specifier specifier_qualifier_list
	| type_qualifier
	| type_qualifier specifier_qualifier_list
	;

struct_declarator_list
	: struct_declarator
	| struct_declarator_list ',' struct_declarator
	;

struct_declarator
	: declarator
	| ':' constant_expression
	| declarator ':' constant_expression
	;

enum_specifier
	: ENUM '{' enumerator_list '}'
	| ENUM identifier '{' enumerator_list '}'
	| ENUM identifier
	;

enumerator_list
	: enumerator
	| enumerator_list ',' enumerator
	;

enumerator
	: IDENTIFIER
	| IDENTIFIER '=' constant_expression
	;

declarator
	: direct_declarator  NS_direct_decl
	| pointer direct_declarator NS_ptr_decl
	;

direct_declarator
	: IDENTIFIER           { declarator_id($$); }
	| '(' declarator ')'
	| direct_declarator '[' ']'
	| direct_declarator '[' constant_expression ']'
        | direct_declarator NS_scope_push '(' parameter_type_list ')'
                  NS_scope_pop
	| direct_declarator NS_scope_push '(' ')' NS_scope_pop 
	| direct_declarator NS_scope_push '(' identifier_list ')' NS_scope_pop
        ;

function_declarator
        : direct_function_declarator NS_direct_decl
        | pointer direct_function_declarator NS_ptr_decl
        ;

direct_function_declarator
        : direct_declarator NS_scope_push '(' parameter_type_list ')'
	| direct_declarator NS_scope_push '(' ')'
	| direct_declarator NS_scope_push '(' identifier_list ')'
        ;

pointer
	: '*'
	| '*' type_qualifier_list
	| '*' pointer
	| '*' type_qualifier_list pointer
	;

type_qualifier_list
        : type_qualifier
        | type_qualifier_list type_qualifier
        ;

parameter_type_list
	: parameter_list
	| parameter_list ',' ELIPSIS
	;

parameter_list
	: parameter_declaration
	| parameter_list ',' parameter_declaration
	;

parameter_declaration
	:  NS_new_parm declaration_specifiers declarator NS_td
	|  NS_new_parm declaration_specifiers NS_td
	|  NS_new_parm declaration_specifiers abstract_declarator NS_td
	;

identifier_list
	: IDENTIFIER
	| identifier_list ',' IDENTIFIER
	;

initializer
	: assignment_expression
	| '{' initializer_list '}'
	| '{' initializer_list ',' '}'
	;

initializer_list
	: initializer
	| initializer_list ',' initializer
	;

type_name
	: specifier_qualifier_list NS_td
	| specifier_qualifier_list NS_td abstract_declarator
	;

abstract_declarator
	: pointer
	| direct_abstract_declarator
	| pointer direct_abstract_declarator
	;

direct_abstract_declarator
	: '(' abstract_declarator ')'
	| '[' ']'
	| '[' constant_expression ']'
	| direct_abstract_declarator '[' ']'
	| direct_abstract_declarator '[' constant_expression ']'
	| '(' ')'
	| '(' parameter_type_list ')'
	| direct_abstract_declarator '(' ')'
	| direct_abstract_declarator '(' parameter_type_list ')'
	;

statement
	: labeled_statement
	| compound_statement
	| expression_statement
	| selection_statement
	| iteration_statement
	| jump_statement
	;

labeled_statement
	: identifier ':' statement
	| CASE constant_expression ':' statement
	| DEFAULT ':' statement
	;

expression_statement
	: ';'
	| expression ';'
	;

compound_statement
	: NS_scope_push '{' NS_scope_pop '}'
	| NS_scope_push '{' statement_list NS_scope_pop '}'
	| NS_scope_push '{' declaration_list NS_scope_pop '}'
	| NS_scope_push '{' declaration_list statement_list NS_scope_pop '}'
	;

statement_list
	: statement
	| statement_list statement
	;

selection_statement
	: IF '(' expression ')' statement %prec THEN
	| IF '(' expression ')' statement ELSE statement
	| SWITCH '(' expression ')' statement
	;

iteration_statement
	: WHILE '(' expression ')' statement
	| DO statement WHILE '(' expression ')' ';'
	| FOR '(' ';' ';' ')' statement
	| FOR '(' ';' ';' expression ')' statement
	| FOR '(' ';' expression ';' ')' statement
	| FOR '(' ';' expression ';' expression ')' statement
	| FOR '(' expression ';' ';' ')' statement
	| FOR '(' expression ';' ';' expression ')' statement
	| FOR '(' expression ';' expression ';' ')' statement
	| FOR '(' expression ';' expression ';' expression ')' statement
	;

jump_statement
	: GOTO identifier ';'
	| CONTINUE ';'
	| BREAK ';'
	| RETURN ';'
	| RETURN expression ';'
	;

expression
	: assignment_expression
	| expression ',' assignment_expression
	;


assignment_expression
	: conditional_expression
	| unary_expression assignment_operator assignment_expression
	;

assignment_operator
	: '=' | MUL_ASSIGN | DIV_ASSIGN | MOD_ASSIGN | ADD_ASSIGN | SUB_ASSIGN
	| LEFT_ASSIGN | RIGHT_ASSIGN | AND_ASSIGN | XOR_ASSIGN | OR_ASSIGN
	;


conditional_expression
	: logical_or_expression
	| logical_or_expression '?' expression ':' conditional_expression
	;


constant_expression
	: conditional_expression
	;


logical_or_expression
	: logical_and_expression
	| logical_or_expression OR_OP logical_and_expression
	;

logical_and_expression
	: inclusive_or_expression
	| logical_and_expression AND_OP inclusive_or_expression
	;

inclusive_or_expression
	: exclusive_or_expression
	| inclusive_or_expression '|' exclusive_or_expression
	;

exclusive_or_expression
	: and_expression
	| exclusive_or_expression '^' and_expression
	;

and_expression
	: equality_expression
	| and_expression '&' equality_expression
	;

equality_expression
	: relational_expression
	| equality_expression EQ_OP relational_expression
	| equality_expression NE_OP relational_expression
	;

relational_expression
	: shift_expression
	| relational_expression '<' shift_expression
	| relational_expression '>' shift_expression
	| relational_expression LE_OP shift_expression
	| relational_expression GE_OP shift_expression
	;

shift_expression
	: additive_expression
	| shift_expression LEFT_OP additive_expression
	| shift_expression RIGHT_OP additive_expression
	;

additive_expression
	: multiplicative_expression
	| additive_expression '+' multiplicative_expression
	| additive_expression '-' multiplicative_expression
	;

multiplicative_expression
	: cast_expression
	| multiplicative_expression '*' cast_expression
	| multiplicative_expression '/' cast_expression
	| multiplicative_expression '%' cast_expression
	;

cast_expression
	: unary_expression
	| '(' type_name ')' cast_expression
	;


unary_expression
	: postfix_expression
	| INC_OP unary_expression
	| DEC_OP unary_expression
	| unary_operator cast_expression
	| SIZEOF unary_expression
	| SIZEOF '(' type_name ')'
	;


unary_operator
	: '&' | '*' | '+' | '-' | '~' | '!'
	;


postfix_expression
	: primary_expression
	| postfix_expression '[' expression ']'
	| postfix_expression '(' ')'
	| postfix_expression '(' argument_expression_list ')'
	| postfix_expression '.' identifier
	| postfix_expression PTR_OP identifier
	| postfix_expression INC_OP
	| postfix_expression DEC_OP
	;

primary_expression
	: IDENTIFIER
	| constant
	| STRING
	| '(' expression ')'
	;

argument_expression_list
	: assignment_expression
	| argument_expression_list ',' assignment_expression
	;

constant
        : INTEGER_CONSTANT
        | CHARACTER_CONSTANT
        | FLOATING_CONSTANT
        | ENUMERATION_CONSTANT
	;


%%
