(*  Title:      Pure/goal.ML
    Author:     Makarius

Goals in tactical theorem proving, with support for forked proofs.
*)

signature BASIC_GOAL =
sig
  val parallel_proofs: int Unsynchronized.ref
  val parallel_proofs_threshold: int Unsynchronized.ref
  val SELECT_GOAL: tactic -> int -> tactic
  val CONJUNCTS: tactic -> int -> tactic
  val PRECISE_CONJUNCTS: int -> tactic -> int -> tactic
  val PARALLEL_CHOICE: tactic list -> tactic
  val PARALLEL_GOALS: tactic -> tactic
end;

signature GOAL =
sig
  include BASIC_GOAL
  val init: cterm -> thm
  val protect: thm -> thm
  val conclude: thm -> thm
  val check_finished: Proof.context -> thm -> thm
  val finish: Proof.context -> thm -> thm
  val norm_result: thm -> thm
  val fork_name: string -> (unit -> 'a) -> 'a future
  val fork: (unit -> 'a) -> 'a future
  val peek_futures: serial -> unit future list
  val reset_futures: unit -> Future.group list
  val future_enabled_level: int -> bool
  val future_enabled: unit -> bool
  val future_enabled_nested: int -> bool
  val future_result: Proof.context -> thm future -> term -> thm
  val prove_internal: cterm list -> cterm -> (thm list -> tactic) -> thm
  val prove_multi: Proof.context -> string list -> term list -> term list ->
    ({prems: thm list, context: Proof.context} -> tactic) -> thm list
  val prove_future: Proof.context -> string list -> term list -> term ->
    ({prems: thm list, context: Proof.context} -> tactic) -> thm
  val prove: Proof.context -> string list -> term list -> term ->
    ({prems: thm list, context: Proof.context} -> tactic) -> thm
  val prove_global: theory -> string list -> term list -> term ->
    ({prems: thm list, context: Proof.context} -> tactic) -> thm
  val extract: int -> int -> thm -> thm Seq.seq
  val retrofit: int -> int -> thm -> thm -> thm Seq.seq
  val conjunction_tac: int -> tactic
  val precise_conjunction_tac: int -> int -> tactic
  val recover_conjunction_tac: tactic
  val norm_hhf_tac: int -> tactic
  val compose_hhf_tac: thm -> int -> tactic
  val assume_rule_tac: Proof.context -> int -> tactic
end;

structure Goal: GOAL =
struct

(** goals **)

(*
  -------- (init)
  C ==> #C
*)
val init =
  let val A = #1 (Thm.dest_implies (Thm.cprop_of Drule.protectI))
  in fn C => Thm.instantiate ([], [(A, C)]) Drule.protectI end;

(*
   C
  --- (protect)
  #C
*)
fun protect th = Drule.comp_no_flatten (th, 0) 1 Drule.protectI;

(*
  A ==> ... ==> #C
  ---------------- (conclude)
  A ==> ... ==> C
*)
fun conclude th = Drule.comp_no_flatten (th, Thm.nprems_of th) 1 Drule.protectD;

(*
  #C
  --- (finish)
   C
*)
fun check_finished ctxt th =
  (case Thm.nprems_of th of
    0 => th
  | n => raise THM ("Proof failed.\n" ^
      Pretty.string_of (Goal_Display.pretty_goal {main = true, limit = false} ctxt th), 0, [th]));

fun finish ctxt = check_finished ctxt #> conclude;



(** results **)

(* normal form *)

val norm_result =
  Drule.flexflex_unique
  #> Raw_Simplifier.norm_hhf_protect
  #> Thm.strip_shyps
  #> Drule.zero_var_indexes;


(* forked proofs *)

local

val forked_proofs =
  Synchronized.var "forked_proofs"
    (0, []: Future.group list, Inttab.empty: unit future list Inttab.table);

fun count_forked i =
  Synchronized.change forked_proofs (fn (m, groups, tab) =>
    let
      val n = m + i;
      val _ = Future.forked_proofs := n;
    in (n, groups, tab) end);

fun register_forked id future =
  Synchronized.change forked_proofs (fn (m, groups, tab) =>
    let
      val groups' = Task_Queue.group_of_task (Future.task_of future) :: groups;
      val tab' = Inttab.cons_list (id, Future.map (K ()) future) tab;
    in (m, groups', tab') end);

fun status task markups =
  let val props = Markup.properties [(Markup.taskN, Task_Queue.str_of_task task)]
  in Output.status (implode (map (Markup.markup_only o props) markups)) end;

in

fun fork_name name e =
  uninterruptible (fn _ => fn () =>
    let
      val pos = Position.thread_data ();
      val id = the_default 0 (Position.parse_id pos);
      val _ = count_forked 1;

      val future =
        (singleton o Future.forks)
          {name = name, group = NONE, deps = [], pri = ~1, interrupts = false}
          (fn () =>
            let
              val task = the (Future.worker_task ());
              val _ = status task [Markup.running];
              val result =
                Exn.capture (Future.interruptible_task e) ()
                |> Future.identify_result pos;
              val _ = status task [Markup.finished, Markup.joined];
              val _ =
                (case result of
                  Exn.Res _ => ()
                | Exn.Exn exn =>
                    if id = 0 orelse Exn.is_interrupt exn then ()
                    else
                      (status task [Markup.failed];
                       Output.report (Markup.markup_only Markup.bad);
                       List.app (Future.error_msg pos) (ML_Compiler.exn_messages_ids exn)));
              val _ = count_forked ~1;
            in Exn.release result end);
      val _ = status (Future.task_of future) [Markup.forked];
      val _ = register_forked id future;
    in future end) ();

fun fork e = fork_name "Goal.fork" e;

fun forked_count () = #1 (Synchronized.value forked_proofs);

fun peek_futures id =
  Inttab.lookup_list (#3 (Synchronized.value forked_proofs)) id;

fun reset_futures () =
  Synchronized.change_result forked_proofs (fn (m, groups, tab) =>
    (Future.forked_proofs := 0; (groups, (0, [], Inttab.empty))));

end;


(* scheduling parameters *)

val parallel_proofs = Unsynchronized.ref 1;
val parallel_proofs_threshold = Unsynchronized.ref 50;

fun future_enabled_level n =
  Multithreading.enabled () andalso ! parallel_proofs >= n andalso
  is_some (Future.worker_task ());

fun future_enabled () = future_enabled_level 1;

fun future_enabled_nested n =
  future_enabled_level n andalso
  forked_count () < ! parallel_proofs_threshold * Multithreading.max_threads_value ();


(* future_result *)

fun future_result ctxt result prop =
  let
    val thy = Proof_Context.theory_of ctxt;
    val _ = Context.reject_draft thy;
    val cert = Thm.cterm_of thy;
    val certT = Thm.ctyp_of thy;

    val assms = Assumption.all_assms_of ctxt;
    val As = map Thm.term_of assms;

    val xs = map Free (fold Term.add_frees (prop :: As) []);
    val fixes = map cert xs;

    val tfrees = fold Term.add_tfrees (prop :: As) [];
    val instT = map (fn (a, S) => (certT (TVar ((a, 0), S)), certT (TFree (a, S)))) tfrees;

    val global_prop =
      cert (Logic.varify_types_global (fold_rev Logic.all xs (Logic.list_implies (As, prop))))
      |> Thm.weaken_sorts (Variable.sorts_of ctxt);
    val global_result = result |> Future.map
      (Drule.flexflex_unique #>
        Thm.adjust_maxidx_thm ~1 #>
        Drule.implies_intr_list assms #>
        Drule.forall_intr_list fixes #>
        Thm.generalize (map #1 tfrees, []) 0 #>
        Thm.strip_shyps);
    val local_result =
      Thm.future global_result global_prop
      |> Thm.close_derivation
      |> Thm.instantiate (instT, [])
      |> Drule.forall_elim_list fixes
      |> fold (Thm.elim_implies o Thm.assume) assms;
  in local_result end;



(** tactical theorem proving **)

(* prove_internal -- minimal checks, no normalization of result! *)

fun prove_internal casms cprop tac =
  (case SINGLE (tac (map Assumption.assume casms)) (init cprop) of
    SOME th => Drule.implies_intr_list casms
      (finish (Syntax.init_pretty_global (Thm.theory_of_thm th)) th)
  | NONE => error "Tactic failed");


(* prove_common etc. *)

fun prove_common immediate ctxt xs asms props tac =
  let
    val thy = Proof_Context.theory_of ctxt;
    val string_of_term = Syntax.string_of_term ctxt;

    val pos = Position.thread_data ();
    fun err msg = cat_error msg
      ("The error(s) above occurred for the goal statement:\n" ^
        string_of_term (Logic.list_implies (asms, Logic.mk_conjunction_list props)) ^
        (case Position.here pos of "" => "" | s => "\n" ^ s));

    fun cert_safe t = Thm.cterm_of thy (Envir.beta_norm (Term.no_dummy_patterns t))
      handle TERM (msg, _) => err msg | TYPE (msg, _, _) => err msg;
    val casms = map cert_safe asms;
    val cprops = map cert_safe props;

    val (prems, ctxt') = ctxt
      |> Variable.add_fixes_direct xs
      |> fold Variable.declare_term (asms @ props)
      |> Assumption.add_assumes casms
      ||> Variable.set_body true;
    val sorts = Variable.sorts_of ctxt';

    val stmt = Thm.weaken_sorts sorts (Conjunction.mk_conjunction_balanced cprops);

    fun result () =
      (case SINGLE (tac {prems = prems, context = ctxt'}) (init stmt) of
        NONE => err "Tactic failed"
      | SOME st =>
          let val res = finish ctxt' st handle THM (msg, _, _) => err msg in
            if Unify.matches_list thy [Thm.term_of stmt] [Thm.prop_of res]
            then Thm.check_shyps sorts res
            else err ("Proved a different theorem: " ^ string_of_term (Thm.prop_of res))
          end);
    val res =
      if immediate orelse #maxidx (Thm.rep_cterm stmt) >= 0 orelse not (future_enabled ())
      then result ()
      else future_result ctxt' (fork result) (Thm.term_of stmt);
  in
    Conjunction.elim_balanced (length props) res
    |> map (Assumption.export false ctxt' ctxt)
    |> Variable.export ctxt' ctxt
    |> map Drule.zero_var_indexes
  end;

val prove_multi = prove_common true;

fun prove_future ctxt xs asms prop tac = hd (prove_common false ctxt xs asms [prop] tac);
fun prove ctxt xs asms prop tac = hd (prove_common true ctxt xs asms [prop] tac);

fun prove_global thy xs asms prop tac =
  Drule.export_without_context (prove (Proof_Context.init_global thy) xs asms prop tac);



(** goal structure **)

(* nested goals *)

fun extract i n st =
  (if i < 1 orelse n < 1 orelse i + n - 1 > Thm.nprems_of st then Seq.empty
   else if n = 1 then Seq.single (Thm.cprem_of st i)
   else
     Seq.single (Conjunction.mk_conjunction_balanced (map (Thm.cprem_of st) (i upto i + n - 1))))
  |> Seq.map (Thm.adjust_maxidx_cterm ~1 #> init);

fun retrofit i n st' st =
  (if n = 1 then st
   else st |> Drule.with_subgoal i (Conjunction.uncurry_balanced n))
  |> Thm.compose_no_flatten false (conclude st', Thm.nprems_of st') i;

fun SELECT_GOAL tac i st =
  if Thm.nprems_of st = 1 andalso i = 1 then tac st
  else Seq.lifts (retrofit i 1) (Seq.maps tac (extract i 1 st)) st;


(* multiple goals *)

fun precise_conjunction_tac 0 i = eq_assume_tac i
  | precise_conjunction_tac 1 i = SUBGOAL (K all_tac) i
  | precise_conjunction_tac n i = PRIMITIVE (Drule.with_subgoal i (Conjunction.curry_balanced n));

val adhoc_conjunction_tac = REPEAT_ALL_NEW
  (SUBGOAL (fn (goal, i) =>
    if can Logic.dest_conjunction goal then rtac Conjunction.conjunctionI i
    else no_tac));

val conjunction_tac = SUBGOAL (fn (goal, i) =>
  precise_conjunction_tac (length (Logic.dest_conjunctions goal)) i ORELSE
  TRY (adhoc_conjunction_tac i));

val recover_conjunction_tac = PRIMITIVE (fn th =>
  Conjunction.uncurry_balanced (Thm.nprems_of th) th);

fun PRECISE_CONJUNCTS n tac =
  SELECT_GOAL (precise_conjunction_tac n 1
    THEN tac
    THEN recover_conjunction_tac);

fun CONJUNCTS tac =
  SELECT_GOAL (conjunction_tac 1
    THEN tac
    THEN recover_conjunction_tac);


(* hhf normal form *)

val norm_hhf_tac =
  rtac Drule.asm_rl  (*cheap approximation -- thanks to builtin Logic.flatten_params*)
  THEN' SUBGOAL (fn (t, i) =>
    if Drule.is_norm_hhf t then all_tac
    else rewrite_goal_tac Drule.norm_hhf_eqs i);

fun compose_hhf_tac th i st =
  PRIMSEQ (Thm.bicompose false (false, Drule.lift_all (Thm.cprem_of st i) th, 0) i) st;


(* non-atomic goal assumptions *)

fun non_atomic (Const ("==>", _) $ _ $ _) = true
  | non_atomic (Const ("all", _) $ _) = true
  | non_atomic _ = false;

fun assume_rule_tac ctxt = norm_hhf_tac THEN' CSUBGOAL (fn (goal, i) =>
  let
    val ((_, goal'), ctxt') = Variable.focus_cterm goal ctxt;
    val goal'' = Drule.cterm_rule (singleton (Variable.export ctxt' ctxt)) goal';
    val Rs = filter (non_atomic o Thm.term_of) (Drule.strip_imp_prems goal'');
    val tacs = Rs |> map (fn R =>
      Tactic.etac (Raw_Simplifier.norm_hhf (Thm.trivial R)) THEN_ALL_NEW assume_tac);
  in fold_rev (curry op APPEND') tacs (K no_tac) i end);


(* parallel tacticals *)

(*parallel choice of single results*)
fun PARALLEL_CHOICE tacs st =
  (case Par_List.get_some (fn tac => SINGLE tac st) tacs of
    NONE => Seq.empty
  | SOME st' => Seq.single st');

(*parallel refinement of non-schematic goal by single results*)
exception FAILED of unit;
fun PARALLEL_GOALS tac =
  Thm.adjust_maxidx_thm ~1 #>
  (fn st =>
    if not (Multithreading.enabled ()) orelse Thm.maxidx_of st >= 0 orelse Thm.nprems_of st <= 1
    then DETERM tac st
    else
      let
        fun try_tac g =
          (case SINGLE tac g of
            NONE => raise FAILED ()
          | SOME g' => g');

        val goals = Drule.strip_imp_prems (Thm.cprop_of st);
        val results = Par_List.map (try_tac o init) goals;
      in ALLGOALS (fn i => retrofit i 1 (nth results (i - 1))) st end
      handle FAILED () => Seq.empty);

end;

structure Basic_Goal: BASIC_GOAL = Goal;
open Basic_Goal;
