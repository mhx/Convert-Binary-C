O                       [0-7]
D			[0-9]
L			[a-zA-Z_]
H			[a-fA-F0-9]
E			[Ee][+-]?{D}+
FS			(f|F|l|L)
IS			(u|U|l|L)
W			[ \t\f]*
LIT                     \"(\\.|[^\\"])*\"

%{
#include <stdio.h>
#include "y.tab.h"
extern char* yylval;
int line_num = 1;
extern int idents_only[];
%}

%%

"/*"			{ comment(); }

^{W}#{W}"line"?{W}{D}+{W}{LIT}.*\n { line_directive(); }
^{W}#{W}"line"?{W}{D}+[^"]*\n      { line_directive(); }
^{W}#{W}"pragma".*\n               { /* ignore pragma */ }

\n    			{ line_num++; }
[ \t\f]+    		{ }

"auto"			{ return(AUTO); }
"break"			{ return(BREAK); }
"case"			{ return(CASE); }
"char"			{ return(CHAR); }
"const"			{ return(CONST); }
"continue"		{ return(CONTINUE); }
"default"		{ return(DEFAULT); }
"do"			{ return(DO); }
"double"		{ return(DOUBLE); }
"else"			{ return(ELSE); }
"enum"			{ return(ENUM); }
"extern"		{ return(EXTERN); }
"float"			{ return(FLOAT); }
"for"			{ return(FOR); }
"goto"			{ return(GOTO); }
"if"			{ return(IF); }
"int"			{ return(INT); }
"long"			{ return(LONG); }
"register"		{ return(REGISTER); }
"return"		{ return(RETURN); }
"short"			{ return(SHORT); }
"signed"		{ return(SIGNED); }
"sizeof"		{ return(SIZEOF); }
"static"		{ return(STATIC); }
"struct"		{ return(STRUCT); }
"switch"		{ return(SWITCH); }
"typedef"		{ return(TYPEDEF); }
"union"			{ return(UNION); }
"unsigned"		{ return(UNSIGNED); }
"void"			{ return(VOID); }
"volatile"		{ return(VOLATILE); }
"while"			{ return(WHILE); }

{L}({L}|{D})*		{ return(identifier_or_typedef_name()); }

0[xX]{H}+{IS}?		{ return(INTEGER_CONSTANT); }
0[xX]{H}+{IS}?		{ return(INTEGER_CONSTANT); }
0{O}+{IS}?		{ return(INTEGER_CONSTANT); }
0{O}+{IS}?		{ return(INTEGER_CONSTANT); }
{D}+{IS}?		{ return(INTEGER_CONSTANT); }
{D}+{IS}?		{ return(INTEGER_CONSTANT); }

'(\\.|[^\\'])+'		{ return(CHARACTER_CONSTANT); }

{D}+{E}{FS}?		{ return(FLOATING_CONSTANT); }
{D}*"."{D}+({E})?{FS}?	{ return(FLOATING_CONSTANT); }
{D}+"."{D}*({E})?{FS}?	{ return(FLOATING_CONSTANT); }

{LIT}			{ return(STRING); }

