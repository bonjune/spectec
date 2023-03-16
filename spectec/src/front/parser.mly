%{
open Source
open Ast


(* Error handling *)

let error at msg = Source.error at "syntax" msg

let parse_error msg =
  error Source.no_region
    (if msg = "syntax error" then "unexpected token" else msg)


(* Position handling *)

let position_to_pos position =
  { file = position.Lexing.pos_fname;
    line = position.Lexing.pos_lnum;
    column = position.Lexing.pos_cnum - position.Lexing.pos_bol
  }

let positions_to_region position1 position2 =
  { left = position_to_pos position1;
    right = position_to_pos position2
  }

let at () =
  positions_to_region (Parsing.symbol_start_pos ()) (Parsing.symbol_end_pos ())
let ati i =
  positions_to_region (Parsing.rhs_start_pos i) (Parsing.rhs_end_pos i)


let as_seq_typ typ =
  match typ.it with
  | SeqT (_::_::_ as typs) -> typs
  | _ -> [typ]

let as_seq_exp exp =
  match exp.it with
  | SeqE (_::_::_ as exps) -> exps
  | _ -> [exp]


(* Identifier Status *)

module VarSet = Set.Make(String)

let atom_vars = ref VarSet.empty

%}

%token LPAR RPAR LBRACK RBRACK LBRACE RBRACE
%token COLON SEMICOLON COMMA DOT DOT2 DOT3 BAR DASH
%token EQ NE LT GT LE GE SUB EQDOT2
%token NOT AND OR
%token QUEST PLUS MINUS STAR SLASH UP COMPOSE
%token ARROW ARROW2 SQARROW TURNSTILE TILESTURN
%token DOLLAR TICK
%token BOT
%token HOLE CAT
%token BOOL NAT TEXT
%token SYNTAX RELATION RULE VAR DEF
%token IFF OTHERWISE HINT
%token EPSILON
%token<bool> BOOLLIT
%token<int> NATLIT
%token<string> TEXTLIT
%token<string> UPID LOID DOTID
%token EOF

%right ARROW2
%left OR
%left AND
%nonassoc TURNSTILE
%nonassoc TILESTURN
%right SQARROW
%left COLON SUB
%left COMMA
%right EQ NE LT GT LE GE
%right ARROW
%left SEMICOLON
%left DOT DOT2 DOT3
%left PLUS MINUS COMPOSE
%left STAR SLASH
%left UP

%start script check_atom
%type<Ast.script> script
%type<bool> check_atom

%%

/* Identifiers */

id : UPID { $1 } | LOID { $1 }

atomid_ : UPID { $1 }
varid : LOID { $1 @@ at () }
defid : id { $1 @@ at () }
relid : id { $1 @@ at () }
hintid : id { $1 }
fieldid : atomid_ { Atom $1 }
dotid : DOTID { Atom $1 }

ruleid : ruleid_ { $1 @@ at () }
ruleid_ : id { $1 } | ruleid_ DOTID { $1 ^ "." ^ $2 }
atomid : atomid_ { $1 } | atomid DOTID { $1 ^ "." ^ $2 }

atom :
  | atomid { Atom $1 }
  | BOT { Bot }

check_atom :
  | UPID EOF { VarSet.mem $1 !atom_vars }


/* Iteration */

iter :
  | QUEST { Opt }
  | PLUS { List1 }
  | STAR { List }
  | UP arith_prim { ListN $2 }


/* Types */

typ_prim : typ_prim_ { $1 @@ at () }
typ_prim_ :
  | varid { VarT $1 }
  | atom { AtomT $1 }
  | BOOL { BoolT }
  | NAT { NatT }
  | TEXT { TextT }
  | LPAR typ_list RPAR
    { match $2 with
      | [] -> ParenT (SeqT [] @@ ati 2)
      | [typ] -> ParenT typ
      | typs -> TupT typs
    }
  | TICK LPAR typ_list RPAR { BrackT (Paren, $3) }
  | TICK LBRACK typ_list RBRACK { BrackT (Brack, $3) }
  | TICK LBRACE typ_list RBRACE { BrackT (Brace, $3) }

typ_post : typ_post_ { $1 @@ at () }
typ_post_ :
  | typ_prim_ { $1 }
  | typ_post iter { IterT ($1, $2) }

typ_seq : typ_seq_ { $1 @@ at () }
typ_seq_ :
  | typ_post_ { $1 }
  | typ_post typ_seq { SeqT ($1 :: as_seq_typ $2) }

