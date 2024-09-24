
# MicroCaml TypeChecker.


## Introduction

Over the course of this project, you will implement a type checker (type inferencer) for MicroCaml — a subset of OCaml.

### Testing & Submitting

Please submit the entire code as a zip file to Canvas. To test locally, compile your code with `make` and run `./infer`.

All tests will be run on direct calls to your code, comparing your return values to the expected return values. Any other output (e.g., for your own debugging) will be ignored. You are free and encouraged to have additional output.

## Parsing MicroCaml Expressions

We have already provided you the implementation of an parser `parse_expr` for MicroCaml, which takes a stream of tokens and outputs as AST for the input expression of type `expr`. The code is in [parser.ml](./src/parser.ml) in accordance with the signature found in [parser.mli](./src/parser.mli).

We present a quick overview of `parse_expr` first, then the definition of AST types it returns, and finally the grammar it parses.

### `parse_expr`
- **Type:** `token list -> token list * expr`
- **Description:** Takes a list of tokens and returns an AST representing the MicroCaml expression corresponding to the given tokens, along with any tokens left in the token list.
- **Exceptions:** Raise `InvalidInputException` if the input fails to parse i.e does not match the MicroCaml expression grammar.

Here is an example call to the parser on a MicroCaml expression (as a string):

```ocaml
parse_expr (tokenize "let x = true in x")
```

This will return the AST as the following OCaml value (which we will explain in due course):

```ocaml
 Let ("x", false, (Bool true), ID "x")
```

### AST and Grammar for `parse_expr`

Below is the AST type `expr`, which is returned by `parse_expr`.

```ocaml
type op = Add | Sub | Mult | Div | Concat | Greater | Less | GreaterEqual | LessEqual | Equal | NotEqual | Or | And

type var = string

type expr =
  | Int of int
  | Bool of bool
  | String of string
  | ID of var
  | Fun of var * expr (* an anonymous function: var is the parameter and expr is the body *)
  | Not of expr
  | Binop of op * expr * expr
  | If of expr * expr * expr
  | FunctionCall of expr * expr
  | Let of var * bool * expr * expr (* bool determines whether var is recursive *)
```

The context-free grammar (CFG) below describes the language of MicroCaml expressions. This CFG is right-recursive, so something like `1 + 2 + 3` will parse as `Add (Int 1, Add (Int 2, Int 3))`, essentially implying parentheses in the form `(1 + (2 + 3))`. In the given CFG note that all non-terminals are capitalized, all syntax literals (terminals) are formatted `as non-italicized code` and will come in to the parser as tokens. Variant token types (i.e. `Tok_Bool`, `Tok_Int`, `Tok_String` and `Tok_ID`) will be printed *`as italicized code`*.

- Expr -> LetExpr | IfExpr | FunctionExpr | OrExpr
- LetExpr -> `let` Recursion *`Tok_ID`* `=` Expr `in` Expr
  -	Recursion -> `rec` | ε
- FunctionExpr -> `fun` *`Tok_ID`* `->` Expr
- IfExpr -> `if` Expr `then` Expr `else` Expr
- OrExpr -> AndExpr `||` OrExpr | AndExpr
- AndExpr -> EqualityExpr `&&` AndExpr | EqualityExpr
- EqualityExpr -> RelationalExpr EqualityOperator EqualityExpr | RelationalExpr
  - EqualityOperator -> `=` | `<>`
- RelationalExpr -> AdditiveExpr RelationalOperator RelationalExpr | AdditiveExpr
  - RelationalOperator -> `<` | `>` | `<=` | `>=`
- AdditiveExpr -> MultiplicativeExpr AdditiveOperator AdditiveExpr | MultiplicativeExpr
  - AdditiveOperator -> `+` | `-`
- MultiplicativeExpr -> ConcatExpr MultiplicativeOperator MultiplicativeExpr | ConcatExpr
  - MultiplicativeOperator -> `*` | `/`
- ConcatExpr -> UnaryExpr `^` ConcatExpr | UnaryExpr
- UnaryExpr -> `not` UnaryExpr | FunctionCallExpr
- FunctionCallExpr -> PrimaryExpr PrimaryExpr | PrimaryExpr
- PrimaryExpr -> *`Tok_Int`* | *`Tok_Bool`* | *`Tok_String`* | *`Tok_ID`* | `(` Expr `)`


