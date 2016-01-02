/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
#define RETURN_ERROR(msg) {\
	cool_yylval.error_msg = (msg);\
	return (ERROR);\
} while (0)

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
ASSIGN 		<-
LE		<=
OPS 		[-=:;.(){}@,~+*/<]

/*
 * Spaces.
 */

NEW_LINE	\n
SPACE 		[ \t\v\f\r]*

/*
 * String literals.
 */

%x string_literal
%x string_contains_errors
%{
	char *string_error_msg;
	void string_literal_append(char);
%}
STR_START   	\"
STR_NCHR 	[^"\\\n]
STR_ESP 	\\.
STR_NL 		\\\n
STR_UNESP_NL 	\n
STR_END 	\"
STR_ERROR_BODY	({STR_NCHR}|{STR_ESP})*
STR_ERROR_NL    {STR_NL}
STR_ERROR_END 	{STR_END}|{STR_UNESP_NL}
/*
 * Comments.
 */
LINE_COMMENT 	--[^\n]*
%x comment
%{
	/*
	 * Comment may be nested.
	 */
	int comment_level;
	void start_comment();
	void end_comment();
%}
COMMENT_START	\(\*
COMMENT_BODY 	([^\*\(\n]|\([^\*]|\*[^\)\*])*
COMMENT_NL	\n
COMMENT_END 	\*\)
/*
 * Numbers.
 */
NUMBER	 	[0-9]+
/*
 * Identifiers.
 */
TYPEID 		[A-Z][_0-9a-zA-Z]*
OBJECTID	[a-z][_0-9a-zA-Z]*
/*
 * Keywords.
 */
K_CLASS		(?i:class)
K_ELSE		(?i:else)
K_FALSE		f(?i:alse)
K_FI		(?i:fi)
K_IF		(?i:if)
K_IN		(?i:in)
K_INHERITS	(?i:inherits)
K_ISVOID	(?i:isvoid)
K_LET		(?i:let)
K_LOOP		(?i:loop)
K_POOL		(?i:pool)
K_THEN		(?i:then)
K_WHILE		(?i:while)
K_CASE		(?i:case)
K_ESAC		(?i:esac)
K_NEW		(?i:new)
K_OF		(?i:of)
K_NOT		(?i:not)
K_TRUE		t(?i:rue)
%%
 /*
  * Line number.
  * In code, comment and string literal.
  */
{NEW_LINE} 		{ ++curr_lineno; }
{SPACE} 		{ }
 
{OPS} 			{ return *yytext; }
{NUMBER} 		{
	cool_yylval.symbol = inttable.add_string(yytext); 
	return (INT_CONST);
}
 
 /*
  *  Nested comments
  */
{LINE_COMMENT} 		{ }
<INITIAL,comment>{COMMENT_START} {
	start_comment();
}
<comment>\*/\* 		{ }
<comment>{COMMENT_BODY} { }
<comment>{COMMENT_NL}	{ ++curr_lineno; }
<comment><<EOF>>  {
	BEGIN(INITIAL);
	RETURN_ERROR("EOF in comment");
}
<comment>{COMMENT_END} 	{
	end_comment();
}
{COMMENT_END} 		{
	RETURN_ERROR("Unmatched *)");
}
 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{LE}			{ return (LE); }
{ASSIGN}		{ return (ASSIGN); }
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{K_CLASS}		{ return (CLASS); }
{K_ELSE}		{ return (ELSE); }
{K_FALSE}		{
	/*
	 * Sematic values of booleans are parsed during
	 * lexical analysis.
	 */
	cool_yylval.boolean = false;
	return (BOOL_CONST);
}
{K_FI}			{ return (FI); }
{K_IF}			{ return (IF); }
{K_IN}			{ return (IN); }
{K_INHERITS}		{ return (INHERITS); }
{K_ISVOID}		{ return (ISVOID); }
{K_LET}			{ return (LET); }
{K_LOOP}		{ return (LOOP); }
{K_POOL}		{ return (POOL); }
{K_THEN}		{ return (THEN); }
{K_WHILE}		{ return (WHILE); }
{K_CASE}		{ return (CASE); }
{K_ESAC}		{ return (ESAC); }
{K_NEW}			{ return (NEW); }
{K_OF}			{ return (OF); }
{K_NOT}			{ return (NOT); }
{K_TRUE}		{
	cool_yylval.boolean = true;
	return (BOOL_CONST);
}
 /*
  * IDs.
  * Must be put after keywords.
  */
{TYPEID} 		{
	cool_yylval.symbol = idtable.add_string(yytext);
	return (TYPEID);
}
{OBJECTID} 		{
	cool_yylval.symbol = idtable.add_string(yytext);
	return (OBJECTID);
}
 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
{STR_START}		{
	BEGIN(string_literal);
	string_buf_ptr = string_buf;
}
<string_literal>{STR_NCHR} {
	string_literal_append(*yytext);
}
<string_literal>{STR_ESP} {
	char org_str = '\0';
	switch (*(yytext + 1))
	{
		case 'b': org_str = '\b';
			  break;
		case 't': org_str = '\t';
			  break;
		case 'n': org_str = '\n';
			  break;
		case 'f': org_str = '\f';
			  break;
		default : org_str = *(yytext + 1);
	}
	string_literal_append(org_str);
}
<string_literal>{STR_NL} {
	string_literal_append('\n');
	++curr_lineno;
}
<string_literal>{STR_UNESP_NL} {
	++curr_lineno;
	BEGIN(INITIAL);
	RETURN_ERROR("Unterminated string constant");
}
<string_literal><<EOF>> {
	BEGIN(INITIAL);
	RETURN_ERROR("EOF in string constant");
}
<string_literal>{STR_END} {
	/*
	 * No errors should be handled here.
	 * Since we've reserved enough space for this '\0'.
	 */
	*string_buf_ptr++ = '\0';
	cool_yylval.symbol = stringtable.add_string(string_buf);
	BEGIN(INITIAL);
	return (STR_CONST);
}
<string_contains_errors>{STR_ERROR_BODY} { }
<string_contains_errors>{STR_ERROR_NL} {
	++curr_lineno;
}
<string_contains_errors>{STR_ERROR_END} {
	BEGIN(INITIAL);
	RETURN_ERROR(string_error_msg);
}
 /*
  * Error handling.
  */
<*>.			{
	/*
	 * Invalid character error.
	 */
	RETURN_ERROR(yytext);
}
%%
void start_comment()
{
	if (comment_level == 0)
	{
		BEGIN(comment);
	}
	++comment_level;
}
void end_comment()
{
	--comment_level;
	if (comment_level == 0)
	{
		BEGIN(INITIAL);
	}
}
void string_literal_append(char c)
{
	if (string_buf_ptr - string_buf == MAX_STR_CONST - 1)
	{
		BEGIN(string_contains_errors);
		string_error_msg = "String constant too long";
		return;
	}
	if (c == '\0')
	{
		BEGIN(string_contains_errors);
		string_error_msg = "String contains null character";
		return;
	}
	*string_buf_ptr++ = c;
}