(*  Title:      HOL/Tools/TFL/usyntax.ML
    Author:     Konrad Slind, Cambridge University Computer Laboratory

Emulation of HOL's abstract syntax functions.
*)

signature USYNTAX =
sig
  datatype lambda = VAR   of {Name : string, Ty : typ}
                  | CONST of {Name : string, Ty : typ}
                  | COMB  of {Rator: term, Rand : term}
                  | LAMB  of {Bvar : term, Body : term}

  val alpha : typ

  (* Types *)
  val type_vars  : typ -> typ list
  val type_varsl : typ list -> typ list
  val mk_vartype : string -> typ
  val is_vartype : typ -> bool
  val strip_prod_type : typ -> typ list

  (* Terms *)
  val free_vars_lr : term -> term list
  val type_vars_in_term : term -> typ list
  val dest_term  : term -> lambda

  (* Prelogic *)
  val inst      : (typ*typ) list -> term -> term

  (* Construction routines *)
  val mk_abs    :{Bvar  : term, Body : term} -> term

  val mk_imp    :{ant : term, conseq :  term} -> term
  val mk_select :{Bvar : term, Body : term} -> term
  val mk_forall :{Bvar : term, Body : term} -> term
  val mk_exists :{Bvar : term, Body : term} -> term
  val mk_conj   :{conj1 : term, conj2 : term} -> term
  val mk_disj   :{disj1 : term, disj2 : term} -> term
  val mk_pabs   :{varstruct : term, body : term} -> term

  (* Destruction routines *)
  val dest_const: term -> {Name : string, Ty : typ}
  val dest_comb : term -> {Rator : term, Rand : term}
  val dest_abs  : string list -> term -> {Bvar : term, Body : term} * string list
  val dest_eq     : term -> {lhs : term, rhs : term}
  val dest_imp    : term -> {ant : term, conseq : term}
  val dest_forall : term -> {Bvar : term, Body : term}
  val dest_exists : term -> {Bvar : term, Body : term}
  val dest_neg    : term -> term
  val dest_conj   : term -> {conj1 : term, conj2 : term}
  val dest_disj   : term -> {disj1 : term, disj2 : term}
  val dest_pair   : term -> {fst : term, snd : term}
  val dest_pabs   : string list -> term -> {varstruct : term, body : term, used : string list}

  val lhs   : term -> term
  val rhs   : term -> term
  val rand  : term -> term

  (* Query routines *)
  val is_imp    : term -> bool
  val is_forall : term -> bool
  val is_exists : term -> bool
  val is_neg    : term -> bool
  val is_conj   : term -> bool
  val is_disj   : term -> bool
  val is_pair   : term -> bool
  val is_pabs   : term -> bool

  (* Construction of a term from a list of Preterms *)
  val list_mk_abs    : (term list * term) -> term
  val list_mk_imp    : (term list * term) -> term
  val list_mk_forall : (term list * term) -> term
  val list_mk_conj   : term list -> term

  (* Destructing a term to a list of Preterms *)
  val strip_comb     : term -> (term * term list)
  val strip_abs      : term -> (term list * term)
  val strip_imp      : term -> (term list * term)
  val strip_forall   : term -> (term list * term)
  val strip_exists   : term -> (term list * term)
  val strip_disj     : term -> term list

  (* Miscellaneous *)
  val mk_vstruct : typ -> term list -> term
  val gen_all    : term -> term
  val find_term  : (term -> bool) -> term -> term option
  val dest_relation : term -> term * term * term
  val is_WFR : term -> bool
  val ARB : typ -> term
end;

structure USyntax: USYNTAX =
struct

infix 4 ##;

fun USYN_ERR func mesg = Utils.ERR {module = "USyntax", func = func, mesg = mesg};


(*---------------------------------------------------------------------------
 *
 *                            Types
 *
 *---------------------------------------------------------------------------*)
val mk_prim_vartype = TVar;
fun mk_vartype s = mk_prim_vartype ((s, 0), HOLogic.typeS);

