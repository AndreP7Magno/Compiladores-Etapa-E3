grammar Gramatica;

/*
Programa: Declara��es de fun��es e uma fun��o main SEMPRE

def fun x = x + 1

def main =
  let x = read_int
  in
     print concat "Resultado" (string (fun x))
*/
@header{
	using System;
	using System.Collections;
	using System.Collections.Generic;
	using System.Linq;
	using System.Text;
	using System.Threading.Tasks;
	using Antlr4.Runtime;
}

@members
{	List<Types> symbols = new List<Types>();
	int nv = 0;
}

WS : [ \r\t\u000C\n]+ -> skip;

COMMENT : '//' ~('\n'|'\r')* -> channel(HIDDEN);

// C�digo de Programa �mML
program
    : decls maindecl EOF
    ;

// Declara��es de Fun��es
// def f1 a : int, c : int = a + b
// def f2 a : int, c : int = (float a) / b
decls
    : decl decls  #decls_one_decl_rule
    | /*empty*/   #decls_end_rule
    ;

// Declara��o da fun��o principal
// def main = 1 + 1
maindecl
  : 'def' 'main' '=' funcbody #programmain_rule
  ;

// Declara��o de uma fun��o
// Header de Fun��o:
// def f2 a : int, b : int -> float
// Implementa��o de Fun��o:
// def f2 a : int, b : int = a / (float b)
decl
    :   'def' functionname typed_arg_list '->' type
        #funcdef_header
    |   'def' functionname typed_arg_list '=' funcbody
        #funcdef_impl
    |   custom_type_decl
        #decl_custom_type
    ;

// Lista de Par�metros:
//   a : int      , b : int, c : int
// |----------| |--------------------|
//    param             cont

typed_arg_list
    :   typed_arg typed_arg_list_cont
        #typed_arg_list_rule
    ;

typed_arg
    :   symbol ':' type
    ;

typed_arg_list_cont
    :   ',' typed_arg_list #typed_arg_list_cont_rule
    |   /*vazio*/          #typed_arg_list_end
    ;

// class MeuTipo = a : int, b : float, c : char[], d : {int, int}
custom_type_decl
    :   'class' custom_type_name '=' typed_arg_list
        #custom_type_decl_rule
    ;

// Tipo
// int , char, etc.
// int[], char[], etc
// int[], char[][], etc.
type
    :   basic_type               #type_basictype_rule
    |   '{' type (',' type)* '}' #type_tuple_rule
    |   custom_type_name         #type_custom_rule
    |   type '[]'                #type_sequence_rule
    ;

custom_type_name
    :   symbol                 #custom_type_name_rule
    ;

// // Tipos B�sicos da Linguagem
basic_type
    :   'char'
    |   'int'
    |   'bool'
    |   'float'
    ;

// Nome de Fun��o
functionname
    : TOK_ID                                 #fdecl_funcname_rule
    ;


// Corpo de Fun��o:
// if x == y then x else x + y
// ou
// let x = 1 + 2, y = 3+1 in (f x y)
// ou
// 1 + 2 + 3
funcbody
    :   'if' cond=funcbody
        'then' bodytrue=funcbody
        'else' bodyfalse=funcbody
        #fbody_if_rule
    |   'let' letlist 
        'in' fnested=funcbody {nv++;}
        #fbody_let_rule
    |   metaexpr
        #fbody_expr_rule
  ;

// Lista de declara��es
//   x = 1        , y = 2
// |--------|  |----------|
//  expr           cont
letlist
  : letvarexpr  letlist_cont  #letlist_rule
  ;

letlist_cont
  :   ',' letvarexpr letlist_cont #letlist_cont_rule
  |   /*empty*/                   #letlist_cont_end ;

// Atribui��o:
// x = 1 + 2
// ou
// _ = 1 + 2
// ou
// x::rest = l
letvarexpr
  :   sym=symbol '=' funcbody   
  {	
	if(symbols.IndexOf($symbol.id) == -1)
		symbols.Add($symbol.id);
	Console.WriteLine("store " + symbols.IndexOf($symbol.id));
  }                 #letvarattr_rule
  |    '_'       '=' funcbody                    #letvarresult_ignore_rule
  |    head=symbol '::' tail=symbol '=' funcbody #letunpack_rule
  ;

// Meta Express�o:
// Booleanas
// a && b
// a || b
// !a
// Concatena��o de listas
// a :: b
// Cria��o de lista
// [a]
// Matem�ticas
// a / b
// a + b
// Relacionais
// a <= b
// a >= b
// S�mbolo
// a
// Literais
// 1
// 2.4
// 0xafbe
// 1010b
// Chamada de Fun��o
// f a b
// Cast
// int a
tuple_ctor
    :   '{' first=funcbody (',' funcbody)* '}'
    ;

class_ctor
    : 'make'
        name=symbol tuple_ctor
    ;

