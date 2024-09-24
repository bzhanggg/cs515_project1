open TokenTypes
open String

(*type token =
  | Tok_RParen
  | Tok_LParen
  | Tok_Equal
  | Tok_NotEqual
  | Tok_Greater
  | Tok_Less
  | Tok_GreaterEqual
  | Tok_LessEqual
  | Tok_Or
  | Tok_And
  | Tok_Not
  | Tok_If
  | Tok_Then
  | Tok_Else
  | Tok_Add
  | Tok_Sub
  | Tok_Mult
  | Tok_Div
  | Tok_Concat
  | Tok_Let
  | Tok_Rec
  | Tok_In
  | Tok_Def
  | Tok_Fun
  | Tok_Arrow
  | Tok_Int of int
  | Tok_Bool of bool
  | Tok_String of string
  | Tok_ID of string
  | Tok_DoubleSemi*)
(* Part 1: Lexer - IMPLEMENT YOUR CODE BELOW *)
let re_rparen = Str.regexp ")";;
let re_lparen = Str.regexp "(";;
let re_equal = Str.regexp "=";;
let re_not_equal = Str.regexp "<>";;
let re_greater = Str.regexp ">";;
let re_less = Str.regexp "<";;
let re_greater_equal = Str.regexp ">=";;
let re_less_equal = Str.regexp "<=";;
let re_or = Str.regexp "||";;
let re_and = Str.regexp "&&";;
let re_not = Str.regexp "not";;
let re_if = Str.regexp "if";;
let re_then = Str.regexp "then";;
let re_else = Str.regexp "else";;
let re_add = Str.regexp "+";;
let re_sub = Str.regexp "-";;
let re_mult = Str.regexp "*";;
let re_div = Str.regexp "/"
let re_concat = Str.regexp "\\^";;
let re_let = Str.regexp "let";;
let re_rec = Str.regexp "rec";;
let re_in = Str.regexp "in";;
let re_def = Str.regexp "def";;
let re_fun = Str.regexp "fun";;
let re_arrow = Str.regexp "->";;
let re_pos_int = Str.regexp "[0-9]+";;
let re_neg_int = Str.regexp "(-[0-9]+)";;
let re_bool = Str.regexp "(true\\|false)";;
let re_string = Str.regexp "\"[^\"]*\"";;
let re_id = Str.regexp "[a-zA-Z][a-zA-Z0-9]*";;
let re_double_semi = Str.regexp ";;";;
let re_whitespace = Str.regexp "[ \t\n]+";;
let negative_num = Str.regexp "-[0-9]+"

(*Fix this to correctly calculate the position change for each type of token. Also go back and read the Part 1 description to figure out edge cases.*)
let tokenize input =
  let rec tok pos s =
    if pos >= String.length s then
      []
    else
      if (Str.string_match re_neg_int s pos) then
        let token = Str.matched_string s in
        let substring = sub token 1 ((length token) - 2) in
        (Tok_Int (int_of_string substring))::(tok (pos + (length token)) s)
      else if (Str.string_match re_rparen s pos) then
        Tok_RParen::(tok (pos + 1) s)
      else if (Str.string_match re_lparen s pos) then
        Tok_LParen::(tok (pos + 1) s)
      else if (Str.string_match re_equal s pos) then
        Tok_Equal::(tok (pos + 1) s)
      else if (Str.string_match re_not_equal s pos) then
        Tok_NotEqual::(tok (pos + 2) s)
      else if (Str.string_match re_greater_equal s pos) then
        Tok_GreaterEqual::(tok (pos + 2) s)
      else if (Str.string_match re_less_equal s pos) then
        Tok_LessEqual::(tok (pos + 2) s)
      else if (Str.string_match re_greater s pos) then
        Tok_Greater::(tok (pos + 1) s)
      else if (Str.string_match re_less s pos) then
        Tok_Less::(tok (pos + 1) s)
      else if (Str.string_match re_or s pos) then
        Tok_Or::(tok (pos + 2) s)
      else if (Str.string_match re_and s pos) then
        Tok_And::(tok (pos + 2) s)
      else if (Str.string_match re_add s pos) then
        Tok_Add::(tok (pos + 1) s)
      else if (Str.string_match re_arrow s pos) then
        Tok_Arrow::(tok (pos + 2) s)
      else if (Str.string_match re_sub s pos) then
        Tok_Sub::(tok (pos + 1) s)
      else if (Str.string_match re_mult s pos) then
        Tok_Mult::(tok (pos + 1) s)
      else if (Str.string_match re_div s pos) then
        Tok_Div::(tok (pos + 1) s)
      else if (Str.string_match re_concat s pos) then
        Tok_Concat::(tok (pos + 1) s)
      else if (Str.string_match re_id s pos) then
        let token = Str.matched_string s in
        match token with
        | "not" -> Tok_Not::(tok (pos + 3) s)
        | "if" -> Tok_If::(tok (pos + 2) s)
        | "then" -> Tok_Then::(tok (pos + 4) s)
        | "else" -> Tok_Else::(tok (pos + 4) s)
        | "let" -> Tok_Let::(tok (pos + 3) s)
        | "rec" -> Tok_Rec::(tok (pos + 3) s)
        | "in" -> Tok_In::(tok (pos + 2) s)
        | "def" -> Tok_Def::(tok (pos + 3) s)
        | "fun" -> Tok_Fun::(tok (pos + 3) s)
        | "true" ->
          let token = Str.matched_string s in
          (Tok_Bool (bool_of_string token))::(tok (pos + (length token)) s)
        | "false" ->
          let token = Str.matched_string s in
          (Tok_Bool (bool_of_string token))::(tok (pos + (length token)) s)
        | _ -> (Tok_ID token)::(tok (pos + (length token)) s)
      else if (Str.string_match re_pos_int s pos) then
        let token = Str.matched_string s in
        (Tok_Int (int_of_string token))::(tok (pos + (length token)) s)
      else if (Str.string_match re_string s pos) then
        let token = Str.matched_string s in
        let substring = sub token 1 ((length token) - 2) in
        (Tok_String substring)::(tok (pos + (length token)) s)
      else if (Str.string_match re_double_semi s pos) then
        Tok_DoubleSemi::(tok (pos + 2) s)
      else if (Str.string_match re_whitespace s pos) then
        let whitespace = Str.matched_string s in
        (tok (pos + (length whitespace)) s)
      else
        raise (InvalidInputException "Invalid Token")
      in
      tok 0 input
