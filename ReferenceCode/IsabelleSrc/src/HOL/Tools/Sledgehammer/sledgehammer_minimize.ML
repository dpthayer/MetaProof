(*  Title:      HOL/Tools/Sledgehammer/sledgehammer_minimize.ML
    Author:     Philipp Meyer, TU Muenchen
    Author:     Jasmin Blanchette, TU Muenchen

Minimization of fact list for Metis using external provers.
*)

signature SLEDGEHAMMER_MINIMIZE =
sig
  type stature = ATP_Problem_Generate.stature
  type play = Sledgehammer_Reconstruct.play
  type mode = Sledgehammer_Provers.mode
  type params = Sledgehammer_Provers.params
  type prover = Sledgehammer_Provers.prover

  val binary_min_facts : int Config.T
  val auto_minimize_min_facts : int Config.T
  val auto_minimize_max_time : real Config.T
  val minimize_facts :
    (string -> thm list -> unit) -> string -> params -> bool -> int -> int
    -> Proof.state -> ((string * stature) * thm list) list
    -> ((string * stature) * thm list) list option
       * (play Lazy.lazy * (play -> string) * string)
  val get_minimizing_isar_prover :
    Proof.context -> mode -> (string -> thm list -> unit) -> string -> prover
  val run_minimize :
    params -> (string -> thm list -> unit) -> int
    -> (Facts.ref * Attrib.src list) list -> Proof.state -> unit
end;

structure Sledgehammer_Minimize : SLEDGEHAMMER_MINIMIZE =
struct

open ATP_Util
open ATP_Proof
open ATP_Problem_Generate
open Sledgehammer_Util
open Sledgehammer_Fact
open Sledgehammer_Reconstruct
open Sledgehammer_Provers

(* wrapper for calling external prover *)

fun n_facts names =
  let val n = length names in
    string_of_int n ^ " fact" ^ plural_s n ^
    (if n > 0 then
       ": " ^ (names |> map fst |> sort string_ord |> space_implode " ")
     else
       "")
  end

fun print silent f = if silent then () else Output.urgent_message (f ())

fun test_facts ({debug, verbose, overlord, provers, max_mono_iters,
                 max_new_mono_instances, type_enc, strict, lam_trans,
                 uncurried_aliases, isar_proofs, isar_shrink,
                 preplay_timeout, ...} : params)
               silent (prover : prover) timeout i n state facts =
  let
    val _ =
      print silent (fn () =>
          "Testing " ^ n_facts (map fst facts) ^
          (if verbose then
             case timeout of
               SOME timeout => " (timeout: " ^ string_from_time timeout ^ ")"
             | _ => ""
           else
             "") ^ "...")
    val {goal, ...} = Proof.goal state
    val facts =
      facts |> maps (fn (n, ths) => ths |> map (Untranslated_Fact o pair n))
    val params =
      {debug = debug, verbose = verbose, overlord = overlord, blocking = true,
       provers = provers, type_enc = type_enc, strict = strict,
       lam_trans = lam_trans, uncurried_aliases = uncurried_aliases,
       learn = false, fact_filter = NONE, max_facts = SOME (length facts),
       fact_thresholds = (1.01, 1.01), max_mono_iters = max_mono_iters,
       max_new_mono_instances = max_new_mono_instances,
       isar_proofs = isar_proofs, isar_shrink = isar_shrink,
       slice = false, minimize = SOME false, timeout = timeout,
       preplay_timeout = preplay_timeout, expect = ""}
    val problem =
      {state = state, goal = goal, subgoal = i, subgoal_count = n,
       facts = facts}
    val result as {outcome, used_facts, run_time, ...} =
      prover params (K (K (K ""))) problem
  in
    print silent
          (fn () =>
              case outcome of
                SOME failure => string_for_failure failure
              | NONE =>
                "Found proof" ^
                 (if length used_facts = length facts then ""
                  else " with " ^ n_facts used_facts) ^
                 " (" ^ string_from_time run_time ^ ").");
    result
  end

(* minimalization of facts *)

(* Give the external prover some slack. The ATP gets further slack because the
   Sledgehammer preprocessing time is included in the estimate below but isn't
   part of the timeout. *)
val slack_msecs = 200

fun new_timeout NONE _ = NONE
  | new_timeout (SOME timeout) run_time =
    Int.min (Time.toMilliseconds timeout,
             Time.toMilliseconds run_time + slack_msecs)
    |> Time.fromMilliseconds |> SOME

(* The linear algorithm usually outperforms the binary algorithm when over 60%
   of the facts are actually needed. The binary algorithm is much more
   appropriate for provers that cannot return the list of used facts and hence
   returns all facts as used. Since we cannot know in advance how many facts are
   actually needed, we heuristically set the threshold to 10 facts. *)
