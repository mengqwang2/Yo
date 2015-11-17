open Ast

type action = 
  | NewVar

let string_of_action = function
  | NewVar -> "new"

type sem = {
  mutable actions: action list;
  type_def: type_entry
}


let string_of_sem s = "$" ^ "type: " ^ (string_of_type_def s.type_def) ^ " " 
                      ^ (String.concat " | " (List.map string_of_action s.actions)) ^ "$"

type s_expr =                                 (* Expressions*)
  | SLiteral of string * sem      (* int, double, bool, string *)
  | SArrayLiteral of s_expr list * sem
  | SArrayExpr of s_expr * s_expr * sem               (* A[B[3]]*)
  | SVar of string * sem             (* foo *)  
  | SDotExpr of s_expr * string * sem        (* A.B *)
  | SBinop of s_expr * op * s_expr * sem      (* 3+4 *)
  | SCall of s_expr option * string * s_expr list * sem      (* foo(a, b) *)
  | SNoExpr 
  
let rec string_of_s_expr = function
  | SLiteral (str, s) -> str ^ (string_of_sem s)
  | SArrayLiteral (selist, s) -> let s = (List.fold_left (fun a b -> a ^ ", " ^ b) "" (List.map string_of_s_expr selist)) in 
  "[" ^ (String.sub s 2 ((String.length s) - 2))  ^ "]" ^ (string_of_sem s)
  | SArrayExpr (sout, sin, s) -> (string_of_s_expr sout) ^ "[" ^ (string_of_s_expr sin) ^ "]" ^ (string_of_sem s)
  | SVar (id, s) -> id ^ (string_of_sem s)
  | SDotExpr (sexpr, id, s) -> (string_of_s_expr sexpr) ^ "." ^ id ^ (string_of_sem s)
  | SBinop (lsexpr, op, rsexpr, s) -> (string_of_s_expr lsexpr) ^ " " ^(match o with | Add -> "+" | Sub -> "-" | Mult -> "*" | Div -> "/"
      | Equal -> "==" | Neq -> "!=" | Less -> "<" | Leq -> "<=" | Greater -> ">" | Geq -> ">=" | And -> "&&" | Or -> "||") 
    ^ (string_of_s_expr rsexpr) ^ (string_of_sem s)
  | SCall (obj, f, el, s) -> (match obj with 
          | None -> "" | Some st -> (string_of_s_expr st) ^ "." )^ f ^ "(" ^ (String.concat ", " (List.map string_of_s_expr el)) ^ ")" ^ (string_of_sem s)
  | SNoExpr -> ""

let extract_semantic = function
  | SLiteral (_, s) -> s
  | SArrayLiteral (_, s) -> s
  | SArrayExpr (_, _, s) -> s            
  | SVar (_, s) -> s            
  | SDotExpr (_, _, s) -> s       
  | SBinop (_, _, _, s) ->s      
  | SCall (_, _, _, s) ->s

type s_stmt =
  | SAssign of s_expr option * s_expr
  | SIfStmt of s_cond_exec list
  | SForIn of string * sem * s_expr * s_stmt list
  | SForEq of string * sem * s_expr * s_expr * s_stmt list
  | SWhileStmt of s_expr * s_stmt list
  | SContinue 
  | SBreak 
  | SReturn of s_expr option

and s_cond_exec = 
   SCondExec of s_expr option * s_stmt list

let string_of_s_stmt = function
  | SAssign(None,rvalue) -> string_of_s_expr rvalue
  | SAssign(Some(lvalue), rvalue) -> (string_of_s_expr lvalue) ^ " = " ^ (string_of_s_expr rvalue)
  | SIfStmt(conds) -> string_of_s_first_cond_exec (List.hd conds) ^ "\n" ^
  (String.concat "\n" (List.map string_of_s_cond_exec (List.tl conds)))
  | SForIn(var, s, expr, stmts) -> "for " ^ var ^ (string_of_sem s) ^ " in " ^ (string_of_s_expr expr) 
    ^ ":\n" ^ (String.concat "\n" (List.map string_of_s_stmt stmts))
  | SForEq(var, s, exprst, expred, stmts) -> "for " ^ var ^ (string_of_sem s) ^ " = " ^ (string_of_s_expr exprst) 
    ^ " to " ^ (string_of_s_expr expred) ^ ":\n" ^(String.concat "\n" (List.map string_of_s_stmt stmts))
  | SWhileStmt(expr, stmts) -> "while " ^ (string_of_s_expr expr) ^ ":\n" 
    ^ (String.concat "\n" (List.map string_of_s_stmt stmts))
  | SContinue -> "continue"
  | SBreak -> "break"
  | SReturn(None) -> "return"
  | SReturn(Some(expr)) -> "return " ^ (string_of_s_expr expr)

and string_of_s_first_cond_exec = function
  | CondExec(None, stmts) -> "else:" ^ (String.concat "\n" (List.map string_of_s_stmt stmts))
  | CondExec(Some(expr), stmts) -> "if " ^ (string_of_s_expr expr) ^ ":\n" ^ (String.concat "\n" (List.map string_of_s_stmt stmts))

and string_of_s_cond_exec = function
  | CondExec(None, stmts) -> "else:" ^ (String.concat "\n" (List.map string_of_s_stmt stmts))
  | CondExec(Some(expr), stmts) -> "elif " ^ (string_of_s_expr expr) ^ ":\n" ^ (String.concat "\n" (List.map string_of_s_stmt stmts))


type s_var_decl = 
  | SVarDecl of string * sem

and s_func_decl = 
  | SFuncDecl of string * s_var_decl list * s_stmt list * sem

and s_type_decl = 
  | STypeDecl of string * s_type_mem_decl list

and s_type_mem_decl = 
  | SMemVarDecl of s_var_decl
  | SMemFuncDecl of s_func_decl
  | SMemTypeDecl of s_type_decl

and global_ele_decl = 
  | SGlobalStmt of s_stmt
  | SGlobalFunc of s_func_decl
  | SGlobalType of s_type_decl


let string_of_s_var_decl = function
  | VarDecl(id, s) -> id ^ (string_of_sem s)

and string_of_s_func_decl = function
  | FuncDecl(name, args, stmts, s) -> "func " ^ name ^ " (" ^ (String.concat ", " (List.map string_of_s_var_decl args)) 
    ^ ")\n" ^ (String.concat "\n" (List.map string_of_s_stmt stmts)) ^ (string_of_sem s)

and string_of_s_type_decl = function
  | TypeDecl(name, args) -> "type " ^ name ^ "\n" ^ (String.concat "\n" (List.map string_of_s_type_mem_decl args))

and string_of_s_type_mem_decl = function
  | MemVarDecl o -> string_of_s_var_decl o
  | MemFuncDecl o -> string_of_s_func_decl o 
  | MemTypeDecl o -> string_of_s_type_decl o

and string_of_s_global_ele_decl = function
  | GlobalStmt o -> string_of_s_stmt o
  | GlobalFunc o -> string_of_s_func_decl o
  | GlobalType o -> string_of_s_type_decl o

and string_of_program program =
  String.concat "\n" (List.map string_of_s_global_ele_decl program) 
