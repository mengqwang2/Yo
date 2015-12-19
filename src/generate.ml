open Ast
open Sast

let rec generate_expr = function
  SLiteral (x, s) -> x
	(*if s.type_def.name = "String" then ("\"" ^ x ^ "\"" )
	else x*)
| SArrayLiteral (x, s)-> "{" ^ 
	(let generate_ele_expr expr =
		try List.find  (fun x ->match x with NewVar -> true | _ -> false) (extract_semantic expr).actions; 

		"std::make_shared<" ^  ^ ">()"
		with Not_found -> (generate_expr expr)
	in String.concat ", " (List.map generate_ele_expr e)
	) ^ "}" (* defined later *)
| SVar (x, s) -> x
| SArrayIndex (x, y, s) -> generate_expr x ^ "[" ^ generate_expr y ^ "]"
| SDotExpr (x, y, s) -> generate_expr x ^ "." ^ y 
| SBinop (x, op, y, s) -> generate_expr x ^ " " ^ (string_of_op op) ^ " " ^ generate_expr y
| SCall (x, y, z, s) -> 
	let rec generate_expr_list = function
	  [] -> ""
    | hd::tl -> if tl = [] then generate_expr hd
    			else generate_expr hd ^ ", " ^ generate_expr_list tl
	in
	(match x with
	| None -> y ^ "(DUMMY_SELF, " ^ generate_expr_list z ^ ")"
	| Some (expr) -> s.type_def.t_actual ^ "::" ^ y ^ "(" ^ generate_expr expr ^ ", " ^ generate_expr_list z ^ ")" )


let generate_type_declaration t = 
	"struct " ^ t.t_actual ^ " {\n" ^ 
	(let generate_member mem_var_name mem_var_type content= 
		content ^ (generate_type_modifier mem_var_type) ^ " " ^ mem_var_name ^ ";\n"
	 in NameMap.fold generate_member t.members "") ^
	(let generate_eval e content= 
		content ^ "\n" ^ (generate_type_modifier e.ret) ^ " eval (" ^
		(String.concat ", " (List.map (fun x -> (generate_type_modifier x.v_type) ^ " " ^ x.v_actual ) t.evals) ) ^ ") {" ^
		
	) ^
	"\n};"


let rec generate_cond = function
| SCondExec (x, l) -> 
	let rec generate_stmt_list = function
	  [] -> ""
    | hd::tl -> generate_stmt hd ^ generate_stmt_list tl
    in
	(match x with
	| None -> "else if (true) {\n" ^ generate_stmt_list l ^ "}"
	| Some (expr) -> "else if (" ^ generate_expr expr ^ ") {\n" ^ generate_stmt_list l ^ "}"
	)

and generate_stmt = function
| SAssign (x, s) -> 
	(match x with
	| None -> generate_expr s
	| Some (expr) -> let sem = extract_semantic expr in
	(try List.find (fun x ->match x with NewVar -> true | _ -> false) sem.actions; 
		(match sem.type_def.name with 
		| "Int" -> "int " ^ generate_expr expr ^ " = " ^ generate_expr s
		| "Double" -> "double" ^ generate_expr expr ^ " = " ^ generate_expr s
		| "String" -> "String" ^ generate_expr expr ^ " = " ^ generate_expr s
		| "Bool" -> "bool" ^ generate_expr expr ^ " = " ^ generate_expr s
		| _ -> let type_name = sem.type_def.t_actual in
			"std::shared_ptr<" ^  type_name ^ "> " ^ generate_expr expr ^ " = std::make_shared<" ^ type_name^ ">()"
		)
	with Not_found -> (generate_expr expr) ^ " = " ^ (generate_expr s))) ^ ";\n"


| SIfStmt (l) -> "if(false) {}\n" ^ 
	(let rec generate_cond_list = function
	  [] -> ""
    | hd::tl -> generate_cond hd ^ generate_cond_list tl
    in generate_cond_list l)

| SForIn (x, s, e, l) -> "for (auto& " ^ generate_expr x ^ " :{"^
	(let generate_forExpr expr =
		try List.find  (fun x ->match x with NewVar -> true | _ -> false) (extract_semantic expr).actions; 
		"std::make_shared<" ^  ^ ">()"
		with Not_found -> 
	in String.concat "," (List.map generate_forExpr e)
	)
    ^ "}" ^ ")" ^ "{" ^
	(let rec generate_stmt_list = function
	  [] -> ""
    | hd::tl -> generate_stmt hd ^ generate_stmt_list tl
    in generate_stmt_list l) 
    ^ "}"

| SForRange (s, sem, start, end, sl, sign) -> 
	let sstr = generate_expr s in let startstr = generate start in let endstr = generate_expr end in 
	(if sign = Inc then "for (auto&" ^ sstr ^ "=" ^ startstr ^ ";" ^ sstr ^ "<" ^ endstr ^ ";" ^ sstr "++) {\n" 
	else "for (auto&" ^ sstr ^ "=" ^ endstr ^ ";" ^ sstr ^ ">" ^ startstr ^ ";" ^ sstr "--) {\n") ^ 
	(let rec generate_stmt_list = function
	  [] -> ""
    | hd::tl -> generate_stmt hd ^ generate_stmt_list tl
    in generate_stmt_list sl) 
    ^ "}"


| SWhileStmt (x, l) -> "while (" ^ generate_expr x ^ ")" ^ "{" ^
	(let rec generate_stmt_list = function
	  [] -> ""
    | hd::tl -> generate_stmt hd ^ generate_stmt_list tl
    in generate_stmt_list l) ^ "}"

| SContinue -> "continue;\n"
| SBreak -> "break;\n"
| SReturn (x) -> "return " ^
	(match x with
	| None -> ""
	| Some (expr) -> generate_expr expr) ^ ";\n"

let rec generate_global = function
  SGlobalStmt (s) -> generate_stmt s
| SGlobalFunc (f) -> generate_func f
| SGlobalType (t) -> generate_type t

and generate_var_decl = function
  SVarDecl (x, s) -> ""

and generate_func = function
  SFuncDecl (s, svdl, sl, ss) -> ""

and generate_type = function
  STypeDecl (s, stml) -> ""

and generate_type_mem = function
  SMemVarDecl (svd) -> generate_var_decl svd
| SMemFuncDecl (f) -> generate_func f
| SMemTypeDecl (t) -> generate_type t

let rec generate_main = function
  [] -> ""
| hd::tl -> generate_global hd ^ (generate_main tl)

let generate program = 
	let header = ["\"yolib.h\""] in
  let pre_defined = List.map (fun h ->"#include " ^ h ^ "\n") header in
  String.concat "\n" pre_defined ^  "int main() {\n" ^ (generate_main program) ^ "return 0;\n}"
