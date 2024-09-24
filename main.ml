open Lexer
open Parser
open Infer
open MicroCamlTypes
open TokenTypes

let _ = Printexc.record_backtrace(true)

(* Simple expressions *)

let public_expr_single_fun_type _ =
  (* fun x -> x + 1 *)
  (*let prog = (Fun ("x", Binop (Add, ID "x", (Int 1)))) in*)
  let _, prog = "fun x -> x + 1" |> tokenize |> parse_expr in
  let result = TFun(TNum, TNum) in
  let student = infer prog in
  assert (student = result)

let public_expr_add1_type _ =
  (* let add1 = fun x -> x + 1 in add1 *)
  (*let prog = (Let ("add1", false, Fun ("x", Binop (Add, ID "x", (Int 1))), ID "add1")) in*)
  let _, prog = "let add1 = fun x -> x + 1 in add1" |> tokenize |> parse_expr in
  let result = TFun (TNum, TNum) in
  let student = infer prog in
  assert (student = result)

let public_expr_apply_type _ =
  (* let apply = fun x -> fun y -> x y in let add1 = fun z -> z + 1 in (apply add1) 5 *)
  (*let prog = (Let ("apply", false, Fun ("x", Fun ("y", FunctionCall (ID "x", ID "y"))),
   Let ("add1", false, Fun ("z", Binop (Add, ID "z", (Int 1))),
    FunctionCall (FunctionCall (ID "apply", ID "add1"), (Int 5))))) in*)
  let _, prog = "let apply = fun x -> fun y -> x y in let add1 = fun z -> z + 1 in (apply add1) 5" |> tokenize |> parse_expr in
  let result = TNum in
  let student = infer prog in
  assert (student = result)

let public_expr_double_fun_type _ =
  (* fun x -> fun y -> x + y *)
  (*let prog = (Fun ("x", Fun ("y", Binop (Add, ID "x", ID "y")))) in*)
  let _, prog = "fun x -> fun y -> x + y" |> tokenize |> parse_expr in
  let result = TFun(TNum, TFun(TNum, TNum)) in
  let student = infer prog in
  assert (student = result)

let public_expr_let_fun_type _ =
  (* let abc = fun a -> a + 1 in abc 1 *)
  (*let prog = (Let ("abc", false, Fun ("a", Binop (Add, ID "a", (Int 1))),
    FunctionCall (ID "abc", (Int 1)))) in*)
  let _, prog = "let abc = fun a -> a + 1 in abc 1" |> tokenize |> parse_expr in
  let result = TNum in
  let student = infer prog in
  assert (student = result)

let public_expr_sub1_type _ =
  (* let sub1 = fun x -> x - 1 in sub1 *)
  (*let prog = (Let ("sub1", false, Fun ("x", Binop (Sub, ID "x", (Int 1))), ID "sub1")) in*)
  let _, prog = "let sub1 = fun x -> x - 1 in sub1" |> tokenize |> parse_expr in
  let result = TFun(TNum, TNum) in
  let student = infer prog in
  assert (student = result)

let public_expr_fact_type _ =
  (*let prog = (Let ("f", true,
                  Fun("x", If (Binop(NotEqual, ID "x", Int 0), Int 1, Binop(Mult, ID "x", FunctionCall(ID "f", Binop(Sub, ID "x", Int 1))))),
                  FunctionCall(ID "f", Int 5))) in*)
  let _, prog = "let rec f = fun x -> if x <= 0 then 1 else x * f(x-1) in f 5" |> tokenize |> parse_expr in
  let result = TNum in
  let student = infer prog in
  assert (student = result)

(* Higher-order functions *)