To illustrate `parse_expr` in action, we show several examples of input and their output AST.

### Example 1: Basic math

**Input:**
```ocaml
(1 + 2 + 3) / 3
```

**Output (after lexing and parsing):**
```ocaml
Binop (Div,
  Binop (Add, (Int 1), Binop (Add, (Int 2), (Int 3))),
  (Int 3))
```

In other words, if we run `parse_expr (tokenize "(1 + 2 + 3) / 3")` it will return the AST above.

### Example 2: `let` expressions

**Input:**
```ocaml
let x = 2 * 3 / 5 + 4 in x - 5
```

**Output (after lexing and parsing):**
```ocaml
Let ("x", false,
  Binop (Add,
    Binop (Mult, (Int 2), Binop (Div, (Int 3), (Int 5))),
    (Int 4)),
  Binop (Sub, ID "x", (Int 5)))
```

### Example 3: `if then ... else ...`

**Input:**
```ocaml
let x = 3 in if not true then x > 3 else x < 3
```

**Output (after lexing and parsing):**
```ocaml
Let ("x", false, (Int 3),
  If (Not ((Bool true)), Binop (Greater, ID "x", (Int 3)),
   Binop (Less, ID "x", (Int 3))))
```

### Example 4: Anonymous functions

**Input:**
```ocaml
let rec f = fun x -> x ^ 1 in f 1
```

**Output (after lexing and parsing):**
```ocaml
Let ("f", true, Fun ("x", Binop (Concat, ID "x", (Int 1))),
  FunctionCall (ID "f", (Int 1)))
```

Keep in mind that the parser is not responsible for finding type errors. This is the job of type inference. For example, while the AST for `1 1` is parsed as `FunctionCall ((Int 1), (Int 1))`; if it is checked by type inference, it will at that time be flagged as a type error.

### Example 5: Recursive anonymous functions

Notice how the AST for `let` expressions uses a `bool` flag to determine whether a function is recursive or not. When a recursive anonymous function `let rec f = fun x -> ... in ...` is defined, `f` will bind to `fun x -> ...` when evaluating the function.

**Input:**
```ocaml
let rec f = fun x -> f (x*x) in f 2
```

**Output (after lexing and parsing):**
```ocaml
Let ("f", true,
  Fun ("x", FunctionCall (ID "f", Binop (Mult, ID "x", ID "x"))),
  FunctionCall (ID "f", (Int 2))))
```

### Example 6: Currying

We will **ONLY** be currying to create multivariable functions as well as passing multiple arguments to them. Here is an example:

**Input:**
```ocaml
let f = fun x -> fun y -> x + y in (f 1) 2
```

**Output (after parsing):**
```ocaml
Let ("f", false,
  Fun ("x", Fun ("y", Binop (Add, ID "x", ID "y"))),
  FunctionCall (FunctionCall (ID "f", (Int 1)), (Int 2)))
```

## Type Inference

You will implement type inference. Put all of your type inference code in [infer.ml](./src/infer.ml).

### Typing Constraint Generation

As stated in [lecture2][lecture2], type inference consists of three steps: (1) Annotate (2) Generate Constraints (3) Solve Constraints. We have provided you a function `gen` for both annotation and constraint generation:
```ocaml
let rec gen (env: environment) (e: expr): aexpr * typeScheme * (typeScheme * typeScheme) list = ...
```
which takes a typing environment `env` and an AST for an input expression of type `expr` and outputs an annotated expression of type `aexpr` that holds the type information for the (sub-expressions) of the given expression `e`, the type of `e` which is represented as a `typeScheme`, and a list of typing constraints `(typeScheme * typeScheme) list`. We provide detailed information about `environment`, `aexpr`, `typeScheme` below.

We defined the typing environment in [infer.ml](./src/infer.ml):
```ocaml
type environment = (var * typeScheme) list
```
An environment is a map that holds the type information `typeScheme` of any variables `var` currently in scope. As an example, consider an expression `let x = 5 in let y = 10 in x + y`. The typing environment of the expression `x+y` is a list `[(y:int); (x: int)]` that maps both `x` and `y` to the `int` type.

