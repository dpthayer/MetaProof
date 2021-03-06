(*  Title:      Pure/tactic.ML
    Author:     Lawrence C Paulson, Cambridge University Computer Laboratory

Fundamental tactics.
*)

signature BASIC_TACTIC =
sig
  val trace_goalno_tac: (int -> tactic) -> int -> tactic
  val rule_by_tactic: Proof.context -> tactic -> thm -> thm
  val assume_tac: int -> tactic
  val eq_assume_tac: int -> tactic
  val compose_tac: (bool * thm * int) -> int -> tactic
  val make_elim: thm -> thm
  val biresolve_tac: (bool * thm) list -> int -> tactic
  val resolve_tac: thm list -> int -> tactic
  val eresolve_tac: thm list -> int -> tactic
  val forward_tac: thm list -> int -> tactic
  val dresolve_tac: thm list -> int -> tactic
  val atac: int -> tactic
  val rtac: thm -> int -> tactic
  val dtac: thm -> int -> tactic
  val etac: thm -> int -> tactic
  val ftac: thm -> int -> tactic
  val ares_tac: thm list -> int -> tactic
  val solve_tac: thm list -> int -> tactic
  val bimatch_tac: (bool * thm) list -> int -> tactic
  val match_tac: thm list -> int -> tactic
  val ematch_tac: thm list -> int -> tactic
  val dmatch_tac: thm list -> int -> tactic
  val flexflex_tac: tactic
  val distinct_subgoal_tac: int -> tactic
  val distinct_subgoals_tac: tactic
  val cut_tac: thm -> int -> tactic
  val cut_rules_tac: thm list -> int -> tactic
  val cut_facts_tac: thm list -> int -> tactic
  val filter_thms: (term * term -> bool) -> int * term * thm list -> thm list
  val biresolution_from_nets_tac: ('a list -> (bool * thm) list) ->
    bool -> 'a Net.net * 'a Net.net -> int -> tactic
  val biresolve_from_nets_tac: (int * (bool * thm)) Net.net * (int * (bool * thm)) Net.net ->
    int -> tactic
  val bimatch_from_nets_tac: (int * (bool * thm)) Net.net * (int * (bool * thm)) Net.net ->
    int -> tactic
  val net_biresolve_tac: (bool * thm) list -> int -> tactic
  val net_bimatch_tac: (bool * thm) list -> int -> tactic
  val filt_resolve_tac: thm list -> int -> int -> tactic
  val resolve_from_net_tac: (int * thm) Net.net -> int -> tactic
  val match_from_net_tac: (int * thm) Net.net -> int -> tactic
  val net_resolve_tac: thm list -> int -> tactic
  val net_match_tac: thm list -> int -> tactic
  val subgoals_of_brl: bool * thm -> int
  val lessb: (bool * thm) * (bool * thm) -> bool
  val rename_tac: string list -> int -> tactic
  val rotate_tac: int -> int -> tactic
  val defer_tac: int -> tactic
  val prefer_tac: int -> tactic
  val filter_prems_tac: (term -> bool) -> int -> tactic
end;

signature TACTIC =
sig
  include BASIC_TACTIC
  val insert_tagged_brl: 'a * (bool * thm) ->
    ('a * (bool * thm)) Net.net * ('a * (bool * thm)) Net.net ->
      ('a * (bool * thm)) Net.net * ('a * (bool * thm)) Net.net
  val build_netpair: (int * (bool * thm)) Net.net * (int * (bool * thm)) Net.net ->
    (bool * thm) list -> (int * (bool * thm)) Net.net * (int * (bool * thm)) Net.net
  val delete_tagged_brl: bool * thm ->
    ('a * (bool * thm)) Net.net * ('a * (bool * thm)) Net.net ->
      ('a * (bool * thm)) Net.net * ('a * (bool * thm)) Net.net
  val eq_kbrl: ('a * (bool * thm)) * ('a * (bool * thm)) -> bool
  val build_net: thm list -> (int * thm) Net.net
end;

structure Tactic: TACTIC =
struct

(*Discover which goal is chosen:  SOMEGOAL(trace_goalno_tac tac) *)
fun trace_goalno_tac tac i st =
    case Seq.pull(tac i st) of
        NONE    => Seq.empty
      | seqcell => (tracing ("Subgoal " ^ string_of_int i ^ " selected");
                         Seq.make(fn()=> seqcell));

(*Makes a rule by applying a tactic to an existing rule*)
fun rule_by_tactic ctxt tac rl =
  let
    val ctxt' = Variable.declare_thm rl ctxt;
    val ((_, [st]), ctxt'') = Variable.import true [rl] ctxt';
  in
    (case Seq.pull (tac st) of
      NONE => raise THM ("rule_by_tactic", 0, [rl])
    | SOME (st', _) => zero_var_indexes (singleton (Variable.export ctxt'' ctxt') st'))
  end;


(*** Basic tactics ***)

(*** The following fail if the goal number is out of range:
     thus (REPEAT (resolve_tac rules i)) stops once subgoal i disappears. *)

(*Solve subgoal i by assumption*)
fun assume_tac i = PRIMSEQ (Thm.assumption i);

(*Solve subgoal i by assumption, using no unification*)
fun eq_assume_tac i = PRIMITIVE (Thm.eq_assumption i);


(** Resolution/matching tactics **)

(*The composition rule/state: no lifting or var renaming.
  The arg = (bires_flg, orule, m);  see Thm.bicompose for explanation.*)
fun compose_tac arg i = PRIMSEQ (Thm.bicompose false arg i);

(*Converts a "destruct" rule like P&Q==>P to an "elimination" rule
  like [| P&Q; P==>R |] ==> R *)
fun make_elim rl = zero_var_indexes (rl RS revcut_rl);

(*Attack subgoal i by resolution, using flags to indicate elimination rules*)
fun biresolve_tac brules i = PRIMSEQ (Thm.biresolution false brules i);

(*Resolution: the simple case, works for introduction rules*)
fun resolve_tac rules = biresolve_tac (map (pair false) rules);

(*Resolution with elimination rules only*)
fun eresolve_tac rules = biresolve_tac (map (pair true) rules);

(*Forward reasoning using destruction rules.*)
fun forward_tac rls = resolve_tac (map make_elim rls) THEN' assume_tac;

(*Like forward_tac, but deletes the assumption after use.*)
fun dresolve_tac rls = eresolve_tac (map make_elim rls);

(*Shorthand versions: for resolution with a single theorem*)
val atac    =   assume_tac;
fun rtac rl =  resolve_tac [rl];
fun dtac rl = dresolve_tac [rl];
fun etac rl = eresolve_tac [rl];
fun ftac rl =  forward_tac [rl];

(*Use an assumption or some rules ... A popular combination!*)
fun ares_tac rules = assume_tac  ORELSE'  resolve_tac rules;

fun solve_tac rules = resolve_tac rules THEN_ALL_NEW assume_tac;

(*Matching tactics -- as above, but forbid updating of state*)
fun bimatch_tac brules i = PRIMSEQ (Thm.biresolution true brules i);
fun match_tac rules  = bimatch_tac (map (pair false) rules);
fun ematch_tac rules = bimatch_tac (map (pair true) rules);
fun dmatch_tac rls   = ematch_tac (map make_elim rls);

(*Smash all flex-flex disagreement pairs in the proof state.*)
val flexflex_tac = PRIMSEQ Thm.flexflex_rule;

(*Remove duplicate subgoals.*)
val permute_tac = PRIMITIVE oo Thm.permute_prems;
fun distinct_tac (i, k) =
  permute_tac 0 (i - 1) THEN
  permute_tac 1 (k - 1) THEN
  DETERM (PRIMSEQ (fn st =>
    Thm.compose_no_flatten false (st, 0) 1
      (Drule.incr_indexes st Drule.distinct_prems_rl))) THEN
  permute_tac 1 (1 - k) THEN
  permute_tac 0 (1 - i);

fun distinct_subgoal_tac i st =
  (case drop (i - 1) (Thm.prems_of st) of
    [] => no_tac st
  | A :: Bs =>
      st |> EVERY (fold (fn (B, k) =>
        if A aconv B then cons (distinct_tac (i, k)) else I) (Bs ~~ (1 upto length Bs)) []));

fun distinct_subgoals_tac state =
  let
    val goals = Thm.prems_of state;
    val dups = distinct (eq_fst (op aconv)) (goals ~~ (1 upto length goals));
  in EVERY (rev (map (distinct_subgoal_tac o snd) dups)) state end;


(*** Applications of cut_rl ***)

(*The conclusion of the rule gets assumed in subgoal i,
  while subgoal i+1,... are the premises of the rule.*)
fun cut_tac rule i = rtac cut_rl i THEN rtac rule (i + 1);

(*"Cut" a list of rules into the goal.  Their premises will become new
  subgoals.*)
fun cut_rules_tac ths i = EVERY (map (fn th => cut_tac th i) ths);

(*As above, but inserts only facts (unconditional theorems);
  generates no additional subgoals. *)
fun cut_facts_tac ths = cut_rules_tac (filter Thm.no_prems ths);


(**** Indexing and filtering of theorems ****)

(*Returns the list of potentially resolvable theorems for the goal "prem",
        using the predicate  could(subgoal,concl).
  Resulting list is no longer than "limit"*)
fun filter_thms could (limit, prem, ths) =
  let val pb = Logic.strip_assums_concl prem;   (*delete assumptions*)
      fun filtr (limit, []) = []
        | filtr (limit, th::ths) =
            if limit=0 then  []
            else if could(pb, concl_of th)  then th :: filtr(limit-1, ths)
            else filtr(limit,ths)
  in  filtr(limit,ths)  end;


(*** biresolution and resolution using nets ***)

(** To preserve the order of the rules, tag them with increasing integers **)

(*insert one tagged brl into the pair of nets*)
fun insert_tagged_brl (kbrl as (k, (eres, th))) (inet, enet) =
  if eres then
    (case try Thm.major_prem_of th of
      SOME prem => (inet, Net.insert_term (K false) (prem, kbrl) enet)
    | NONE => error "insert_tagged_brl: elimination rule with no premises")
  else (Net.insert_term (K false) (concl_of th, kbrl) inet, enet);

(*build a pair of nets for biresolution*)
fun build_netpair netpair brls =
    fold_rev insert_tagged_brl (tag_list 1 brls) netpair;

(*delete one kbrl from the pair of nets*)
fun eq_kbrl ((_, (_, th)), (_, (_, th'))) = Thm.eq_thm_prop (th, th')

fun delete_tagged_brl (brl as (eres, th)) (inet, enet) =
  (if eres then
    (case try Thm.major_prem_of th of
      SOME prem => (inet, Net.delete_term eq_kbrl (prem, ((), brl)) enet)
    | NONE => (inet, enet))  (*no major premise: ignore*)
  else (Net.delete_term eq_kbrl (Thm.concl_of th, ((), brl)) inet, enet))
  handle Net.DELETE => (inet,enet);


(*biresolution using a pair of nets rather than rules.
    function "order" must sort and possibly filter the list of brls.
    boolean "match" indicates matching or unification.*)
fun biresolution_from_nets_tac order match (inet,enet) =
  SUBGOAL
    (fn (prem,i) =>
      let val hyps = Logic.strip_assums_hyp prem
          and concl = Logic.strip_assums_concl prem
          val kbrls = Net.unify_term inet concl @ maps (Net.unify_term enet) hyps
      in PRIMSEQ (Thm.biresolution match (order kbrls) i) end);

(*versions taking pre-built nets.  No filtering of brls*)
val biresolve_from_nets_tac = biresolution_from_nets_tac order_list false;
val bimatch_from_nets_tac   = biresolution_from_nets_tac order_list true;

(*fast versions using nets internally*)
val net_biresolve_tac =
    biresolve_from_nets_tac o build_netpair(Net.empty,Net.empty);

val net_bimatch_tac =
    bimatch_from_nets_tac o build_netpair(Net.empty,Net.empty);

(*** Simpler version for resolve_tac -- only one net, and no hyps ***)

(*insert one tagged rl into the net*)
fun insert_krl (krl as (k,th)) =
  Net.insert_term (K false) (concl_of th, krl);

(*build a net of rules for resolution*)
fun build_net rls =
  fold_rev insert_krl (tag_list 1 rls) Net.empty;

(*resolution using a net rather than rules; pred supports filt_resolve_tac*)
fun filt_resolution_from_net_tac match pred net =
  SUBGOAL
    (fn (prem,i) =>
      let val krls = Net.unify_term net (Logic.strip_assums_concl prem)
      in
         if pred krls
         then PRIMSEQ
                (Thm.biresolution match (map (pair false) (order_list krls)) i)
         else no_tac
      end);

(*Resolve the subgoal using the rules (making a net) unless too flexible,
   which means more than maxr rules are unifiable.      *)
fun filt_resolve_tac rules maxr =
    let fun pred krls = length krls <= maxr
    in  filt_resolution_from_net_tac false pred (build_net rules)  end;

(*versions taking pre-built nets*)
val resolve_from_net_tac = filt_resolution_from_net_tac false (K true);
val match_from_net_tac = filt_resolution_from_net_tac true (K true);

(*fast versions using nets internally*)
val net_resolve_tac = resolve_from_net_tac o build_net;
val net_match_tac = match_from_net_tac o build_net;


(*** For Natural Deduction using (bires_flg, rule) pairs ***)

(*The number of new subgoals produced by the brule*)
fun subgoals_of_brl (true,rule)  = nprems_of rule - 1
  | subgoals_of_brl (false,rule) = nprems_of rule;

(*Less-than test: for sorting to minimize number of new subgoals*)
fun lessb (brl1,brl2) = subgoals_of_brl brl1 < subgoals_of_brl brl2;


(*Renaming of parameters in a subgoal*)
fun rename_tac xs i =
  case Library.find_first (not o Symbol_Pos.is_identifier) xs of
      SOME x => error ("Not an identifier: " ^ x)
    | NONE => PRIMITIVE (Thm.rename_params_rule (xs, i));

(*rotate_tac n i: rotate the assumptions of subgoal i by n positions, from
  right to left if n is positive, and from left to right if n is negative.*)
fun rotate_tac 0 i = all_tac
  | rotate_tac k i = PRIMITIVE (Thm.rotate_rule k i);

(*Rotates the given subgoal to be the last.*)
fun defer_tac i = PRIMITIVE (Thm.permute_prems (i - 1) 1);

(*Rotates the given subgoal to be the first.*)
fun prefer_tac i = PRIMITIVE (Thm.permute_prems (i - 1) 1 #> Thm.permute_prems 0 ~1);

(* remove premises that do not satisfy p; fails if all prems satisfy p *)
fun filter_prems_tac p =
  let fun Then NONE tac = SOME tac
        | Then (SOME tac) tac' = SOME(tac THEN' tac');
      fun thins H (tac,n) =
        if p H then (tac,n+1)
        else (Then tac (rotate_tac n THEN' etac thin_rl),0);
  in SUBGOAL(fn (subg,n) =>
       let val Hs = Logic.strip_assums_hyp subg
       in case fst(fold thins Hs (NONE,0)) of
            NONE => no_tac | SOME tac => tac n
       end)
  end;

end;

structure Basic_Tactic: BASIC_TACTIC = Tactic;
open Basic_Tactic;