val binary_min_facts =
  Attrib.setup_config_int @{binding sledgehammer_minimize_binary_min_facts}
                          (K 20)
val auto_minimize_min_facts =
  Attrib.setup_config_int @{binding sledgehammer_auto_minimize_min_facts}
      (fn generic => Config.get_generic generic binary_min_facts)
val auto_minimize_max_time =
  Attrib.setup_config_real @{binding sledgehammer_auto_minimize_max_time}
                           (K 5.0)

fun linear_minimize test timeout result xs =
  let
    fun min _ [] p = p
      | min timeout (x :: xs) (seen, result) =
        case test timeout (xs @ seen) of
          result as {outcome = NONE, used_facts, run_time, ...}
          : prover_result =>
          min (new_timeout timeout run_time)
              (filter_used_facts true used_facts xs)
              (filter_used_facts false used_facts seen, result)
        | _ => min timeout xs (x :: seen, result)
  in min timeout xs ([], result) end

fun binary_minimize test timeout result xs =
  let
    fun min depth (result as {run_time, ...} : prover_result) sup
            (xs as _ :: _ :: _) =
        let
          val (l0, r0) = chop (length xs div 2) xs
(*
          val _ = warning (replicate_string depth " " ^ "{ " ^
                           "sup: " ^ n_facts (map fst sup))
          val _ = warning (replicate_string depth " " ^ "  " ^
                           "xs: " ^ n_facts (map fst xs))
          val _ = warning (replicate_string depth " " ^ "  " ^
                           "l0: " ^ n_facts (map fst l0))
          val _ = warning (replicate_string depth " " ^ "  " ^
                           "r0: " ^ n_facts (map fst r0))
*)
          val depth = depth + 1
          val timeout = new_timeout timeout run_time
        in
          case test timeout (sup @ l0) of
            result as {outcome = NONE, used_facts, ...} =>
            min depth result (filter_used_facts true used_facts sup)
                      (filter_used_facts true used_facts l0)
          | _ =>
            case test timeout (sup @ r0) of
              result as {outcome = NONE, used_facts, ...} =>
              min depth result (filter_used_facts true used_facts sup)
                        (filter_used_facts true used_facts r0)
            | _ =>
              let
                val (sup_r0, (l, result)) = min depth result (sup @ r0) l0
                val (sup, r0) =
                  (sup, r0)
                  |> pairself (filter_used_facts true (map fst sup_r0))
                val (sup_l, (r, result)) = min depth result (sup @ l) r0
                val sup = sup |> filter_used_facts true (map fst sup_l)
              in (sup, (l @ r, result)) end
        end
(*
        |> tap (fn _ => warning (replicate_string depth " " ^ "}"))
*)
      | min _ result sup xs = (sup, (xs, result))
  in
    case snd (min 0 result [] xs) of
      ([x], result as {run_time, ...}) =>
      (case test (new_timeout timeout run_time) [] of
         result as {outcome = NONE, ...} => ([], result)
       | _ => ([x], result))
    | p => p
  end

fun minimize_facts do_learn prover_name (params as {learn, timeout, ...}) silent
                   i n state facts =
  let
    val ctxt = Proof.context_of state
    val prover =
      get_prover ctxt (if silent then Auto_Minimize else Minimize) prover_name
    fun test timeout = test_facts params silent prover timeout i n state
    val (chained, non_chained) = List.partition is_fact_chained facts
    (* Push chained facts to the back, so that they are less likely to be
       kicked out by the linear minimization algorithm. *)
    val facts = non_chained @ chained
  in
    (print silent (fn () => "Sledgehammer minimizer: " ^
                            quote prover_name ^ ".");
     case test timeout facts of
       result as {outcome = NONE, used_facts, run_time, ...} =>
       let
         val facts = filter_used_facts true used_facts facts
         val min =
           if length facts >= Config.get ctxt binary_min_facts then
             binary_minimize
           else
             linear_minimize
         val (min_facts, {preplay, message, message_tail, ...}) =
           min test (new_timeout timeout run_time) result facts
       in
         print silent (fn () => cat_lines
             ["Minimized to " ^ n_facts (map fst min_facts)] ^
              (case min_facts |> filter is_fact_chained |> length of
                 0 => ""
               | n => "\n(including " ^ string_of_int n ^ " chained)") ^ ".");
         (if learn then do_learn prover_name (maps snd min_facts) else ());
         (SOME min_facts, (preplay, message, message_tail))
       end
     | {outcome = SOME TimedOut, preplay, ...} =>
       (NONE,
        (preplay,
         fn _ =>
            "Timeout: You can increase the time limit using the \"timeout\" \
            \option (e.g., \"timeout = " ^
            string_of_int (10 + Time.toMilliseconds
                (timeout |> the_default (seconds 60.0)) div 1000) ^
            "\").", ""))
     | {preplay, message, ...} =>
       (NONE, (preplay, prefix "Prover error: " o message, "")))
    handle ERROR msg =>
           (NONE, (Lazy.value (Failed_to_Play plain_metis),
            fn _ => "Error: " ^ msg, ""))
  end

