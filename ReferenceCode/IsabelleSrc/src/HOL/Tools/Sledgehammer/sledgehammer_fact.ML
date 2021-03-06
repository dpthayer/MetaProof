(*  Title:      HOL/Tools/Sledgehammer/sledgehammer_fact.ML
    Author:     Jia Meng, Cambridge University Computer Laboratory and NICTA
    Author:     Jasmin Blanchette, TU Muenchen

Sledgehammer fact handling.
*)

signature SLEDGEHAMMER_FACT =
sig
  type status = ATP_Problem_Generate.status
  type stature = ATP_Problem_Generate.stature

  type fact = ((unit -> string) * stature) * thm

  type fact_override =
    {add : (Facts.ref * Attrib.src list) list,
     del : (Facts.ref * Attrib.src list) list,
     only : bool}

  val ignore_no_atp : bool Config.T
  val instantiate_inducts : bool Config.T
  val no_fact_override : fact_override
  val fact_from_ref :
    Proof.context -> unit Symtab.table -> thm list -> status Termtab.table
    -> Facts.ref * Attrib.src list -> ((string * stature) * thm) list
  val backquote_thm : Proof.context -> thm -> string
  val is_blacklisted_or_something : Proof.context -> bool -> string -> bool
  val clasimpset_rule_table_of : Proof.context -> status Termtab.table
  val build_name_tables :
    (thm -> string) -> ('a * thm) list
    -> string Symtab.table * string Symtab.table
  val maybe_instantiate_inducts :
    Proof.context -> term list -> term -> (((unit -> string) * 'a) * thm) list
    -> (((unit -> string) * 'a) * thm) list
  val maybe_filter_no_atps : Proof.context -> ('a * thm) list -> ('a * thm) list
  val all_facts :
    Proof.context -> bool -> bool -> unit Symtab.table -> thm list -> thm list
    -> status Termtab.table -> fact list
  val nearly_all_facts :
    Proof.context -> bool -> fact_override -> unit Symtab.table
    -> status Termtab.table -> thm list -> term list -> term -> fact list
end;

structure Sledgehammer_Fact : SLEDGEHAMMER_FACT =
struct

open ATP_Util
open ATP_Problem_Generate
open Metis_Tactic
open Sledgehammer_Util

type fact = ((unit -> string) * stature) * thm

type fact_override =
  {add : (Facts.ref * Attrib.src list) list,
   del : (Facts.ref * Attrib.src list) list,
   only : bool}

(* experimental features *)
val ignore_no_atp =
  Attrib.setup_config_bool @{binding sledgehammer_ignore_no_atp} (K false)
val instantiate_inducts =
  Attrib.setup_config_bool @{binding sledgehammer_instantiate_inducts} (K false)

val no_fact_override = {add = [], del = [], only = false}

fun needs_quoting reserved s =
  Symtab.defined reserved s orelse
  exists (not o Symbol_Pos.is_identifier) (Long_Name.explode s)

fun make_name reserved multi j name =
  (name |> needs_quoting reserved name ? quote) ^
  (if multi then "(" ^ string_of_int j ^ ")" else "")

fun explode_interval _ (Facts.FromTo (i, j)) = i upto j
  | explode_interval max (Facts.From i) = i upto i + max - 1
  | explode_interval _ (Facts.Single i) = [i]

val backquote =
  raw_explode #> map (fn "`" => "\\`" | s => s) #> implode #> enclose "`" "`"

(* unfolding these can yield really huge terms *)
val risky_defs = @{thms Bit0_def Bit1_def}

fun is_rec_eq lhs = Term.exists_subterm (curry (op =) (head_of lhs))
fun is_rec_def (@{const Trueprop} $ t) = is_rec_def t
  | is_rec_def (@{const ==>} $ _ $ t2) = is_rec_def t2
  | is_rec_def (Const (@{const_name "=="}, _) $ t1 $ t2) = is_rec_eq t1 t2
  | is_rec_def (Const (@{const_name HOL.eq}, _) $ t1 $ t2) = is_rec_eq t1 t2
  | is_rec_def _ = false

fun is_assum assms th = exists (fn ct => prop_of th aconv term_of ct) assms
fun is_chained chained = member Thm.eq_thm_prop chained

fun scope_of_thm global assms chained th =
  if is_chained chained th then Chained
  else if global then Global
  else if is_assum assms th then Assum
  else Local

val may_be_induction =
  exists_subterm (fn Var (_, Type (@{type_name fun}, [_, T])) =>
                     body_type T = @{typ bool}
                   | _ => false)

fun status_of_thm css name th =
  (* FIXME: use structured name *)
  if (String.isSubstring ".induct" name orelse
      String.isSubstring ".inducts" name) andalso
     may_be_induction (prop_of th) then
    Induction
  else case Termtab.lookup css (prop_of th) of
    SOME status => status
  | NONE => General

fun stature_of_thm global assms chained css name th =
  (scope_of_thm global assms chained th, status_of_thm css name th)

fun fact_from_ref ctxt reserved chained css (xthm as (xref, args)) =
  let
    val ths = Attrib.eval_thms ctxt [xthm]
    val bracket =
      map (enclose "[" "]" o Pretty.str_of o Args.pretty_src ctxt) args
      |> implode
    fun nth_name j =
      case xref of
        Facts.Fact s => backquote s ^ bracket
      | Facts.Named (("", _), _) => "[" ^ bracket ^ "]"
      | Facts.Named ((name, _), NONE) =>
        make_name reserved (length ths > 1) (j + 1) name ^ bracket
      | Facts.Named ((name, _), SOME intervals) =>
        make_name reserved true
                 (nth (maps (explode_interval (length ths)) intervals) j) name ^
        bracket
    fun add_nth th (j, rest) =
      let val name = nth_name j in
        (j + 1, ((name, stature_of_thm false [] chained css name th), th)
                :: rest)
      end
  in (0, []) |> fold add_nth ths |> snd end

(* Reject theorems with names like "List.filter.filter_list_def" or
  "Accessible_Part.acc.defs", as these are definitions arising from packages. *)
fun is_package_def s =
  let val ss = Long_Name.explode s in
    length ss > 2 andalso not (hd ss = "local") andalso
    exists (fn suf => String.isSuffix suf s)
           ["_case_def", "_rec_def", "_size_def", "_size_overloaded_def"]
  end

(* FIXME: put other record thms here, or declare as "no_atp" *)
fun multi_base_blacklist ctxt ho_atp =
  ["defs", "select_defs", "update_defs", "split", "splits", "split_asm",
   "ext_cases", "eq.simps", "eq.refl", "nchotomy", "case_cong",
   "weak_case_cong", "nibble_pair_of_char_simps", "nibble.simps",
   "nibble.distinct"]
  |> not (ho_atp orelse (Config.get ctxt instantiate_inducts)) ?
        append ["induct", "inducts"]
  |> map (prefix Long_Name.separator)

val max_lambda_nesting = 5 (*only applies if not ho_atp*)

fun term_has_too_many_lambdas max (t1 $ t2) =
    exists (term_has_too_many_lambdas max) [t1, t2]
  | term_has_too_many_lambdas max (Abs (_, _, t)) =
    max = 0 orelse term_has_too_many_lambdas (max - 1) t
  | term_has_too_many_lambdas _ _ = false

(* Don't count nested lambdas at the level of formulas, since they are
   quantifiers. *)
fun formula_has_too_many_lambdas Ts (Abs (_, T, t)) =
    formula_has_too_many_lambdas (T :: Ts) t
  | formula_has_too_many_lambdas Ts t =
    if member (op =) [HOLogic.boolT, propT] (fastype_of1 (Ts, t)) then
      exists (formula_has_too_many_lambdas Ts) (#2 (strip_comb t))
    else
      term_has_too_many_lambdas max_lambda_nesting t

(* The maximum apply depth of any "metis" call in "Metis_Examples" (on
   2007-10-31) was 11. *)
val max_apply_depth = 18

fun apply_depth (f $ t) = Int.max (apply_depth f, apply_depth t + 1)
  | apply_depth (Abs (_, _, t)) = apply_depth t
  | apply_depth _ = 0

fun is_too_complex ho_atp t =
  apply_depth t > max_apply_depth orelse
  (not ho_atp andalso formula_has_too_many_lambdas [] t)

(* FIXME: Ad hoc list *)
val technical_prefixes =
  ["ATP", "Code_Evaluation", "Datatype", "DSequence", "Enum", "Lazy_Sequence",
   "Meson", "Metis", "Nitpick", "New_DSequence", "New_Random_Sequence",
   "Quickcheck", "Quickcheck_Exhaustive", "Quickcheck_Narrowing",
   "Random_Sequence", "Sledgehammer", "SMT"]
  |> map (suffix Long_Name.separator)

fun has_technical_prefix s =
  exists (fn pref => String.isPrefix pref s) technical_prefixes
val exists_technical_const = exists_Const (has_technical_prefix o fst)

(* FIXME: make more reliable *)
val exists_low_level_class_const =
  exists_Const (fn (s, _) =>
     s = @{const_name equal_class.equal} orelse
     String.isSubstring (Long_Name.separator ^ "class" ^ Long_Name.separator) s)

fun is_that_fact th =
  String.isSuffix (Long_Name.separator ^ Obtain.thatN) (Thm.get_name_hint th)
  andalso exists_subterm (fn Free (s, _) => s = Name.skolem Auto_Bind.thesisN
                           | _ => false) (prop_of th)

fun is_likely_tautology_too_meta_or_too_technical th =
  let
    fun is_interesting_subterm (Const (s, _)) =
        not (member (op =) atp_widely_irrelevant_consts s)
      | is_interesting_subterm (Free _) = true
      | is_interesting_subterm _ = false
    fun is_boring_bool t =
      not (exists_subterm is_interesting_subterm t) orelse
      exists_type (exists_subtype (curry (op =) @{typ prop})) t
    fun is_boring_prop _ (@{const Trueprop} $ t) = is_boring_bool t
      | is_boring_prop Ts (@{const "==>"} $ t $ u) =
        is_boring_prop Ts t andalso is_boring_prop Ts u
      | is_boring_prop Ts (Const (@{const_name all}, _) $ Abs (_, T, t)) =
        is_boring_prop (T :: Ts) t
      | is_boring_prop Ts ((t as Const (@{const_name all}, _)) $ u) =
        is_boring_prop Ts (t $ eta_expand Ts u 1)
      | is_boring_prop _ (Const (@{const_name "=="}, _) $ t $ u) =
        is_boring_bool t andalso is_boring_bool u
      | is_boring_prop _ _ = true
    val t = prop_of th
  in
    (is_boring_prop [] (prop_of th) andalso
     not (Thm.eq_thm_prop (@{thm ext}, th))) orelse
    exists_type type_has_top_sort t orelse exists_technical_const t orelse
    exists_low_level_class_const t orelse is_that_fact th
  end

fun is_blacklisted_or_something ctxt ho_atp name =
  (not (Config.get ctxt ignore_no_atp) andalso is_package_def name) orelse
  exists (fn s => String.isSuffix s name) (multi_base_blacklist ctxt ho_atp)

fun hackish_string_for_term ctxt =
  with_vanilla_print_mode (Syntax.string_of_term ctxt) #> simplify_spaces

(* This is a terrible hack. Free variables are sometimes coded as "M__" when
   they are displayed as "M" and we want to avoid clashes with these. But
   sometimes it's even worse: "Ma__" encodes "M". So we simply reserve all
   prefixes of all free variables. In the worse case scenario, where the fact
   won't be resolved correctly, the user can fix it manually, e.g., by giving a
   name to the offending fact. *)
fun all_prefixes_of s =
  map (fn i => String.extract (s, 0, SOME i)) (1 upto size s - 1)

fun close_form t =
  (t, [] |> Term.add_free_names t |> maps all_prefixes_of)
  |> fold (fn ((s, i), T) => fn (t', taken) =>
              let val s' = singleton (Name.variant_list taken) s in
                ((if fastype_of t' = HOLogic.boolT then HOLogic.all_const
                  else Logic.all_const) T
                 $ Abs (s', T, abstract_over (Var ((s, i), T), t')),
                 s' :: taken)
              end)
          (Term.add_vars t [] |> sort_wrt (fst o fst))
  |> fst

fun backquote_term ctxt t =
  t |> close_form
    |> hackish_string_for_term ctxt
    |> backquote

fun backquote_thm ctxt th = backquote_term ctxt (prop_of th)

fun clasimpset_rule_table_of ctxt =
  let
    val thy = Proof_Context.theory_of ctxt
    val atomize = HOLogic.mk_Trueprop o Object_Logic.atomize_term thy
    fun add stature normalizers get_th =
      fold (fn rule =>
               let
                 val th = rule |> get_th
                 val t =
                   th |> Thm.maxidx_of th > 0 ? zero_var_indexes |> prop_of
               in
                 fold (fn normalize => Termtab.update (normalize t, stature))
                      (I :: normalizers)
               end)
    val {safeIs, (* safeEs, *) hazIs, (* hazEs, *) ...} =
      ctxt |> claset_of |> Classical.rep_cs
    val intros = Item_Net.content safeIs @ Item_Net.content hazIs
(* Add once it is used:
    val elims =
      Item_Net.content safeEs @ Item_Net.content hazEs
      |> map Classical.classical_rule
*)
    val simps = ctxt |> simpset_of |> dest_ss |> #simps
    val specs = ctxt |> Spec_Rules.get
    val (rec_defs, nonrec_defs) =
      specs |> filter (curry (op =) Spec_Rules.Equational o fst)
            |> maps (snd o snd)
            |> filter_out (member Thm.eq_thm_prop risky_defs)
            |> List.partition (is_rec_def o prop_of)
    val spec_intros =
      specs |> filter (member (op =) [Spec_Rules.Inductive,
                                      Spec_Rules.Co_Inductive] o fst)
            |> maps (snd o snd)
  in
    Termtab.empty |> add Simp [atomize] snd simps
                  |> add Rec_Def [] I rec_defs
                  |> add Non_Rec_Def [] I nonrec_defs
(* Add once it is used:
                  |> add Elim [] I elims
*)
                  |> add Intro [] I intros
                  |> add Inductive [] I spec_intros
  end

fun normalize_eq (t as @{const Trueprop}
        $ ((t0 as Const (@{const_name HOL.eq}, _)) $ t1 $ t2)) =
    if Term_Ord.fast_term_ord (t1, t2) <> GREATER then t
    else HOLogic.mk_Trueprop (t0 $ t2 $ t1)
  | normalize_eq (t as @{const Trueprop} $ (@{const Not}
        $ ((t0 as Const (@{const_name HOL.eq}, _)) $ t1 $ t2))) =
    if Term_Ord.fast_term_ord (t1, t2) <> GREATER then t
    else HOLogic.mk_Trueprop (HOLogic.mk_not (t0 $ t2 $ t1))
  | normalize_eq t = t

val normalize_eq_etc = normalize_eq o Term_Subst.zero_var_indexes

fun if_thm_before th th' =
  if Theory.subthy (pairself Thm.theory_of_thm (th, th')) then th else th'

(* Hack: Conflate the facts about a class as seen from the outside with the
   corresponding low-level facts, so that MaSh can learn from the low-level
   proofs. *)
fun un_class_ify s =
  case first_field "_class" s of
    SOME (pref, suf) => [s, pref ^ suf]
  | NONE => [s]

fun build_name_tables name_of facts =
  let
    fun cons_thm (_, th) = Termtab.cons_list (normalize_eq_etc (prop_of th), th)
    fun add_plain canon alias =
      Symtab.update (Thm.get_name_hint alias,
                     name_of (if_thm_before canon alias))
    fun add_plains (_, aliases as canon :: _) = fold (add_plain canon) aliases
    fun add_inclass (name, target) =
      fold (fn s => Symtab.update (s, target)) (un_class_ify name)
    val prop_tab = fold cons_thm facts Termtab.empty
    val plain_name_tab = Termtab.fold add_plains prop_tab Symtab.empty
    val inclass_name_tab = Symtab.fold add_inclass plain_name_tab Symtab.empty
  in (plain_name_tab, inclass_name_tab) end

fun uniquify facts =
  Termtab.fold (cons o snd)
      (fold (Termtab.default o `(normalize_eq_etc o prop_of o snd)) facts
            Termtab.empty) []

fun struct_induct_rule_on th =
  case Logic.strip_horn (prop_of th) of
    (prems, @{const Trueprop}
            $ ((p as Var ((p_name, 0), _)) $ (a as Var (_, ind_T)))) =>
    if not (is_TVar ind_T) andalso length prems > 1 andalso
       exists (exists_subterm (curry (op aconv) p)) prems andalso
       not (exists (exists_subterm (curry (op aconv) a)) prems) then
      SOME (p_name, ind_T)
    else
      NONE
  | _ => NONE

val instantiate_induct_timeout = seconds 0.01

fun instantiate_induct_rule ctxt concl_prop p_name ((name, stature), th) ind_x =
  let
    fun varify_noninducts (t as Free (s, T)) =
        if (s, T) = ind_x orelse can dest_funT T then t else Var ((s, 0), T)
      | varify_noninducts t = t
    val p_inst =
      concl_prop |> map_aterms varify_noninducts |> close_form
                 |> lambda (Free ind_x)
                 |> hackish_string_for_term ctxt
  in
    ((fn () => name () ^ "[where " ^ p_name ^ " = " ^ quote p_inst ^ "]",
      stature), th |> read_instantiate ctxt [((p_name, 0), p_inst)])
  end

fun type_match thy (T1, T2) =
  (Sign.typ_match thy (T2, T1) Vartab.empty; true)
  handle Type.TYPE_MATCH => false

fun instantiate_if_induct_rule ctxt stmt stmt_xs (ax as (_, th)) =
  case struct_induct_rule_on th of
    SOME (p_name, ind_T) =>
    let val thy = Proof_Context.theory_of ctxt in
      stmt_xs |> filter (fn (_, T) => type_match thy (T, ind_T))
              |> map_filter (try (TimeLimit.timeLimit instantiate_induct_timeout
                     (instantiate_induct_rule ctxt stmt p_name ax)))
    end
  | NONE => [ax]

fun external_frees t =
  [] |> Term.add_frees t |> filter_out (can Name.dest_internal o fst)

fun maybe_instantiate_inducts ctxt hyp_ts concl_t =
  if Config.get ctxt instantiate_inducts then
    let
      val thy = Proof_Context.theory_of ctxt
      val ind_stmt =
        (hyp_ts |> filter_out (null o external_frees), concl_t)
        |> Logic.list_implies |> Object_Logic.atomize_term thy
      val ind_stmt_xs = external_frees ind_stmt
    in maps (instantiate_if_induct_rule ctxt ind_stmt ind_stmt_xs) end
  else
    I

fun maybe_filter_no_atps ctxt =
  not (Config.get ctxt ignore_no_atp) ? filter_out (No_ATPs.member ctxt o snd)

fun all_facts ctxt generous ho_atp reserved add_ths chained css =
  let
    val thy = Proof_Context.theory_of ctxt
    val global_facts = Global_Theory.facts_of thy
    val local_facts = Proof_Context.facts_of ctxt
    val named_locals = local_facts |> Facts.dest_static []
    val assms = Assumption.all_assms_of ctxt
    fun is_good_unnamed_local th =
      not (Thm.has_name_hint th) andalso
      forall (fn (_, ths) => not (member Thm.eq_thm_prop ths th)) named_locals
    val unnamed_locals =
      union Thm.eq_thm_prop (Facts.props local_facts) chained
      |> filter is_good_unnamed_local |> map (pair "" o single)
    val full_space =
      Name_Space.merge (Facts.space_of global_facts, Facts.space_of local_facts)
    fun add_facts global foldx facts =
      foldx (fn (name0, ths) =>
        if name0 <> "" andalso
           forall (not o member Thm.eq_thm_prop add_ths) ths andalso
           (Facts.is_concealed facts name0 orelse
            not (can (Proof_Context.get_thms ctxt) name0) orelse
            (not generous andalso
             is_blacklisted_or_something ctxt ho_atp name0)) then
          I
        else
          let
            val n = length ths
            val multi = n > 1
            fun check_thms a =
              case try (Proof_Context.get_thms ctxt) a of
                NONE => false
              | SOME ths' => eq_list Thm.eq_thm_prop (ths, ths')
          in
            pair n
            #> fold_rev (fn th => fn (j, accum) =>
                   (j - 1,
                    if not (member Thm.eq_thm_prop add_ths th) andalso
                       (is_likely_tautology_too_meta_or_too_technical th orelse
                        (not generous andalso
                         is_too_complex ho_atp (prop_of th))) then
                      accum
                    else
                      let
                        val new =
                          (((fn () =>
                                if name0 = "" then
                                  backquote_thm ctxt th
                                else
                                  [Facts.extern ctxt facts name0,
                                   Name_Space.extern ctxt full_space name0]
                                  |> distinct (op =)
                                  |> find_first check_thms
                                  |> the_default name0
                                  |> make_name reserved multi j),
                             stature_of_thm global assms chained css name0 th),
                           th)
                      in
                        accum |> (if multi then apsnd else apfst) (cons new)
                      end)) ths
            #> snd
          end)
  in
    (* The single-theorem names go before the multiple-theorem ones (e.g.,
       "xxx" vs. "xxx(3)"), so that single names are preferred when both are
       available. *)
    `I [] |> add_facts false fold local_facts (unnamed_locals @ named_locals)
          |> add_facts true Facts.fold_static global_facts global_facts
          |> op @
  end

fun nearly_all_facts ctxt ho_atp {add, del, only} reserved css chained hyp_ts
                     concl_t =
  if only andalso null add then
    []
  else
    let
      val chained =
        chained
        |> maps (fn th => insert Thm.eq_thm_prop (zero_var_indexes th) [th])
    in
      (if only then
         maps (map (fn ((name, stature), th) => ((K name, stature), th))
               o fact_from_ref ctxt reserved chained css) add
       else
         let val (add, del) = pairself (Attrib.eval_thms ctxt) (add, del) in
           all_facts ctxt false ho_atp reserved add chained css
           |> filter_out (member Thm.eq_thm_prop del o snd)
           |> maybe_filter_no_atps ctxt
           |> uniquify
         end)
      |> maybe_instantiate_inducts ctxt hyp_ts concl_t
    end

end;