typ_un : typ_un_ { $1 @@ at () }
typ_un_ :
  | typ_seq_ { $1 }
  | DOT typ_un { RelT (SeqT [] @@ ati 1, Dot, $2) }
  | DOT2 typ_un { RelT (SeqT [] @@ ati 1, Dot2, $2) }
  | DOT3 typ_un { RelT (SeqT [] @@ ati 1, Dot3, $2) }
  | SEMICOLON typ_un { RelT (SeqT [] @@ ati 1, Semicolon, $2) }
  | ARROW typ_un { RelT (SeqT [] @@ ati 1, Arrow, $2) }

typ_bin : typ_bin_ { $1 @@ at () }
typ_bin_ :
  | typ_un_ { $1 }
  | typ_bin DOT typ_bin { RelT ($1, Dot, $3) }
  | typ_bin DOT2 typ_bin { RelT ($1, Dot2, $3) }
  | typ_bin DOT3 typ_bin { RelT ($1, Dot3, $3) }
  | typ_bin SEMICOLON typ_bin { RelT ($1, Semicolon, $3) }
  | typ_bin ARROW typ_bin { RelT ($1, Arrow, $3) }

typ_unrel : typ_unrel_ { $1 @@ at () }
typ_unrel_ :
  | typ_bin_ { $1 }
  | COLON typ_rel { RelT (SeqT [] @@ ati 1, Colon, $2) }
  | SUB typ_rel { RelT (SeqT [] @@ ati 1, Sub, $2) }
  | SQARROW typ_rel { RelT (SeqT [] @@ ati 1, SqArrow, $2) }
  | TILESTURN typ_rel { RelT (SeqT [] @@ ati 1, Tilesturn, $2) }
  | TURNSTILE typ_rel { RelT (SeqT [] @@ ati 1, Turnstile, $2) }

typ_rel : typ_rel_ { $1 @@ at () }
typ_rel_ :
  | typ_unrel_ { $1 }
  | typ_rel COLON typ_rel { RelT ($1, Colon, $3) }
  | typ_rel SUB typ_rel { RelT ($1, Sub, $3) }
  | typ_rel SQARROW typ_rel { RelT ($1, SqArrow, $3) }
  | typ_rel TILESTURN typ_rel { RelT ($1, Tilesturn, $3) }
  | typ_rel TURNSTILE typ_rel { RelT ($1, Turnstile, $3) }

typ : typ_rel { $1 }

deftyp : deftyp_ { $1 @@ at () }
deftyp_ :
  | typ { AliasT $1 }
  | LBRACE fieldtyp_list RBRACE { StructT $2 }
  | BAR casetyp_list { VariantT (fst $2, snd $2) }

fieldtyp_list :
  | /* empty */ { [] }
  | fieldid typ hint_list { ($1, $2, $3) :: [] }
  | fieldid typ hint_list COMMA fieldtyp_list { ($1, $2, $3) :: $5 }

casetyp_list :
  | /* empty */ { [], [] }
  | varid { [$1], [] }
  | varid BAR casetyp_list { $1::fst $3, snd $3 }
  | atom typs hint_list { [], ($1, $2, $3)::[] }
  | atom typs hint_list BAR casetyp_list { fst $5, ($1, $2, $3)::snd $5 }

typ_list :
  | /* empty */ { [] }
  | typ_bin { $1::[] }
  | typ_bin COMMA typ_list { $1::$3 }

typs :
  | /* empty */ { [] }
  | typ_post typs { $1::$2 }


/* Expressions */

exp_prim : exp_prim_ { $1 @@ at () }
exp_prim_ :
  | varid { VarE $1 }
  | BOOLLIT { BoolE $1 }
  | NATLIT { NatE $1 }
  | TEXTLIT { TextE $1 }
  | EPSILON { SeqE [] }
  | LBRACE fieldexp_list RBRACE { StrE $2 }
  | HOLE { HoleE }
  | LPAR exp_list RPAR
    { match $2 with
      | [] -> ParenE (SeqE [] @@ ati 2)
      | [exp] -> ParenE exp
      | exps -> TupE exps
    }
  | TICK LPAR exp_list RPAR { BrackE (Paren, $3) }
  | TICK LBRACK exp_list RBRACK { BrackE (Brack, $3) }
  | TICK LBRACE exp_list RBRACE { BrackE (Brace, $3) }
  | DOLLAR LPAR arith RPAR { $3.it }
  | DOLLAR defid exp_prim { CallE ($2, $3) }

exp_post : exp_post_ { $1 @@ at () }
exp_post_ :
  | exp_prim_ { $1 }
  | exp_post LBRACK arith RBRACK { IdxE ($1, $3) }
  | exp_post LBRACK arith COLON arith RBRACK { SliceE ($1, $3, $5) }
  | exp_post LBRACK path EQ exp RBRACK { UpdE ($1, $3, $5) }
  | exp_post LBRACK path EQDOT2 exp RBRACK { ExtE ($1, $3, $5) }
  | exp_post dotid { DotE ($1, $2) }
  | exp_post iter { IterE ($1, $2) }