">>="			{ return(RIGHT_ASSIGN); }
"<<="			{ return(LEFT_ASSIGN); }
"+="			{ return(ADD_ASSIGN); }
"-="			{ return(SUB_ASSIGN); }
"*="			{ return(MUL_ASSIGN); }
"/="			{ return(DIV_ASSIGN); }
"%="			{ return(MOD_ASSIGN); }
"&="			{ return(AND_ASSIGN); }
"^="			{ return(XOR_ASSIGN); }
"|="			{ return(OR_ASSIGN); }
">>"			{ return(RIGHT_OP); }
"<<"			{ return(LEFT_OP); }
"++"			{ return(INC_OP); }
"--"			{ return(DEC_OP); }
"->"			{ return(PTR_OP); }
"&&"			{ return(AND_OP); }
"||"			{ return(OR_OP); }
"<="			{ return(LE_OP); }
">="			{ return(GE_OP); }
"=="			{ return(EQ_OP); }
"!="			{ return(NE_OP); }
";"			{ return(';'); }
"{"			{ return('{'); }
"}"			{ return('}'); }
","			{ return(','); }
":"			{ return(':'); }
"="			{ return('='); }
"("			{ return('('); }
")"			{ return(')'); }
"["			{ return('['); }
"]"			{ return(']'); }
"."			{ return('.'); }
"&"			{ return('&'); }
"!"			{ return('!'); }
"~"			{ return('~'); }
"-"			{ return('-'); }
"+"			{ return('+'); }
"*"			{ return('*'); }
"/"			{ return('/'); }
"%"			{ return('%'); }
"<"			{ return('<'); }
">"			{ return('>'); }
"^"			{ return('^'); }
"|"			{ return('|'); }
"?"			{ return('?'); }

.			{ return BAD_TOKEN; }

%%

char *filename = 0;
extern int yychar;
extern int decl_level;
extern int errors;

yyerror(s)
char *s;
{
	errors++;

        fprintf(stderr, "%s: ", s);

        if(filename)
              fprintf(stderr, "file \"%s\", ", filename );

        fprintf(stderr, "line %d, token = \"%s\"\n",
              line_num, yytext);
}

#ifndef yywrap
yywrap()
{
	return(1);
}
#endif

comment()
{
	
        int splat_seen = 0;

        for(;;) {
           int ch = input();
           switch (ch) {
              default:
                 splat_seen = 0;
                 break;
              case '*':
                 splat_seen = 1;
                 break;
              case '/':
                 if(splat_seen)
                    return;
                 else
                    splat_seen = 0;
                 break;
              case 0: {
                   /* This should never happen, because cpp should
                    * catch the error first.
                    */
                   yychar = BAD_TOKEN;
                   yyerror("Unterminated comment");
                   exit(-(++errors));
               }
           }

        }

}

extern char* strpbrk();
extern char* index();
extern char* rindex();
extern char* emalloc();

int line_directive()
{
  /* Handle directive left by the preprocessor, i.e.
   *
   *    # line 123 "foo.h"
   *    # line 125
   *    # 126 "foo.h" 2
   *
   * et cetera.
   */

  char *line_ptr = strpbrk(yytext, "0123456789");
  char *file_ptr = index(line_ptr, '"') + 1;  /* Start of file-name */

  line_num = atoi(line_ptr);

  if(file_ptr != 0) {

 	char *file_end = rindex(file_ptr, '"');    /* end */
	int  len = file_end - file_ptr;

	if(filename != 0)
		free(filename);

	filename = emalloc(len + 1);

	strncpy(filename, file_ptr, len);
	filename[len] = 0;

  }
}

int identifier_or_typedef_name()
{
    /* Make a copy and set yylval.
     */
    int len = strlen(yytext);
    char *name = emalloc(len+1);
    strncpy(name, yytext, len);
    name[len] = 0;

    yylval = name;

    /* Return the type of the token,
     * IDENTIFIER, TYPEDEF_NAME, or ENUM_CONSTANT
     */
    if(idents_only[decl_level])
        return IDENTIFIER;
    else {
        return type_of_name(name);
    }
        
}


lex_sync()
{
    /* Probably because of its use for interactive line-interpreters
     * like "dc", original yacc uses a "lazy" lookahead, that is to say, it
     * does not fetch a lookahead when the only action is the default
     * reduction. But our scanner-feedback must keep the lookahead in
     * sync. This routine sees to it that the lookahead has been
     * fetched.
     *
     * yychar is the yacc lookahead token. It is -1 when
     * yacc is being "lazy". yylex() is allowed to return -1 (or any
     * negative int) to indicate EOF, but yacc uses 0 to indicate EOF.
     */
    
    if(yychar == -1)
      if((yychar = yylex()) < 0)
	      yychar = 0;
}

