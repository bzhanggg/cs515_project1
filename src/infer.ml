open MicroCamlTypes

(*******************************************************************|
|**********************   Environment   ****************************|
|*******************************************************************|
| - The environment is a map that holds type information of         |
|   variables                                                       |
|*******************************************************************)
type environment = (var * typeScheme) list

exception OccursCheckException

exception UndefinedVar

exception TypeError

type substitutions = (string * typeScheme) list

let type_variable = ref (Char.code 'a')

(* generates a new unknown type placeholder.
   returns T(string) of the generated alphabet *)
let gen_new_type () =
  let c1 = !type_variable in
  incr type_variable; T(Char.escaped (Char.chr c1))
;;

let string_of_constraints (constraints: (typeScheme * typeScheme) list) =
  List.fold_left (fun acc (l, r) -> Printf.sprintf "%s%s = %s\n" acc (string_of_type l) (string_of_type r)) "" constraints

let string_of_subs (subs: substitutions) =
  List.fold_left (fun acc (s, t) -> Printf.sprintf "%s%s: %s\n" acc s (string_of_type t)) "" subs

(******************************************************************|
|**********************   Unification   ***************************|
|**********************    Algorithm    ***************************|
|******************************************************************)


(******************************************************************|
|**********************   Substitute   ****************************|
|******************************************************************|
|Arguments:                                                        |
|   t -> type in which substitutions have to be made.              |
|   (x, u) -> (type placeholder, resolved substitution)            |
|******************************************************************|
|Returns:                                                          |
|   returns a valid substitution for t if present, else t as it is.|
|******************************************************************|
|- In this method we are given a substitution rule that asks us to |
|  replace all occurrences of type placeholder x with u, in t.     |
|- We are required to apply this substitution to t recursively, so |
|  if t is a composite type that contains multiple occurrences of  |
|  x then at every position of x, a u is to be substituted.        |
*******************************************************************)
let rec substitute (u: typeScheme) (x: string) (t: typeScheme) : typeScheme =
  match t with
  | TNum | TBool | TStr -> t
  | T(c) -> if c = x then u else t
  | TFun(t1, t2) -> TFun(substitute u x t1, substitute u x t2)
  | TPoly(vars, t') ->
    if List.mem x vars then t
    else TPoly(vars, substitute u x t')
;;

(******************************************************************|
|*************************    Apply    ****************************|
|******************************************************************|
| Arguments:                                                       |
|   subs -> list of substitution rules.                            |
|   t -> type in which substitutions have to be made.              |
|******************************************************************|
| Returns:                                                         |
|   returns t after all the substitutions have been made in it     |
|   given by all the substitution rules in subs.                   |
|******************************************************************|
| - Works from right to left                                       |
| - Effectively what this function does is that it uses            |
|   substitution rules generated from the unification algorithm and|
|   applies it to t. Internally it calls the substitute function   |
|   which does the actual substitution and returns the resultant   |
|   type after substitutions.                                      |
| - Substitution rules: (type placeholder, typeScheme), where we   |
|   have to replace each occurrence of the type placeholder with   |
|   the given type t.                                              |
|******************************************************************)
let apply (subs: substitutions) (t: typeScheme) : typeScheme =
  List.fold_right (fun (x, u) t -> substitute u x t) subs t
;;

(******************************************************************|
|****************   Polymorphic Type Inference   ******************|
|******************************************************************)

(* create polymorphic type by replacing all variables with fresh types*)
let rec instantiate (ty_scheme: typeScheme) : typeScheme =
  match ty_scheme with
  | TPoly(vars, t) ->
    let subst = List.map (fun v -> (v, gen_new_type ())) vars in
    List.fold_left (fun acc (v, fresh_ty) -> substitute fresh_ty v acc) t subst
  | _ -> ty_scheme
;;

(* get free type variables from a type *)
let rec free_type_vars (t: typeScheme) : string list =
  match t with
  | TNum | TBool | TStr -> []
  | T x -> [x]
  | TFun(t1, t2) -> (free_type_vars t1) @ (free_type_vars t2)
  | TPoly(vars, t') -> List.filter (fun v -> not (List.mem v vars)) (free_type_vars t')
;;

let free_vars_in_env (env: environment) : string list =
  List.fold_left (fun acc (_, ty) -> acc @ free_type_vars ty) [] env
;;

(* quantify free type variables *)
let generalize (env: environment) (t: typeScheme) : typeScheme = 
  let env_vars = free_vars_in_env env in
  let free_vars = free_type_vars t in
  let to_generalize = List.filter (fun v -> not (List.mem v env_vars)) free_vars in
  if to_generalize = [] then t
  else TPoly(to_generalize, t)
;;

(******************************************************************|
|***************************   Unify   ****************************|
|******************************************************************|
| Arguments:                                                       |
|   constraints -> list of constraints (tuple of 2 types)          |
|******************************************************************|
| Returns:                                                         |
|   returns a list of substitutions                                |
|******************************************************************|
| - The unify function takes a bunch of constraints it obtained    |
|   from the collect method and turns them into substitutions.     |
| - In the end we get a complete list of substitutions that helps  |
|   resolve types of all expressions in our program.               |
|******************************************************************)

(* Occurs check helper *)
let rec occurs_check (x: string) (t: typeScheme) : bool =
  match t with
  | TNum | TBool | TStr -> false
  | T y -> x = y
  | TFun(t1, t2) -> occurs_check x t1 || occurs_check x t2
  | TPoly(vars, t') ->
    if List.mem x vars then true
    else occurs_check x t'
;;

let rec update_subs (subs: substitutions) (a: string) (t: typeScheme) : substitutions =
  List.map (fun (x, u) -> 
    let x' = if x = a then string_of_type t else x in
    let u' = substitute t a u in
    (x', u')
  ) subs
;;

let rec unify_cons (constraints: (typeScheme * typeScheme) list) : substitutions =
  match constraints with
  | [] -> []
  | (TBool, TBool) :: constraints' | (TNum, TNum) :: constraints' | (TStr, TStr) :: constraints' -> unify_cons constraints'
  | (TFun (a, b), TFun (c, d)) :: constraints' -> unify_cons ((a, c) :: (b, d) :: constraints')
  | (T a, t) :: constraints' | (t, T a) :: constraints' ->
    if t = T a then unify_cons constraints'
    else if occurs_check a t then raise OccursCheckException
    else
      let constraints'' = List.map(fun (t1, t2) -> (substitute t a t1, substitute t a t2)) constraints' in (a, t) :: (unify_cons constraints'')
  | _ -> failwith "Unification failed"
;;

let rec unify_subs (subs : substitutions) (constraints: (typeScheme * typeScheme) list) : substitutions =
  match unify_cons constraints with
  | [] -> subs
  | new_subs ->
    let updated_subs = List.fold_left (fun acc (a, t) ->
      let updated = List.map (fun (x, u) -> (x, substitute t a u)) acc in
      (a, t) :: updated
    ) subs new_subs in
    let substituted_constraints = List.map (fun (t1, t2) ->
      List.fold_left (fun (t1', t2') (a, t) -> (substitute t a t1' , substitute t a t2')) (t1, t2) updated_subs
    ) constraints in
    unify_subs updated_subs substituted_constraints
;;

let unify (constraints: (typeScheme * typeScheme) list) : substitutions = unify_subs [] constraints;;

(*********************************************************************|
|******************   Annotate Expressions   *************************|
|*********************************************************************|
| Arguments:                                                          |
|   env -> A typing environment                                       |
|   e -> An expression that has to be annotated                       |
|*********************************************************************|
| Returns:                                                            |
|   returns an annotated expression of type aexpr that holds          |
|   type information for the given expression e.                      |
|   and the type of e                                                 |
|   and a list of typing constraints.                                 |
|*********************************************************************|
| - This method takes every expression/sub-expression in the          |
|   program and assigns some type information to it.                  |
| - This type information maybe something concrete like a TNum        |
|   or it could be a unique parameterized type(placeholder) such      |
|   as 'a.                                                            |
| - Concrete types are usually assigned when you encounter            |
|   simple literals like 10, true and "hello"                         |
| - Whereas, a random type placeholder is assigned when no            |
|   explicit information is available.                                |
| - The algorithm not only infers types of variables and              |
|   functions defined by user but also of every expression and        |
|   sub-expression since most of the inference happens from           |
|   analyzing these expressions only.                                 |
| - A constraint is a tuple of two typeSchemes. A strict equality     |
|   is being imposed on the two types.                                |
| - Constraints are generated from the expresssion being analyzed,    |
|   for e.g. for the expression ABinop(x, Add, y, t) we can constrain |
|   the types of x, y, and t to be TNum.                              |
| - In short, most of the type checking rules will be added here in   |
|   the form of constraints.                                          |
| - Further, if an expression contains sub-expressions, then          |
|   constraints need to be obtained recursively from the              |
|   subexpressions as well.                                           |
| - Lastly, constraints obtained from sub-expressions should be to    |
|   the left of the constraints obtained from the current expression  |
|   since constraints obtained from current expression holds more     |
|   information than constraints from subexpressions and also later   |
|   on we will be working with these constraints from right to left.  |
|*********************************************************************)
let rec gen (env: environment) (e: expr): aexpr * typeScheme * (typeScheme * typeScheme) list =
  match e with
  | Int n -> AInt(n, TNum), TNum, []
  | Bool b -> ABool(b, TBool), TBool, []
  | String s -> AString(s, TStr), TStr, []
  | ID x ->
    if List.mem_assoc x env
    then
      let t = instantiate (List.assoc x env) in
      AID(x, t), t, []
    else raise UndefinedVar
  | Fun(id, e) ->
    let tid = gen_new_type () in
    let rty = gen_new_type () in
    let env' = (id, tid)::env in
    let ae, t, q = gen env' e in
    (*let t = List.assoc id env in
    let _ = List.iter (fun k v -> print_string k; print_string " "; print_string (string_of_type v); print_string "\n") env in
    let _ = print_string id; print_string " "; print_string (string_of_type t); print_string ("\n") in*)
    let q' = [(t, rty)] in
    AFun(id, ae, TFun(tid, rty)), TFun(tid, rty), q @ q'
  | Not e ->
    let ae, t1, q = gen env e in
    ANot(ae, TBool), TBool, q @ [(t1, TBool)]
  | Binop(op, e1, e2) ->
    let et1, t1, q1 = gen env e1
    and et2, t2, q2 = gen env e2 in
    (* impose constraints based on binary operator *)
    let opc, t = match op with
      | Add | Sub | Mult | Div -> [(t1, TNum); (t2, TNum)], TNum
      | Concat -> [(t1, TStr); (t2, TStr)], TStr
      (* we return et1, et2 since these are generic operators *)
      | Greater | Less | GreaterEqual | LessEqual | Equal | NotEqual -> [(t1, t2)], TBool
      | And | Or -> [(t1, TBool); (t2, TBool)], TBool
    in
    (* opc appended at the rightmost since we apply substitutions right to left *)
    ABinop(op, et1, et2, t), t, q1 @ q2 @ opc
  | If (e1, e2, e3) ->
    let ae1, t1, q1 = gen env e1 in
    let ae2, t2, q2 = gen env e2 in
    let ae3, t3, q3 = gen env e3 in
    AIf (ae1, ae2, ae3, t2), t2, q1 @ q2 @ q3 @ [(t1, TBool); (t2, t3)]
  | FunctionCall(fn, arg) ->
    let afn, fnty, fnq = gen env fn in
    let aarg, argty, argq = gen env arg in
    let t = gen_new_type () in
    let q = fnq @ argq @ [(fnty, TFun(argty, t))] in
    AFunctionCall(afn, aarg, t), t, q
  | Let (id, b, e1, e2) ->
    let ae1, t1, q1 =
      if b then
        let tid = gen_new_type () in
        let env' = (id, tid)::env in
        gen env' e1
      else
        gen env e1 in
    let env_unify = List.map(fun (var, t) -> (var, apply (unify q1) t)) env in 
    let t1' = if b then t1 else generalize env_unify (apply (unify q1) t1) in
    let env'' = (id, t1')::env in
    let ae2, t2, q2 = gen env'' e2 in
    ALet (id, b, ae1, ae2, t2), t2, q1 @ q2
;;

(* applies a final set of substitutions on the annotated expr *)
let rec apply_expr (subs: substitutions) (ae: aexpr): aexpr =
  match ae with
  | ABool(b, t) -> ABool(b, apply subs t)
  | AInt(n, t) -> AInt(n, apply subs t)
  | AString(s, t) -> AString(s, apply subs t)
  | AID(s, t) -> AID(s, apply subs t)
  | AFun(id, e, t) -> AFun(id, apply_expr subs e, apply subs t)
  | ANot(e, t) -> ANot(apply_expr subs e, apply subs t)
  | ABinop(op, e1, e2, t) -> ABinop(op, apply_expr subs e1, apply_expr subs e2, apply subs t)
  | AIf(e1, e2, e3, t) -> AIf(apply_expr subs e1, apply_expr subs e2, apply_expr subs e3, apply subs t)
  | AFunctionCall(fn, arg, t) -> AFunctionCall(apply_expr subs fn, apply_expr subs arg, apply subs t)
  | ALet(id, b, e1, e2, t) -> ALet(id, b, apply_expr subs e1, apply_expr subs e2, apply subs t)
;;

(* 1. annotate expression with placeholder types and generate constraints
   2. unify types based on constraints *)
let infer (e: expr) : typeScheme =
  let env = [] in
  let ae, t, constraints = gen env e in
  (*let _ = print_string "\n"; print_string (string_of_constraints constraints) in
  let _ = print_string "\n"; print_string (string_of_aexpr ae) in *)
  let subs = unify constraints in
  type_variable := (Char.code 'a');
  (* let _ = print_string "\n"; print_string (string_of_subs subs) in *)
  (* reset the type counter after completing inference *)
  (* Printf.printf "Subs: %s\n" (string_of_subs subs); *)
  let inferred_type = apply subs t in 
  (* apply_expr subs annotated_expr *)
  (* Printf.printf "Inferred type: %s\n" (string_of_type inferred_type); *)
  inferred_type
;;