let public_expr_ho_type _ =
  (* fun x -> x 1 *)
  (*let prog = (Fun("x", FunctionCall(ID "x", Int 1))) in*)
  let _, prog = "fun x -> x 1" |> tokenize |> parse_expr in
  let a = gen_new_type() in
  (* (int -> 'a) -> 'a *)
  let result = pp_string_of_type (TFun(TFun(TNum, a), a)) in
  let student = pp_string_of_type (infer prog) in
  assert (student = result)

let public_expr_ho2_type _ =
  (* fun a -> (fun b -> a(a b)) *)
  (*let prog = (Fun("a", Fun("b", FunctionCall(ID "a", FunctionCall(ID "a", ID "b"))))) in*)
  let _, prog = "fun a -> (fun b -> a(a b))" |> tokenize |> parse_expr in
  let a = gen_new_type() in
  (* ('a -> 'a) -> 'a -> 'a *)
  let result = pp_string_of_type (TFun(TFun(a, a), TFun(a, a))) in
  let student = pp_string_of_type (infer prog) in
  assert (student = result)

let public_expr_ho3_type _ =
  (* fun c -> (fun d -> (fun e -> e c d)) *)
  (*let prog = (Fun("c", Fun("d", Fun ("e", FunctionCall(FunctionCall(ID "e", ID "c"), ID "d"))))) in*)
  let _, prog = "fun c -> (fun d -> (fun e -> (e c) d))" |> tokenize |> parse_expr in
  let a = gen_new_type() in
  let b = gen_new_type() in
  let c = gen_new_type() in
  (* 'a -> 'b -> ('a -> 'b -> 'c) -> 'c *)
  let result = pp_string_of_type (TFun(a, TFun(b, TFun(TFun(a, TFun(b, c)), c)))) in
  let student = pp_string_of_type (infer prog) in
  assert (student = result)

let public_expr_hoapp_type _ =
  (* (fun x -> x 1) (fun x -> x + 1) *)
  (*let prog = (FunctionCall(Fun("x", FunctionCall(ID "x", Int 1)), Fun("x", Binop(Add, ID "x", Int 1)))) in*)
  let _, prog = "(fun x -> x 1) (fun x -> x + 1)" |> tokenize |> parse_expr in
  let result = TNum in
  let student = infer prog in
  assert (student = result)

let public_expr_hoapp2_type _ =
  (* (fun a -> (fun b -> a(a b))) (fun c -> (fun d -> (fun e -> e c d))) *)
  (*let prog = FunctionCall (Fun("a", Fun("b", FunctionCall(ID "a", FunctionCall(ID "a", ID "b")))), Fun("c", Fun("d", Fun ("e", FunctionCall(FunctionCall(ID "e", ID "c"), ID "d"))))) in*)
  let _, prog = "(fun a -> (fun b -> a(a b))) (fun c -> (fun d -> (fun e -> (e c) d)))" |> tokenize |> parse_expr in
  try
    let _ = infer prog in
    assert false
  with OccursCheckException -> (type_variable := (Char.code 'a')) | _ -> (type_variable := (Char.code 'a'); assert (1 = 0))

let public_expr_xx_type _ =
  (*let prog = (Fun("x", FunctionCall(ID "x", ID "x"))) in*)
  let _, prog = "fun x -> x x" |> tokenize |> parse_expr in
  try
    let _ = infer prog in
    assert false
  with OccursCheckException -> (type_variable := (Char.code 'a')) | _ -> (type_variable := (Char.code 'a'); assert (1 = 0))

let public_expr_xx_type_2 _  =
  (* fun f -> (fun x -> f x x) (fun y -> f y y) *)
  let prog = Fun("f", FunctionCall(Fun ("x", FunctionCall(FunctionCall(ID "f", ID "x"), ID "x")), Fun ("y", FunctionCall(FunctionCall(ID "f", ID "y"), ID "y")))) in
  try
    let _ = infer prog in
    assert false
  with OccursCheckException -> (type_variable := (Char.code 'a')) | _ -> (type_variable := (Char.code 'a'); assert (1 = 0))

let public_complex_type _ =
  (* let x = 1 in let y = "world" in if x > 1 && y > "hello" then let w = fun z x -> y in w 1 else fun x -> "world" *)
  (*let prog = Let ("x", false , Int 1, Let ("y", false, String "world", If (Binop(And, Binop(Greater, ID "x", Int 1), Binop(Equal, ID "y", String "Hello")),
              Let("w", false, Fun ("z", Fun ("x", ID "y")), FunctionCall(ID "w", Int 1)), Fun("x", String "world")
  ))) in*)
  let _, prog = "let x = 1 in let y = \"world\" in if x > 1 && y = \"Hello\" then let w = fun z -> fun x -> y in w 1 else fun x -> \"world\"" |> tokenize |> parse_expr in
  let a = gen_new_type() in
  let result = pp_string_of_type(TFun (a, TStr)) in
  let student = pp_string_of_type (infer prog) in
  assert (student = result)


let public_constraint_solving _ =
  let e = (FunctionCall(Fun("x", FunctionCall(ID "x", Int 1)), Fun("x", Binop(Add, ID "x", Int 1)))) in
  let _, _, constraints = gen [] e in
  let student =  unify constraints in
  let result = [("f", TNum); ("c", TNum); ("d", TNum); ("e", TNum); ("a", TFun(TNum, TNum)); ("b", TNum)] in
  let f x y = if x < y then -1 else if x = y then 0 else 1 in
  assert (List.sort f student = List.sort f result)

let public_constraint_solving_1 _ =
  let constraints = [
    (TFun(T "p", TFun(T "p", T "q")), TFun(T "q", TFun(T "r", TNum)))
  ] in
  let student =  unify constraints in
  let result = [("p", TNum); ("q", TNum); ("r", TNum)] in
  let f x y = if x < y then -1 else if x = y then 0 else 1 in
  assert (List.sort f student = List.sort f result)

let public_constraint_solving_2 _ =
  let constraints = [
    (T "a", TFun(TNum, T "d"));
    (TNum, T "b");
    (T "d", TNum);
    (TNum, T "c");
    (TFun(T "b", T "c"), TFun(TNum, T "e"))
  ] in
  let student =  unify constraints in
  let result = [("c", TNum); ("d", TNum); ("e", TNum); ("a", TFun(TNum, TNum)); ("b", TNum)] in
  let f x y = if x < y then -1 else if x = y then 0 else 1 in
  assert (List.sort f student = List.sort f result)

(* Polymorphic expressions *)

let public_poly_1 _ =
  (*let prog = Let ("f", false, Fun("x", ID "x"), Let ("s", false, FunctionCall(ID "f", Int 1), FunctionCall(ID "f", String "hello"))) in*)
  let _, prog = "let f = fun x -> x in let s = f 1 in f \"Hello World!\"" |> tokenize |> parse_expr in
  let result = TStr in
  let student = infer prog in
  assert (student = result)

let public_poly_2 _ =
  let _, prog = "let f = fun x -> x 1 in let s = f (fun y -> \"Hello World!\") in f (fun x -> x + 1)" |> tokenize |> parse_expr in
  let result = TNum in
  let student = infer prog in
  assert (student = result)

let public_poly_3 _ =
  let _, prog = "fun x -> let f = fun y -> x in let s = f 1 in f true" |> tokenize |> parse_expr in
  let a = gen_new_type() in
  (* 'a -> 'a *)
  let result = pp_string_of_type (TFun(a, a)) in
  let student = pp_string_of_type (infer prog) in
  assert (student = result)


(*********************)
(* Testing your code *)
(*********************)

let _ = print_string ("Testing your code ...\n")

let error_count = ref 0

let main () =

  (*********************************)
  (* Test cases for type inference *)
  (*********************************)

  let _ = try public_expr_single_fun_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in

  let _ = try public_expr_add1_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_apply_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_double_fun_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_let_fun_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_sub1_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_fact_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in

  let _ = try public_expr_ho_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_ho2_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_ho3_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_hoapp_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_hoapp2_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_xx_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_expr_xx_type_2()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_complex_type()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in

  let _ = try public_constraint_solving()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_constraint_solving_1()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_constraint_solving_2()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in

  let _ = try public_poly_1()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_poly_2()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in
  let _ = try public_poly_3()
    with e -> (error_count := !error_count + 1;
    let msg = Printexc.to_string e and stack = Printexc.get_backtrace () in
    Printf.eprintf "there was an error: %s %s\n" msg stack) in


  if !error_count = 0 then  Printf.printf ("Passed all testcases.\n")
  else Printf.printf ("%d out of 21 programming questions are incorrect.\n") (!error_count)

let _ = main()