metaexpr
    : '(' funcbody ')'                            #me_exprparens_rule     // Anything in parenthesis -- if, let, funcion call, etc
    | tuple_ctor                                  #me_tup_create_rule     // tuple creation
    | class_ctor                                  #me_class_ctor_rule     // create a class from
    | sequence_expr                               #me_list_create_rule    // creates a list [x]
    | TOK_NEG symbol                              #me_boolneg_rule        // Negate a variable
    | TOK_NEG '(' funcbody ')'                    #me_boolnegparens_rule  // or anything in between ( )
    | l=metaexpr op=TOK_CONCAT r=metaexpr         #me_listconcat_rule     // Sequence concatenation
    | l=metaexpr op=TOK_DIV_OR_MUL r=metaexpr 
		{
			if($op.text == "*")
				Console.WriteLine("mul");
			if($op.text == "/")
				Console.WriteLine("div");
		}    #me_exprmuldiv_rule     // Div, Mult and mod are equal
    | l=metaexpr op=TOK_PLUS_OR_MINUS r=metaexpr
		{
			if($op.text == "+")
				Console.WriteLine("add");
			if($op.text == "-")
				Console.WriteLine("sub");
		}  #me_exprplusminus_rule  // Sum and Sub are equal
    | l=metaexpr TOK_CMP_GT_LT r=metaexpr         #me_boolgtlt_rule       // < <= >= > are equal
    | l=metaexpr TOK_CMP_EQ_DIFF r=metaexpr       #me_booleqdiff_rule     // == and != are egual
    | l=metaexpr TOK_BOOL_AND r=metaexpr          #me_bool_and_rule      // &&
    | l=metaexpr TOK_BOOL_OR r=metaexpr           #me_bool_or_rule      // ||
    | 'get' pos=DECIMAL funcbody                  #me_tuple_get_rule      // get 0 funcTup
    | 'set' pos=DECIMAL tup=funcbody val=funcbody #me_tuple_set_rule      // get 0 funcTup
    | 'get' name=symbol funcbody                  #me_class_get_rule      // get campo
    | 'set' name=symbol cl=funcbody val=funcbody  #me_class_set_rule      // get campo
    | symbol                       
	{		
			for(int i = symbols.Count-1; i >= 0 ; i--)
			if(symbols[i].nivel == $symbol.id.nivel && symbols[i].nome == $symbol.id.nome) {
				Console.WriteLine("load " + i); break;
		}
						
	}               #me_exprsymbol_rule     // a single symbol
    | literal                                     #me_exprliteral_rule    // literal value
    | funcall                                     #me_exprfuncall_rule    // a funcion call
    | cast                                        #me_exprcast_rule       // cast a type to other
    ;

// Cria��o de sequ�ncia:
// [a + b]
sequence_expr
  : '[' funcbody ']'                               #seq_create_seq
  ;

// Chamada de fun��o
// f a b
funcall
  : symbol funcall_params #funcall_rule
  ;

// Par�metros de Fun��o
//    a + b        c d
// |-------|   |-------|
//   expr         cont
funcall_params
    :   metaexpr funcall_params_cont #funcallparams_rule
    |   '_'                          #funcallnoparam_rule
    ;

// Continua��o dos Par�metros
//   c       d
// |----|  |-------|
//  expr    cont
funcall_params_cont
    :   metaexpr funcall_params_cont #funcall_params_cont_rule
    |   /*empty*/                    #funcall_params_end_rule
    ;

// Cast
// int b
// char 65
cast
  : c=basic_type funcbody #cast_rule
  ;

literal
    :   'nil'              #literalnil_rule
    |   ('true' | 'false') #literaltrueorfalse_rule
    |   FLOAT            {Console.WriteLine("push " + $FLOAT.text);}  #literal_float_rule
    |   DECIMAL          {Console.WriteLine("push " + $DECIMAL.text);}   #literal_decimal_rule
    |   HEXADECIMAL      {Console.WriteLine("push " + $HEXADECIMAL.text);}  #literal_hexadecimal_rule
    |   BINARY           {Console.WriteLine("push " + $BINARY.text);}  #literal_binary_rule
    |   TOK_STR_LIT      {Console.WriteLine("push " + $TOK_STR_LIT.text);}  #literalstring_rule
    |   TOK_CHAR_LIT     {Console.WriteLine("push " + $TOK_CHAR_LIT.text);}  #literal_char_rule
    ;

symbol returns [Types id]
    : TOK_ID   {
	Types idz = new Types();
	idz.nome = $TOK_ID.text;
	idz.nivel = nv;
	$id = idz;
	}#symbol_rule
    ;

// id: begins with a letter, follows letters, numbers or underscore
TOK_ID: [a-zA-Z]([a-zA-Z0-9_]*);
TOK_CONCAT: '::' ;
TOK_NEG: '!';
TOK_POWER: '^' ;
TOK_DIV_OR_MUL: ('/'|'*'|'%');
TOK_PLUS_OR_MINUS: ('+'|'-');
TOK_CMP_GT_LT: ('<='|'>='|'<'|'>');
TOK_CMP_EQ_DIFF: ('=='|'!=');
TOK_BOOL_OR: '||' ;
TOK_BOOL_AND: '&&' ;
TOK_REL_OP : ('>'|'<'|'=='|'>='|'<=') ;

// TOK_STR_LIT
// : '"' (~[\"\\\r\n] | '\\' (. | EOF))* '"'
// ;

TOK_STR_LIT
    :   '"' // open string
        ( ~('"' | '\n' | '\r' ) | '\\' [a-z"\\] )*
        '"' // close string
    ;

TOK_CHAR_LIT
    :   '\''
        ( '\\' [a-z] | ~('\'') ) // Um escape (\a, \n, \t) ou qualquer coisa que n�o seja aspas (a, b, ., z, ...)
        '\''
    ;

FLOAT : '-'? DEC_DIGIT+ '.' DEC_DIGIT+([eE][+-]? DEC_DIGIT+)? ;

DECIMAL : '-'? DEC_DIGIT+ ;

HEXADECIMAL : '0' 'x' HEX_DIGIT+ ;

BINARY : BIN_DIGIT+ 'b' ; // Sequencia de digitos seguida de b  10100b

fragment
BIN_DIGIT : [01];

fragment
HEX_DIGIT : [0-9A-Fa-f];

fragment
DEC_DIGIT : [0-9] ;