exp_atom : exp_atom_ { $1 @@ at () }
exp_atom_ :
  | exp_post_ { $1 }
  | atom { AtomE $1 }
  | exp_atom CAT exp_prim { CatE ($1, $3) }

exp_seq : exp_seq_ { $1 @@ at () }
exp_seq_ :
  | exp_atom_ { $1 }
  | exp_atom exp_seq { SeqE ($1 :: as_seq_exp $2) }

exp_call : exp_call_ { $1 @@ at () }
exp_call_ :
  | exp_seq_ { $1 }
  | BAR exp BAR { LenE $2 }

exp_un : exp_un_ { $1 @@ at () }
exp_un_ :
  | exp_call_ { $1 }
  | NOT exp_un { UnE (NotOp, $2) }
  | DOT exp_un { RelE (SeqE [] @@ ati 1, Dot, $2) }
  | DOT2 exp_un { RelE (SeqE [] @@ ati 1, Dot2, $2) }
  | DOT3 exp_un { RelE (SeqE [] @@ ati 1, Dot3, $2) }
  | SEMICOLON exp_un { RelE (SeqE [] @@ ati 1, Semicolon, $2) }
  | ARROW exp_un { RelE (SeqE [] @@ ati 1, Arrow, $2) }

exp_bin : exp_bin_ { $1 @@ at () }
exp_bin_ :
  | exp_un_ { $1 }
  | exp_bin COMPOSE exp_bin { CompE ($1, $3) }
  | exp_bin DOT exp_bin { RelE ($1, Dot, $3) }
  | exp_bin DOT2 exp_bin { RelE ($1, Dot2, $3) }
  | exp_bin DOT3 exp_bin { RelE ($1, Dot3, $3) }
  | exp_bin SEMICOLON exp_bin { RelE ($1, Semicolon, $3) }
  | exp_bin ARROW exp_bin { RelE ($1, Arrow, $3) }
  | exp_bin EQ exp_bin { CmpE ($1, EqOp, $3) }
  | exp_bin NE exp_bin { CmpE ($1, NeOp, $3) }
  | exp_bin LT exp_bin { CmpE ($1, LtOp, $3) }
  | exp_bin GT exp_bin { CmpE ($1, GtOp, $3) }
  | exp_bin LE exp_bin { CmpE ($1, LeOp, $3) }
  | exp_bin GE exp_bin { CmpE ($1, GeOp, $3) }
  | exp_bin AND exp_bin { BinE ($1, AndOp, $3) }
  | exp_bin OR exp_bin { BinE ($1, OrOp, $3) }
  | exp_bin ARROW2 exp_bin { BinE ($1, OrOp, $3) }

exp_unrel : exp_unrel_ { $1 @@ at () }
exp_unrel_ :
  | exp_bin_ { $1 }
  | COMMA exp_rel { CommaE (SeqE [] @@ ati 1, $2) }
  | COLON exp_rel { RelE (SeqE [] @@ ati 1, Colon, $2) }
  | SUB exp_rel { RelE (SeqE [] @@ ati 1, Sub, $2) }
  | SQARROW exp_rel { RelE (SeqE [] @@ ati 1, SqArrow, $2) }
  | TILESTURN exp_rel { RelE (SeqE [] @@ ati 1, Tilesturn, $2) }
  | TURNSTILE exp_rel { RelE (SeqE [] @@ ati 1, Turnstile, $2) }

exp_rel : exp_rel_ { $1 @@ at () }
exp_rel_ :
  | exp_unrel_ { $1 }
  | exp_rel COMMA exp_rel { CommaE ($1, $3) }
  | exp_rel COLON exp_rel { RelE ($1, Colon, $3) }
  | exp_rel SUB exp_rel { RelE ($1, Sub, $3) }
  | exp_rel SQARROW exp_rel { RelE ($1, SqArrow, $3) }
  | exp_rel TILESTURN exp_rel { RelE ($1, Tilesturn, $3) }
  | exp_rel TURNSTILE exp_rel { RelE ($1, Turnstile, $3) }

exp : exp_rel { $1 }

fieldexp_list :
  | /* empty */ { [] }
  | fieldid exps1 { ($1, $2) :: [] }
  | fieldid exps1 COMMA fieldexp_list { ($1, $2) :: $4 }

exp_list :
  | /* empty */ { [] }
  | exp_bin { $1::[] }
  | exp_bin COMMA exp_list { $1::$3 }

exps1 :
  | exp_post { $1 }
  | exp_post exps1 { SeqE ($1 :: as_seq_exp $2) @@ at () }


arith_prim : arith_prim_ { $1 @@ at () }
arith_prim_ :
  | varid { VarE $1 }
  | NATLIT { NatE $1 }
  | LPAR arith RPAR { ParenE $2 }