We defined the data structure for `typeScheme` in [microCamlTypes.ml](./src/microCamlTypes.ml):
```ocaml
type typeScheme =
    | TNum                                  (int type)
    | TBool                                 (bool type)
    | TStr                                  (string type)
    | T of string                           (type variable for an unknown type)
    | TFun of typeScheme * typeScheme       (function type)
```
More information about type schemes can be found in the lecture slides. As an example, consider a function `fun x -> x 1`. Its OCaml type is `(int -> 'a) -> 'a` (the higher order function takes a function `x` as input and returns the results of applying the function `x` to 1). In our project, this type is written as  `TFun(TFun(TNum, T "'a"), T "'a")`.

We defined the data structure for an expression annotated with types as `aexpr` in [microCamlTypes.ml](./src/microCamlTypes.ml):
```ocaml
type aexpr =
  | AInt of int * typeScheme
  | ABool of bool * typeScheme
  | AString of string * typeScheme
  | AID of var * typeScheme
  | AFun of var * aexpr * typeScheme
  | ANot of aexpr * typeScheme
  | ABinop of op * aexpr * aexpr * typeScheme
  | AIf of aexpr * aexpr * aexpr * typeScheme
  | AFunctionCall of aexpr * aexpr * typeScheme
  | ALet of var * bool * aexpr * aexpr * typeScheme
```
It follows `type expr` defined above except that any `aexpr` expression must be paired with a type scheme which holds the type information of the expression. For example, `5` should be annotated as `AInt (5, TNum)`. As another example, consider the anonymous function `fun x -> x 1`. As we initially have no idea of the type of the function parameter `x`, we use a type scheme `T "a"` to represent the unknown type of `x`. Similarly, we do not know the type of the return of the anonymous function so we use a type scheme `T "b"` to represent this unknown type. Observe that `x` is applied to `1` in the body of the anonymous function. As we have no knowledge about the return type of the function `x`, we once again annotate `x 1` a type scheme `T "c"`. Thus, the annotated expression is:
```ocaml
(fun x -> ((x: a) (1: int)): c): (a -> b)
```
or in OCaml code:
```ocaml
AFun("x", AFunctionCall(AID("x", T "a"), AInt(1, TNum), T "c"), TFun(T "a", T "b"))
```
It is important to note that the annotation is recursive as every subexpression is also annotated in the above example.

The third element in the return of `gen env e` is a list of typing constraints `(typeScheme * typeScheme) list` collected by recursively traversing the input expression `e` under the typing environment `env`. For the anonymous function `fun x -> x 1`, the following typing constraints should be generated:
```
a = (int -> c)
c = b
```
or in OCaml code:
```ocaml
[(T "a", TFun(TNum, T "c"));
 (T "c", T "b")]
```
In the first constraint, `T "a"` is the annotated type of `x` (see above). In the body of the anonymous function, `x` is used a function that applies to an integer (`TNum`) and the function application is annotated with `T "c"`. We constrain `T "a"` same as `TFun(TNum, T "c")`. The second constraint is derived from the fact that the result of the function application `x 1`, annotated with type `T "c"`, is used as the return value of the anonymous function, annotated with return type `T "b"`, so we constrain `T "c"` same as `T "b"`.

Formally, the function `gen` implements the following typing rules to collect the typing constraints. The rules are (recursively) defined in the shape of `G |- u ==> e, t, q` where `G` is a typing environment (initialized to []), `u` is an unannotated expression of type `expr`, `e` is an annotated expression of type `aexpr`, `t` is the annotated type of `u`, and `q` is the list of typing constraints for `u` that must be solved. In other words, the following typing rules jointly define `gen G u = e t q`.

1. Typing the integers.
```
------------------------------
G |- n ==> (n: int), int, []
```

For example, `gen [] (Int 5) = AInt (5, TNum), TNum, []`. No typing constraint is generated.

2. Typing the Booleans.
```
------------------------------
G |- b ==> (b: bool), bool, []
```

For example, `gen [] (Bool true) = ABool (true, TBool), TBool, []`. No typing constraint is generated.