(* But internally, it's useful *)
fun dest_vtype (TVar x) = x
  | dest_vtype _ = raise USYN_ERR "dest_vtype" "not a flexible type variable";

val is_vartype = can dest_vtype;

val type_vars  = map mk_prim_vartype o Misc_Legacy.typ_tvars
fun type_varsl L = distinct (op =) (fold (curry op @ o type_vars) L []);

val alpha  = mk_vartype "'a"
val beta   = mk_vartype "'b"

val strip_prod_type = HOLogic.flatten_tupleT;



(*---------------------------------------------------------------------------
 *
 *                              Terms
 *
 *---------------------------------------------------------------------------*)

(* Free variables, in order of occurrence, from left to right in the
 * syntax tree. *)
fun free_vars_lr tm =
  let fun memb x = let fun m[] = false | m(y::rst) = (x=y)orelse m rst in m end
      fun add (t, frees) = case t of
            Free   _ => if (memb t frees) then frees else t::frees
          | Abs (_,_,body) => add(body,frees)
          | f$t =>  add(t, add(f, frees))
          | _ => frees
  in rev(add(tm,[]))
  end;



val type_vars_in_term = map mk_prim_vartype o Misc_Legacy.term_tvars;



(* Prelogic *)
fun dest_tybinding (v,ty) = (#1(dest_vtype v),ty)
fun inst theta = subst_vars (map dest_tybinding theta,[])


(* Construction routines *)

fun mk_abs{Bvar as Var((s,_),ty),Body}  = Abs(s,ty,abstract_over(Bvar,Body))
  | mk_abs{Bvar as Free(s,ty),Body}  = Abs(s,ty,abstract_over(Bvar,Body))
  | mk_abs _ = raise USYN_ERR "mk_abs" "Bvar is not a variable";


fun mk_imp{ant,conseq} =
   let val c = Const(@{const_name HOL.implies},HOLogic.boolT --> HOLogic.boolT --> HOLogic.boolT)
   in list_comb(c,[ant,conseq])
   end;

fun mk_select (r as {Bvar,Body}) =
  let val ty = type_of Bvar
      val c = Const(@{const_name Eps},(ty --> HOLogic.boolT) --> ty)
  in list_comb(c,[mk_abs r])
  end;

fun mk_forall (r as {Bvar,Body}) =
  let val ty = type_of Bvar
      val c = Const(@{const_name All},(ty --> HOLogic.boolT) --> HOLogic.boolT)
  in list_comb(c,[mk_abs r])
  end;

fun mk_exists (r as {Bvar,Body}) =
  let val ty = type_of Bvar
      val c = Const(@{const_name Ex},(ty --> HOLogic.boolT) --> HOLogic.boolT)
  in list_comb(c,[mk_abs r])
  end;


fun mk_conj{conj1,conj2} =
   let val c = Const(@{const_name HOL.conj},HOLogic.boolT --> HOLogic.boolT --> HOLogic.boolT)
   in list_comb(c,[conj1,conj2])
   end;

fun mk_disj{disj1,disj2} =
   let val c = Const(@{const_name HOL.disj},HOLogic.boolT --> HOLogic.boolT --> HOLogic.boolT)
   in list_comb(c,[disj1,disj2])
   end;

fun prod_ty ty1 ty2 = HOLogic.mk_prodT (ty1,ty2);

local
fun mk_uncurry (xt, yt, zt) =
    Const(@{const_name prod_case}, (xt --> yt --> zt) --> prod_ty xt yt --> zt)
fun dest_pair(Const(@{const_name Pair},_) $ M $ N) = {fst=M, snd=N}
  | dest_pair _ = raise USYN_ERR "dest_pair" "not a pair"
fun is_var (Var _) = true | is_var (Free _) = true | is_var _ = false
in
fun mk_pabs{varstruct,body} =
 let fun mpa (varstruct, body) =
       if is_var varstruct
       then mk_abs {Bvar = varstruct, Body = body}
       else let val {fst, snd} = dest_pair varstruct
            in mk_uncurry (type_of fst, type_of snd, type_of body) $
               mpa (fst, mpa (snd, body))
            end
 in mpa (varstruct, body) end
 handle TYPE _ => raise USYN_ERR "mk_pabs" "";
end;

(* Destruction routines *)

datatype lambda = VAR   of {Name : string, Ty : typ}
                | CONST of {Name : string, Ty : typ}
                | COMB  of {Rator: term, Rand : term}
                | LAMB  of {Bvar : term, Body : term};


fun dest_term(Var((s,i),ty)) = VAR{Name = s, Ty = ty}
  | dest_term(Free(s,ty))    = VAR{Name = s, Ty = ty}
  | dest_term(Const(s,ty))   = CONST{Name = s, Ty = ty}
  | dest_term(M$N)           = COMB{Rator=M,Rand=N}
  | dest_term(Abs(s,ty,M))   = let  val v = Free(s,ty)
                               in LAMB{Bvar = v, Body = Term.betapply (M,v)}
                               end
  | dest_term(Bound _)       = raise USYN_ERR "dest_term" "Bound";

fun dest_const(Const(s,ty)) = {Name = s, Ty = ty}
  | dest_const _ = raise USYN_ERR "dest_const" "not a constant";

fun dest_comb(t1 $ t2) = {Rator = t1, Rand = t2}
  | dest_comb _ =  raise USYN_ERR "dest_comb" "not a comb";

fun dest_abs used (a as Abs(s, ty, M)) =
     let
       val s' = singleton (Name.variant_list used) s;
       val v = Free(s', ty);
     in ({Bvar = v, Body = Term.betapply (a,v)}, s'::used)
     end
  | dest_abs _ _ =  raise USYN_ERR "dest_abs" "not an abstraction";

fun dest_eq(Const(@{const_name HOL.eq},_) $ M $ N) = {lhs=M, rhs=N}
  | dest_eq _ = raise USYN_ERR "dest_eq" "not an equality";

fun dest_imp(Const(@{const_name HOL.implies},_) $ M $ N) = {ant=M, conseq=N}
  | dest_imp _ = raise USYN_ERR "dest_imp" "not an implication";

fun dest_forall(Const(@{const_name All},_) $ (a as Abs _)) = fst (dest_abs [] a)
  | dest_forall _ = raise USYN_ERR "dest_forall" "not a forall";

fun dest_exists(Const(@{const_name Ex},_) $ (a as Abs _)) = fst (dest_abs [] a)
  | dest_exists _ = raise USYN_ERR "dest_exists" "not an existential";

fun dest_neg(Const(@{const_name Not},_) $ M) = M
  | dest_neg _ = raise USYN_ERR "dest_neg" "not a negation";

fun dest_conj(Const(@{const_name HOL.conj},_) $ M $ N) = {conj1=M, conj2=N}
  | dest_conj _ = raise USYN_ERR "dest_conj" "not a conjunction";

fun dest_disj(Const(@{const_name HOL.disj},_) $ M $ N) = {disj1=M, disj2=N}
  | dest_disj _ = raise USYN_ERR "dest_disj" "not a disjunction";

fun mk_pair{fst,snd} =
   let val ty1 = type_of fst
       val ty2 = type_of snd
       val c = Const(@{const_name Pair},ty1 --> ty2 --> prod_ty ty1 ty2)
   in list_comb(c,[fst,snd])
   end;

fun dest_pair(Const(@{const_name Pair},_) $ M $ N) = {fst=M, snd=N}
  | dest_pair _ = raise USYN_ERR "dest_pair" "not a pair";


local  fun ucheck t = (if #Name (dest_const t) = @{const_name prod_case} then t
                       else raise Match)
in
fun dest_pabs used tm =
   let val ({Bvar,Body}, used') = dest_abs used tm
   in {varstruct = Bvar, body = Body, used = used'}
   end handle Utils.ERR _ =>
          let val {Rator,Rand} = dest_comb tm
              val _ = ucheck Rator
              val {varstruct = lv, body, used = used'} = dest_pabs used Rand
              val {varstruct = rv, body, used = used''} = dest_pabs used' body
          in {varstruct = mk_pair {fst = lv, snd = rv}, body = body, used = used''}
          end
end;


val lhs   = #lhs o dest_eq
val rhs   = #rhs o dest_eq
val rand  = #Rand o dest_comb


(* Query routines *)
val is_imp    = can dest_imp
val is_forall = can dest_forall
val is_exists = can dest_exists
val is_neg    = can dest_neg
val is_conj   = can dest_conj
val is_disj   = can dest_disj
val is_pair   = can dest_pair
val is_pabs   = can (dest_pabs [])


(* Construction of a cterm from a list of Terms *)

fun list_mk_abs(L,tm) = fold_rev (fn v => fn M => mk_abs{Bvar=v, Body=M}) L tm;

(* These others are almost never used *)
fun list_mk_imp(A,c) = fold_rev (fn a => fn tm => mk_imp{ant=a,conseq=tm}) A c;
fun list_mk_forall(V,t) = fold_rev (fn v => fn b => mk_forall{Bvar=v, Body=b})V t;
val list_mk_conj = Utils.end_itlist(fn c1 => fn tm => mk_conj{conj1=c1, conj2=tm})


(* Need to reverse? *)
fun gen_all tm = list_mk_forall(Misc_Legacy.term_frees tm, tm);

(* Destructing a cterm to a list of Terms *)
fun strip_comb tm =
   let fun dest(M$N, A) = dest(M, N::A)
         | dest x = x
   in dest(tm,[])
   end;

fun strip_abs(tm as Abs _) =
       let val ({Bvar,Body}, _) = dest_abs [] tm
           val (bvs, core) = strip_abs Body
       in (Bvar::bvs, core)
       end
  | strip_abs M = ([],M);


fun strip_imp fm =
   if (is_imp fm)
   then let val {ant,conseq} = dest_imp fm
            val (was,wb) = strip_imp conseq
        in ((ant::was), wb)
        end
   else ([],fm);

fun strip_forall fm =
   if (is_forall fm)
   then let val {Bvar,Body} = dest_forall fm
            val (bvs,core) = strip_forall Body
        in ((Bvar::bvs), core)
        end
   else ([],fm);


fun strip_exists fm =
   if (is_exists fm)
   then let val {Bvar, Body} = dest_exists fm
            val (bvs,core) = strip_exists Body
        in (Bvar::bvs, core)
        end
   else ([],fm);

fun strip_disj w =
   if (is_disj w)
   then let val {disj1,disj2} = dest_disj w
        in (strip_disj disj1@strip_disj disj2)
        end
   else [w];


(* Miscellaneous *)

fun mk_vstruct ty V =
  let fun follow_prod_type (Type(@{type_name Product_Type.prod},[ty1,ty2])) vs =
              let val (ltm,vs1) = follow_prod_type ty1 vs
                  val (rtm,vs2) = follow_prod_type ty2 vs1
              in (mk_pair{fst=ltm, snd=rtm}, vs2) end
        | follow_prod_type _ (v::vs) = (v,vs)
  in #1 (follow_prod_type ty V)  end;


(* Search a term for a sub-term satisfying the predicate p. *)
fun find_term p =
   let fun find tm =
      if (p tm) then SOME tm
      else case tm of
          Abs(_,_,body) => find body
        | (t$u)         => (case find t of NONE => find u | some => some)
        | _             => NONE
   in find
   end;

fun dest_relation tm =
   if (type_of tm = HOLogic.boolT)
   then let val (Const(@{const_name Set.member},_) $ (Const(@{const_name Pair},_)$y$x) $ R) = tm
        in (R,y,x)
        end handle Bind => raise USYN_ERR "dest_relation" "unexpected term structure"
   else raise USYN_ERR "dest_relation" "not a boolean term";

fun is_WFR (Const(@{const_name Wellfounded.wf},_)$_) = true
  | is_WFR _                 = false;

fun ARB ty = mk_select{Bvar=Free("v",ty),
                       Body=Const(@{const_name True},HOLogic.boolT)};

end;
