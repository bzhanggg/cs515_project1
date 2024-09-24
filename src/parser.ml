open MicroCamlTypes
open Utils
open TokenTypes

(* Provided functions - DO NOT MODIFY *)

(* Matches the next token in the list, throwing an error if it doesn't match the given token *)
let match_token (toks: token list) (tok: token) =
  match toks with
  | [] -> raise (InvalidInputException(string_of_token tok))
  | h::t when h = tok -> t
  | h::_ -> raise (InvalidInputException(
      Printf.sprintf "Expected %s from input %s, got %s"
        (string_of_token tok)
        (string_of_list string_of_token toks)
        (string_of_token h)))

(* Matches a sequence of tokens given as the second list in the order in which they appear, throwing an error if they don't match *)
let match_many (toks: token list) (to_match: token list) =
  List.fold_left match_token toks to_match

(* Return the next token in the token list as an option *)
let lookahead (toks: token list) =
  match toks with
  | [] -> None
  | h::t -> Some h

(* Return the token at the nth index in the token list as an option*)
let rec lookahead_many (toks: token list) (n: int) =
  match toks, n with
  | h::_, 0 -> Some h
  | _::t, n when n > 0 -> lookahead_many t (n-1)
  | _ -> None

(* Part 2: Parsing expressions *)
let getInt toks =
  match toks with
  [] -> raise (InvalidInputException "Empty Token List")
  | h::t -> (match h with
    Tok_Int s -> s
    | _ -> raise (InvalidInputException "No matching token"))

let getBool toks =
  match toks with
  [] -> raise (InvalidInputException "Empty Token List")
  | h::t -> (match h with
    Tok_Bool s -> s
    | _ -> raise (InvalidInputException "No matching token"))

let getString toks =
  match toks with
  [] -> raise (InvalidInputException "Empty Token List")
  | h::t -> (match h with
    Tok_ID s -> s
    | Tok_String s -> s
    | _ -> raise (InvalidInputException "No matching token"))

let rec parse_expr toks =
  let ltoken = lookahead toks in
  if ltoken = Some Tok_Let then
    parse_LetExpr toks
  else if ltoken = Some Tok_If then
    parse_IfExpr toks
  else if ltoken = Some Tok_Fun then
    parse_FunctionExpr toks
  else
    parse_OrExpr toks
and parse_LetExpr toks =
  let tokens = match_token toks Tok_Let in
  let (rec_toks, rec_or_not) = parse_Recursion tokens in
  let tokens = rec_toks in
  let id = getString tokens in
  let tokens = match_token tokens (Tok_ID (getString tokens))in
  let tokens = match_token tokens Tok_Equal in
  let (expr1_toks, expression1) = parse_expr tokens in
  let tokens = expr1_toks in
  let tokens = match_token tokens Tok_In in
  let (expr2_toks, expression2) = parse_expr tokens in
  let tokens = expr2_toks in
  (tokens, Let (id, rec_or_not, expression1, expression2))
and parse_Recursion toks =
  match lookahead toks with
  Some Tok_Rec -> ((match_token toks Tok_Rec), true)
  | _ -> (toks, false)
and parse_FunctionExpr toks =
  let tokens = match_token toks Tok_Fun in
  let id = getString tokens in
  let tokens = match_many tokens [(Tok_ID (getString tokens)); Tok_Arrow;] in
  let (expr1_toks, expression1) = parse_expr tokens in
  (expr1_toks, Fun (id, expression1))
and parse_IfExpr toks =
  let tokens = match_token toks Tok_If in
  let (expr1_toks, expression1) = parse_expr tokens in
  let tokens = match_token expr1_toks Tok_Then in
  let (expr2_toks, expression2) = parse_expr tokens in
  let tokens = match_token expr2_toks Tok_Else in
  let (expr3_toks, expression3) = parse_expr tokens in
  (expr3_toks, If (expression1, expression2, expression3))
and parse_OrExpr toks =
  let (and_toks, and_expr) = parse_AndExpr toks in
  match lookahead and_toks with
  Some Tok_Or ->
    let tokens = match_token and_toks Tok_Or in
    let (ref_toks, ref_expr) = parse_OrExpr tokens in
    (ref_toks, Binop (Or, and_expr, ref_expr))
 |  _ -> (and_toks, and_expr)
and parse_AndExpr toks =
  let (eq_toks, eq_expr) = parse_EqualityExpr toks in
  match lookahead eq_toks with
  Some Tok_And ->
    let tokens = match_token eq_toks Tok_And in
    let (ref_toks, ref_expr) = parse_AndExpr tokens in
    (ref_toks, Binop (And, eq_expr, ref_expr))
  | _ -> (eq_toks, eq_expr)
and parse_EqualityExpr toks =
  let (rel_toks, rel_expr) = parse_RelationalExpr toks in
  match lookahead rel_toks with
  Some Tok_Equal ->
    let tokens = match_token rel_toks Tok_Equal in
    let (ref_toks, ref_expr) = parse_EqualityExpr tokens in
    (ref_toks, Binop (Equal, rel_expr, ref_expr))
  | Some Tok_NotEqual ->
    let tokens = match_token rel_toks Tok_NotEqual in
    let (ref_toks, ref_expr) = parse_EqualityExpr tokens in
    (ref_toks, Binop (NotEqual, rel_expr, ref_expr))
  | _ -> (rel_toks, rel_expr)
and parse_RelationalExpr toks =
  let (add_toks, add_expr) = parse_AdditiveExpr toks in
  match lookahead add_toks with
  Some Tok_Less ->
    let tokens = match_token add_toks Tok_Less in
    let (ref_toks, ref_expr) = parse_RelationalExpr tokens in
    (ref_toks, Binop (Less, add_expr, ref_expr))
  | Some Tok_Greater ->
    let tokens = match_token add_toks Tok_Greater in
    let (ref_toks, ref_expr) = parse_RelationalExpr tokens in
    (ref_toks, Binop (Greater, add_expr, ref_expr))
  | Some Tok_LessEqual ->
    let tokens = match_token add_toks Tok_LessEqual in
    let (ref_toks, ref_expr) = parse_RelationalExpr tokens in
    (ref_toks, Binop (LessEqual, add_expr, ref_expr))
  | Some Tok_GreaterEqual ->
    let tokens = match_token add_toks Tok_GreaterEqual in
    let (ref_toks, ref_expr) = parse_RelationalExpr tokens in
    (ref_toks, Binop (GreaterEqual, add_expr, ref_expr))
  | _ -> (add_toks, add_expr)
and parse_AdditiveExpr toks =
  let (mult_toks, mult_expr) = parse_MultiplicativeExpr toks in
  match lookahead mult_toks with
  Some Tok_Add ->
    let tokens = match_token mult_toks Tok_Add in
    let (ref_toks, ref_expr) = parse_AdditiveExpr tokens in
    (ref_toks, Binop (Add, mult_expr, ref_expr))
  | Some Tok_Sub ->
    let tokens = match_token mult_toks Tok_Sub in
    let (ref_toks, ref_expr) = parse_AdditiveExpr tokens in
    (ref_toks, Binop (Sub, mult_expr, ref_expr))
  | _ -> (mult_toks, mult_expr)
and parse_MultiplicativeExpr toks =
  let (con_toks, con_expr) = parse_ConcatExpr toks in
  match lookahead con_toks with
  Some Tok_Mult ->
    let tokens = match_token con_toks Tok_Mult in
    let (ref_toks, ref_expr) = parse_MultiplicativeExpr tokens in
    (ref_toks, Binop (Mult, con_expr, ref_expr))
  | Some Tok_Div ->
    let tokens = match_token con_toks Tok_Div in
    let (ref_toks, ref_expr) = parse_MultiplicativeExpr tokens in
    (ref_toks, Binop (Div, con_expr, ref_expr))
  | _ -> (con_toks, con_expr)
and parse_ConcatExpr toks =
  let (un_toks, un_expr) = parse_UnaryExpr toks in
  match lookahead un_toks with
  Some Tok_Concat ->
    let tokens = match_token un_toks Tok_Concat in
    let (ref_toks, ref_expr) = parse_ConcatExpr tokens in
    (ref_toks, Binop (Concat, un_expr, ref_expr))
  | _ -> (un_toks, un_expr)
and parse_UnaryExpr toks =
  match lookahead toks with
  Some Tok_Not ->
    let tokens = match_token toks Tok_Not in
    let (ref_toks, ref_expr) = parse_UnaryExpr tokens in
    (ref_toks, Not (ref_expr))
  | _ -> parse_FunctionCallExpr toks
and parse_FunctionCallExpr toks =
  let (prim_toks, prim_expr) = parse_PrimaryExpr toks in
  match lookahead prim_toks with
  Some (Tok_Int i) ->
    let (prim2_toks, prim2_expr) = parse_PrimaryExpr prim_toks in
    (prim2_toks, FunctionCall (prim_expr, prim2_expr))
  | Some (Tok_Bool b) ->
    let (prim2_toks, prim2_expr) = parse_PrimaryExpr prim_toks in
    (prim2_toks, FunctionCall (prim_expr, prim2_expr))
  | Some (Tok_String s)->
    let (prim2_toks, prim2_expr) = parse_PrimaryExpr prim_toks in
    (prim2_toks, FunctionCall (prim_expr, prim2_expr))
  | Some (Tok_ID id) ->
    let (prim2_toks, prim2_expr) = parse_PrimaryExpr prim_toks in
    (prim2_toks, FunctionCall (prim_expr, prim2_expr))
  | Some Tok_LParen ->
    let (prim2_toks, prim2_expr) = parse_PrimaryExpr prim_toks in
    (prim2_toks, FunctionCall (prim_expr, prim2_expr))
  | _ -> (prim_toks, prim_expr)
and parse_PrimaryExpr toks =
  match lookahead toks with
  Some (Tok_Int i) ->
    let expression = (Int (getInt toks)) in
    let tokens = match_token toks (Tok_Int i) in
    (tokens, expression)
  | Some (Tok_Bool b) ->
    let expression = (Bool (getBool toks)) in
    let tokens = match_token toks (Tok_Bool b) in
    (tokens, expression)
  | Some (Tok_String s) ->
    let expression = (String (getString toks)) in
    let tokens = match_token toks (Tok_String s) in
    (tokens, expression)
  | Some (Tok_ID id) ->
    let expression = ID (getString toks) in
    let tokens = match_token toks (Tok_ID id) in
    (tokens, expression)
  | Some Tok_LParen ->
    let tokens = match_token toks Tok_LParen in
    let (ptoks, pexpr) = parse_expr tokens in
    let tokens = match_token ptoks Tok_RParen in
    (tokens, pexpr)
  | _ -> raise (InvalidInputException "No matching token - Primary")