3. Typing the strings.
```
----------------------------------
G |- s ==> (s: string), string, []
```

For example, `gen [] (String "CS314") = AString ("CS314", TStr), TStr, []`. No typing constraint is generated.

4. Typing the variables (identifiers).
```
----------------------------------------------
G |- x ==> (x: t), t, []   (if G(x) = t)
```

For example, `gen [("x", TNum); ("y", TNum)] (ID "x") = AID ("x", TNum), TNum, []`. No typing constraint is generated.

If a variable does not appear in its typing environment, raise `UndefinedVar` exception. `gen [] (ID "x")` raises `UndefinedVar` because `x` is undefined in the typing environment.

5. Typing the function definitions.
```
G; x: a |- u ==> e, t, q               (for fresh a, b)
--------------------------------------------------------------------  
G |- (fun x -> u) ==> (fun x -> e : (a -> b)), a -> b, q @ [(t, b)]
```

See the above example on the anonymous function `fun x -> x 1` for how this rule executes. We have `gen [] (Fun ("x", FunctionCall (ID "x", Int 1))) = AFun("x", AFunctionCall(AID("x", T "a"), AInt(1, TNum), T "c"), TFun(T "a", T "b")), TFun(T "a", T "b"), [(T "a", TFun(TNum, T "c")); (T "c", T "b")]`. The typing constraints `[a = (int -> c); c = b]` are explained above.


6. Typing the negation of Boolean expressions.

```
G |- u ==> e, t, q
---------------------------------------------------
G |- not u ==> (not e: bool), bool, q @ [(t, bool)]   
```

For example, `gen [] (Not (Bool true)) = ANot (ABool (true, TBool), TBool), TBool, [(TBool, TBool)]`. The typing constraint requires the annotated type `t` for `u` (in this example `TBool`) same as `TBool`.

7. Typing binary operations.

```
G |- u1 ==> e1, t1, q1   G |- u2 ==> e2, t2, q2
-----------------------------------------------------------------------------------
G |- u1 ^ u2 ==>  (e1 ^ e2: string), string, q1 @ q2 @ [(t1, string), (t2, string)]
```

We constrain the annotated types for `u1` and `u2` in `u1 ^ u2` as string.

```
G |- u1 ==> e1, t1, q1   G |- u2 ==> e2, t2, q2
-----------------------------------------------------------------------
G |- u1 + u2 ==>  (e1 + e2: int), int, q1 @ q2 @ [(t1, int), (t2, int)]
```

We constrain the annotated types for `u1` and `u2` in `u1 + u2` as int.

```
G |- u1 ==> e1, t1, q1   G |- u2 ==> e2, t2, q2
-------------------------------------------------------------
G |- u1 < u2 ==>  (e1 < e2: bool), bool, q1 @ q2 @ [(t1, t2)]
```

We constrain the annotated type for `u1` and `u2` in `u1 < u2` to be the same. For comparison operators ("<", ">", "=", "<=", ">="), we assume they are generic meaning that they can take values of arbitrary types, provided that the operands have the same type.

8. Typing if expressions.

```
G |- u1 ==> e1, t1, q1   G |= u2 ==> e2, t2, q2   G |- u3 ==> e3, t3, q3
-------------------------------------------------------------------------------------------------------
G |- (if u1 then u2 else u3) ==> (if e1 then e2 else e3: t2), t2, q1 @ q2 @ q3 @ [(t1, bool); (t2, t3)]
```

We constrain the annotated type for `u1` as bool and the annotated types for `u2` and `u3` the same.

9. Typing function applications.

```
G |- u1 ==> e1, t1, q1
G |- u2 ==> e2, t2, q2                 (for fresh a)
--------------------------------------------------------
G |- u1 u2 ==> (e1 e2: a), a, q1 @ q2 @ [(t1 = t2 -> a)]
```