fun adjust_reconstructor_params override_params
        ({debug, verbose, overlord, blocking, provers, type_enc, strict,
         lam_trans, uncurried_aliases, learn, fact_filter, max_facts,
         fact_thresholds, max_mono_iters, max_new_mono_instances, isar_proofs,
         isar_shrink, slice, minimize, timeout, preplay_timeout, expect}
         : params) =
  let
    fun lookup_override name default_value =
      case AList.lookup (op =) override_params name of
        SOME [s] => SOME s
      | _ => default_value
    (* Only those options that reconstructors are interested in are considered
       here. *)
    val type_enc = lookup_override "type_enc" type_enc
    val lam_trans = lookup_override "lam_trans" lam_trans
  in
    {debug = debug, verbose = verbose, overlord = overlord, blocking = blocking,
     provers = provers, type_enc = type_enc, strict = strict,
     lam_trans = lam_trans, uncurried_aliases = uncurried_aliases,
     learn = learn, fact_filter = fact_filter, max_facts = max_facts,
     fact_thresholds = fact_thresholds, max_mono_iters = max_mono_iters,
     max_new_mono_instances = max_new_mono_instances, isar_proofs = isar_proofs,
     isar_shrink = isar_shrink, slice = slice, minimize = minimize,
     timeout = timeout, preplay_timeout = preplay_timeout, expect = expect}
  end

fun maybe_minimize ctxt mode do_learn name
        (params as {verbose, isar_proofs, minimize, ...})
        ({state, subgoal, subgoal_count, facts, ...} : prover_problem)
        (result as {outcome, used_facts, run_time, preplay, message,
                    message_tail} : prover_result) =
  if is_some outcome orelse null used_facts then
    result
  else
    let
      val num_facts = length used_facts
      val ((perhaps_minimize, (minimize_name, params)), preplay) =
        if mode = Normal then
          if num_facts >= Config.get ctxt auto_minimize_min_facts then
            ((true, (name, params)), preplay)
          else
            let
              fun can_min_fast_enough time =
                0.001
                * Real.fromInt ((num_facts + 1) * Time.toMilliseconds time)
                <= Config.get ctxt auto_minimize_max_time
              fun prover_fast_enough () = can_min_fast_enough run_time
            in
              if isar_proofs then
                ((prover_fast_enough (), (name, params)), preplay)
              else
                (case Lazy.force preplay of
                   Played (reconstr, timeout) =>
                   if can_min_fast_enough timeout then
                     (true, extract_reconstructor params reconstr
                            ||> (fn override_params =>
                                    adjust_reconstructor_params
                                        override_params params))
                   else
                     (prover_fast_enough (), (name, params))
                 | _ => (prover_fast_enough (), (name, params)),
                 preplay)
            end
        else
          ((false, (name, params)), preplay)
      val minimize = minimize |> the_default perhaps_minimize
      val (used_facts, (preplay, message, _)) =
        if minimize then
          minimize_facts do_learn minimize_name params
                         (mode <> Normal orelse not verbose) subgoal
                         subgoal_count state
                         (filter_used_facts true used_facts
                              (map (apsnd single o untranslated_fact) facts))
          |>> Option.map (map fst)
        else
          (SOME used_facts, (preplay, message, ""))
    in
      case used_facts of
        SOME used_facts =>
        {outcome = NONE, used_facts = used_facts, run_time = run_time,
         preplay = preplay, message = message, message_tail = message_tail}
      | NONE => result
    end

(* TODO: implement *)
fun maybe_regenerate_isar_proof result = result

fun get_minimizing_isar_prover ctxt mode do_learn name params minimize_command
                               problem =
  get_prover ctxt mode name params minimize_command problem
  |> maybe_minimize ctxt mode do_learn name params problem
  |> maybe_regenerate_isar_proof

fun run_minimize (params as {provers, ...}) do_learn i refs state =
  let
    val ctxt = Proof.context_of state
    val reserved = reserved_isar_keyword_table ()
    val chained_ths = #facts (Proof.goal state)
    val css = clasimpset_rule_table_of ctxt
    val facts =
      refs |> maps (map (apsnd single)
                    o fact_from_ref ctxt reserved chained_ths css)
  in
    case subgoal_count state of
      0 => Output.urgent_message "No subgoal!"
    | n => case provers of
             [] => error "No prover is set."
           | prover :: _ =>
             (kill_provers ();
              minimize_facts do_learn prover params false i n state facts
              |> (fn (_, (preplay, message, message_tail)) =>
                     message (Lazy.force preplay) ^ message_tail
                     |> Output.urgent_message))
  end

end;