arith_post : arith_post_ { $1 @@ at () }
arith_post_ :
  | arith_prim_ { $1 }
  | arith_post UP arith_prim { BinE ($1, ExpOp, $3) }
  | arith_post LBRACK arith RBRACK { IdxE ($1, $3) }
  | arith_post dotid { DotE ($1, $2) }

arith_atom : arith_atom_ { $1 @@ at () }
arith_atom_ :
  | arith_post_ { $1 }
  | atom { AtomE $1 }

arith_call : arith_call_ { $1 @@ at () }
arith_call_ :
  | arith_atom_ { $1 }
  | BAR exp BAR { LenE $2 }
  | DOLLAR defid { CallE ($2, SeqE [] @@ at ()) }
  | DOLLAR defid exp_prim { CallE ($2, $3) }

arith_un : arith_un_ { $1 @@ at () }
arith_un_ :
  | arith_call_ { $1 }
  | NOT arith_un { UnE (NotOp, $2) }
  | PLUS arith_un { UnE (PlusOp, $2) }
  | MINUS arith_un { UnE (MinusOp, $2) }

arith_bin : arith_bin_ { $1 @@ at () }
arith_bin_ :
  | arith_un_ { $1 }
  | arith_bin STAR arith_bin { BinE ($1, MulOp, $3) }
  | arith_bin SLASH arith_bin { BinE ($1, DivOp, $3) }
  | arith_bin PLUS arith_bin { BinE ($1, AddOp, $3) }
  | arith_bin MINUS arith_bin { BinE ($1, SubOp, $3) }
  | arith_bin EQ arith_bin { CmpE ($1, EqOp, $3) }
  | arith_bin NE arith_bin { CmpE ($1, NeOp, $3) }
  | arith_bin LT arith_bin { CmpE ($1, LtOp, $3) }
  | arith_bin GT arith_bin { CmpE ($1, GtOp, $3) }
  | arith_bin LE arith_bin { CmpE ($1, LeOp, $3) }
  | arith_bin GE arith_bin { CmpE ($1, GeOp, $3) }
  | arith_bin AND arith_bin { BinE ($1, AndOp, $3) }
  | arith_bin OR arith_bin { BinE ($1, OrOp, $3) }
  | arith_bin ARROW2 arith_bin { BinE ($1, OrOp, $3) }

arith : arith_bin { $1 }


path : path_ { $1 @@ at () }
path_ :
  | /* empty */ { RootP }
  | path LBRACK arith RBRACK { IdxP ($1, $3) }
  | path dotid { DotP ($1, $2) }


/* Definitions */

def : def_ { $1 @@ at () }
def_ :
  | SYNTAX varid hint_list EQ deftyp
    { SynD ($2, $5, $3) }
  | RELATION relid hint_list COLON typ
    { RelD ($2, $5, $3) }
  | RULE relid ruleid_list COLON exp premise_list
    { RuleD ($2, $3, $5, $6) }
  | VAR varid COLON typ hint_list
    { VarD ($2, $4, $5) }
  | VAR atomid_ COLON typ hint_list
    { atom_vars := VarSet.add $2 !atom_vars;
      VarD ($2 @@ ati 2, $4, $5) }
  | DEF DOLLAR defid COLON typ hint_list
    { DecD ($3, SeqE [] @@ ati 4, $5, $6) }
  | DEF DOLLAR defid exp_prim COLON typ hint_list
    { DecD ($3, $4, $6, $7) }
  | DEF DOLLAR defid EQ exp
    { DefD ($3, SeqE [] @@ ati 4, $5) }
  | DEF DOLLAR defid exp_prim EQ exp
    { DefD ($3, $4, $6) }

ruleid_list :
  | /* empty */ { [] }
  | SLASH ruleid ruleid_list { $2::$3 }
  | MINUS ruleid ruleid_list { $2::$3 }

premise_list :
  | /* empty */ { [] }
  | DASH premise premise_list { $2::$3 }

premise : premise_ { $1 @@ at () }
premise_ :
  | relid COLON exp { RulePr ($1, $3, None) }
  | IFF COLON exp { IffPr ($3, None) }
  | OTHERWISE { ElsePr }
  | LPAR relid COLON exp RPAR iter { RulePr ($2, $4, Some $6) }
  | LPAR IFF COLON exp RPAR iter { IffPr ($4, Some $6) }

hint : hint_ { $1 @@ at () }
hint_ :
  | HINT LPAR hintid exp RPAR { {hintid = $3 @@ ati 3; hintexp = $4} }

hint_list :
  | /* empty */ { [] }
  | hint hint_list { $1::$2 }


/* Scripts */

def_list :
  | /* empty */ { [] }
  | def def_list { $1::$2 }

script :
  | def_list EOF { $1 }

%%
