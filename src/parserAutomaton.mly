(* {2 Tokens } *)
%token EOF
%token COLON PIPE SEMICOLON EQUALS
%token <string> COUNT
%token LEFT_PAREN RIGHT_PAREN
%token LEFT_COMMENT_DELIM RIGHT_COMMENT_DELIM
%token <string> COMMENT_CHUNK
%token <string> COMMENT_LINE
%token <string> IDENTIFIER
%token <string> SHORT_FLAGS
%token <string> LONG_FLAG
(* %token <bool> BOOL *)
(* %token <int> NUM10 *)
(* %token <string> STREL *)

%start <AST.t> script
%start <AST.statement> statement

%{ open AST %}

%%
(* {2 Rules } *)

script:
 | xs = optterm_list(break, unterminated_statement); EOF { {statements = xs} }
 ;

statement:
 | x = unterminated_statement; break?; EOF { x }
 ;

unterminated_statement:
 | COLON*; count = COUNT?; cmd = command; args = arguments
 { make_statement ?count ~cmd ~args }
 ;

command:
 | x = IDENTIFIER { x }
 ;

arguments:
 | { [] }
 | xs = nonempty_arguments { xs }
 ;

nonempty_arguments:
 | xs = positional_and_arguments { xs }
 | xs = flag_and_arguments { xs }
 ;

positional_and_arguments:
 | x = IDENTIFIER { [Positional x] }
 | x = IDENTIFIER; xs = nonempty_arguments { (Positional x) :: xs }
 ;

(* Still broken short_flags. *)
flag_and_arguments:
 | x = last_long_flag  { [x] }
 | xs = last_short_flags  { xs }

 | x = long_flag_before_positional; xs = positional_and_arguments { x :: xs }
 | x = long_flag_before_flag; xs = flag_and_arguments { x :: xs }

 | xs = short_flags; ys = nonempty_arguments { xs @ ys }
 ;

long_flag_before_flag:
 | name = LONG_FLAG  { Flag {name; payload = Absent} }
 | name = LONG_FLAG; EQUALS; payload = IDENTIFIER
 { Flag {name; payload = Resolved payload} }
 ;

long_flag_before_positional:
 | name = LONG_FLAG  { Flag {name; payload = Unresolved} }
 | name = LONG_FLAG; EQUALS; payload = IDENTIFIER
 { Flag {name; payload = Resolved payload} }
 ;

last_long_flag:
 | name = LONG_FLAG  { Flag {name; payload = Absent} }
 | name = LONG_FLAG; EQUALS; payload = IDENTIFIER
 { Flag {name; payload = Resolved payload} }
 ;

(* FIXME: NYI. This will mark *all* short-flags as unresolved. Boomsplode. *)
short_flags:
 | xs = explode(SHORT_FLAGS)
 { List.map (fun x -> Flag {name = x; payload = Unresolved}) xs }
 ;

last_short_flags:
 | xs = explode(SHORT_FLAGS)
 { List.map (fun x -> Flag {name = x; payload = Absent}) xs }
 ;

break:
 | SEMICOLON { }
 ;

%%