See the above example on the anonymous function `fun x -> x 1` for how this rule executes. We have `gen [("x", T "a")] (FunctionCall (ID "x", Int 1)) = AFunctionCall(AID("x", T "a"), AInt(1, TNum), T "c"), T "c", [(T "a", TFun(TNum, T "c"))]`. Here as we have no knowledge about the return type of the function `x`, we annotate `x 1` a type scheme `T "c"`.  As `x` is used a function that applies to an integer (`TNum`), we constrain `T "a"` (the type of `x` in the typing environment) as `TFun(TNum, T "c")`. Informally, the constraint is `a = (int -> c)`.

10. Typing let expressions.

```
G |- u1 ==> e1, t1, q1   G; x: t1 |- u2 ==> e2, t2, q2
---------------------------------------------------------------
G |- (let x = u1 in u2) ==> (let x = e1 in e2: t2), t2, q1 @ q2  
```

```
G; f: a |- u1 ==> e1, t1, q1   G; f: t1 |- u2 ==> e2, t2, q2  (for fresh a)
-----------------------------------------------------------------------------------
G |- (let rec f = u1 in u2) ==> (let rec f = e1 in e2: t2), t2, q1 @ [(a, t1)] @ q2  
```

The second rule above is for typing recursive functions e.g. `let rec f = fun x -> if x <= 0 then 1 else x * f(x-1) in f 5`. When type checking for `u1`, it is important to add to the type environment a type for `f`. This is because `f` can be recursively used in `u1`. Since we do not know the type of `f` initially, we annotate it with an unknown type `a` and build constraints over it. When type checking `u2`, it is also necessary to extend the typing environment with `(f: t1)` as `f` may be used in `u2`.

### Task I: Typing Constraint Solver

The unification function (defined in [infer.ml](./src/infer.ml))
```ocaml
let rec unify (constraints: (typeScheme * typeScheme) list) : substitutions = ...
```
solves a given set of typing constraints obtained from `gen` and returns the solution in type `substitutions`.

In [infer.ml](./src/infer.ml), we define the type `substitutions` as:
```ocaml
type substitutions = (string * typeScheme) list
```

As an example, consider the typing constraints generated for the program `fun x -> x 1` (explained above):
```
a = (int -> c)
c = b
```
or in OCaml code:
```ocaml
[(T "a", TFun(TNum, T "c"));
 (T "c", T "b")]
```
The solution to the typing constraints is
```
[("a", TFun(TNum, T"b")); ("c", T "b")]
```
Intuitively, this solution is a substitution `[int->b/a, b/c]`. Applying this substitution to the typing constraints mentioned above would render the left-hand side and right-hand side of each constraint equivalent. With this solution, we have the type of `fun x -> x 1` as `(int -> b) -> b`.

Your task is to implement `unify` in [infer.ml](./src/infer.ml). The implementation should be similar to the pseudocode presented in the [lecture2][lecture2] slides. Reviewing the examples covered in [lecture2][lecture2] would be beneficial.

For example, consider the program `(fun x -> x 1) (fun x -> x + 1)`. Evaluating this program yields 2. This expression is of type `int`. Applying `gen` to this program should generate the following annotated program:
```ocaml
((fun x -> ((x: a) (1: int)): c): (a -> b) (fun x -> ((x: d) + (1: int): int)): (d -> e)): f
```
where `a`, `b`, `c`, `d`, `e`, `f` and `g` are unknown type variables to be solved, and generate the following typing constraints over the type variables:
```
a = (int -> c)
c = b
d = int
int = int
int = e
(a -> b) = ((d -> e) -> f)
```

Your `unify` function should derive the following solution:
```
f: int
c: int
d: int
e: int
a: (int -> int)
b: int
```

Please note that your `unify` implementation should handle occurs check. In [lecture2][lecture2], we discussed that the program `fun x -> x x` should be rejected by the type checker. Applying `gen` to this program should generate the following annotated program:
```ocaml
(fun x -> ((x: a) (x: a)): c): (a -> b)
```
where `a`, `b` and `c` are unknown type variables to be solved, and generate the following typing constraints over the type variables:
```
a = (a -> c)
c = b
```
The typing constraints are unsolvable because of the constraint `a = (a -> c)`. The type variable `a` occurs on both sides of the constraint.

Your implementation should reject a program like `fun x -> x x` by raising the `OccursCheckException` exception in `unify` when a typing constraint like `a = (a -> c)` presents.

### Provided functions

#### `gen_new_type`
- **Type:** `unit -> typeScheme`
- **Description:** Returns T(string) as a new unknown type placeholder. Every call to `gen_new_type` generates a fresh type variable. For example, the program `let a = gen_new_type() in let b = gen_new_type in (a, b)` returns two type variables `T "a"` and `T "b"`. This function is particularly useful for implementing the typing rules. The function is defined in [infer.ml](./src/infer.ml).

#### `string_of_op`, `string_of_type`, `string_of_aexpr`, `string_of_expr`
- **Description:** Returns a string representation of a given operator `op`, type `typeScheme`, annotated expression `aexpr`, and unannotated expression `expr`. These functions are defined [microCamlTypes.ml](./src/microCamlTypes.ml) and would be very useful for debugging your implementation.

#### `pp_string_of_type`, `pp_string_of_aexpr`
- **Description:** Pretty printers for returning a string representation of a given type `typeScheme` and annotated expression `aexpr`. These functions outputs types in the OCaml style. For exmple, consider the expression `fun x -> x 1`:
```ocaml
let e = (Fun("x", FunctionCall(ID "x", Int 1))) in
let annotated_expr, t, constraints = gen env e in
let subs = unify constraints in
let annotated_expr = apply_expr subs annotated_expr in
let _ = print_string (pp_string_of_aexpr annotated_expr) in
print_string (pp_string_of_type t
```
The type of `fun x -> x 1` would be printed as the OCaml type `((int -> 'a) -> 'a)`. These functions are defined [microCamlTypes.ml](./src/microCamlTypes.ml) and would be useful to present the type inference result back to the programmer.

#### `string_of_constraints`, `string_of_subs`
- **Description:** These functions return the string representation of typing constraints and solutions. They can be helpful for debugging. The functions are defiend in [infer.ml](./src/infer.ml).

#### `infer`
- **Type:**  `expr -> typeScheme`
- **Description:** This function is what we will use to test your code for type inference. Formally, `infer e` invokes the `gen` function to collect the typing constraints from the given expression `e`, solves the typing constraints using the `unify` function, and finally returns the inferred type of `e`. The function is defined in [infer.ml](./src/infer.ml).

```ocaml
let e = (Fun("x", FunctionCall(ID "x", Int 1))) in
let t = infer e in
pp_string_of_type (t)   (* ((int -> 'a) -> 'a) *)
```
The above program prints out the OCaml type of `fun x -> x 1`.


## Task II: Polymorphic Type Inference

In this part of the project, your task is to modify the code in [infer.ml](./src/infer.ml) to support polymorphic type inference. For example, consider the following the program:

```ocaml
let f = fun x -> x in
let y = f 1 in
f "hello"
```

The `gen` function would collect the following typing constraints from the program:
```        
a = b
(a -> b) = (int -> c)
(a -> b) = (string -> d)
```
where `a` and `b` are the type variables for the input and the output of the function `f`, and `c` and `d` are the type variables for `f 1` and `f "hello"` respectively.

Even with a correct implementation of `unify`, the `infer` function is not capable of inferring the type of this program. This limitation arises from the inability to unify the type variable `a` to both `int` and `string`. Please refer to the `W` algorithm discussed in [lecture2][lecture2] to understand how polymorphic type inference overcomes this challenge.

There are no specific restrictions on how you can modify [infer.ml](./src/infer.ml). Your code will be evaluated by calling the `infer` function. For reference, you can check [main.ml](./main.ml) for example test cases.

In the implementation, you will probably need to update [microCamlTypes.ml](./src/microCamlTypes.ml) to define polymorphic types. Attached below are two examples. There are certainly other approaches to defining a data type for polymorphism.

Option 1:

```ocaml
type typeScheme =
    | TNum
    | TBool
    | TStr
    | T of string
    | TFun of typeScheme * typeScheme
    | TPoly of string list * typeScheme
```

Option 2:

```ocaml
type typeScheme =
    | TNum
    | TBool
    | TStr
    | T of string
    | TFun of typeScheme * typeScheme

type polyType =
    string list * typeScheme
```


[str doc]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Str.html
[lecture2]: ./type-system-inference.pdf
