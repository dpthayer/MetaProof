(*  Title:      HOL/Tools/Sledgehammer/sledgehammer_isar.ML
    Author:     Jasmin Blanchette, TU Muenchen

Adds "sledgehammer" and related commands to Isabelle/Isar's outer syntax.
*)

signature SLEDGEHAMMER_ISAR =
sig
  type params = Sledgehammer_Provers.params

  val auto : bool Unsynchronized.ref
  val provers : string Unsynchronized.ref
  val timeout : int Unsynchronized.ref
  val default_params : Proof.context -> (string * string) list -> params
  val setup : theory -> theory
end;

structure Sledgehammer_Isar : SLEDGEHAMMER_ISAR =
struct

open ATP_Util
open ATP_Systems
open ATP_Problem_Generate
open ATP_Proof_Reconstruct
open Sledgehammer_Util
open Sledgehammer_Fact
open Sledgehammer_Provers
open Sledgehammer_Minimize
open Sledgehammer_MaSh
open Sledgehammer_Run

(* val cvc3N = "cvc3" *)
val yicesN = "yices"
val z3N = "z3"

val runN = "run"
val minN = "min"
val messagesN = "messages"
val supported_proversN = "supported_provers"
val kill_allN = "kill_all"
val running_proversN = "running_provers"
val running_learnersN = "running_learners"
val refresh_tptpN = "refresh_tptp"

val auto = Unsynchronized.ref false

val _ =
  ProofGeneralPgip.add_preference Preferences.category_tracing
      (Preferences.bool_pref auto "auto-sledgehammer"
           "Run Sledgehammer automatically.")

(** Sledgehammer commands **)

fun add_fact_override ns : fact_override = {add = ns, del = [], only = false}
fun del_fact_override ns : fact_override = {add = [], del = ns, only = false}
fun only_fact_override ns : fact_override = {add = ns, del = [], only = true}
fun merge_fact_override_pairwise (r1 : fact_override) (r2 : fact_override) =
  {add = #add r1 @ #add r2, del = #del r1 @ #del r2,
   only = #only r1 andalso #only r2}
fun merge_fact_overrides rs =
  fold merge_fact_override_pairwise rs (only_fact_override [])

(*** parameters ***)

val provers = Unsynchronized.ref ""
val timeout = Unsynchronized.ref 30

val _ =
  ProofGeneralPgip.add_preference Preferences.category_proof
      (Preferences.string_pref provers
          "Sledgehammer: Provers"
          "Default automatic provers (separated by whitespace)")

val _ =
  ProofGeneralPgip.add_preference Preferences.category_proof
      (Preferences.int_pref timeout
          "Sledgehammer: Time Limit"
          "ATPs will be interrupted after this time (in seconds)")

type raw_param = string * string list

val default_default_params =
  [("debug", "false"),
   ("verbose", "false"),
   ("overlord", "false"),
   ("blocking", "false"),
   ("type_enc", "smart"),
   ("strict", "false"),
   ("lam_trans", "smart"),
   ("uncurried_aliases", "smart"),
   ("learn", "true"),
   ("fact_filter", "smart"),
   ("max_facts", "smart"),
   ("fact_thresholds", "0.45 0.85"),
   ("max_mono_iters", "smart"),
   ("max_new_mono_instances", "smart"),
   ("isar_proofs", "false"),
   ("isar_shrink", "10"),
   ("slice", "true"),
   ("minimize", "smart"),
   ("preplay_timeout", "3")]

val alias_params =
  [("prover", ("provers", [])), (* legacy *)
   ("max_relevant", ("max_facts", [])), (* legacy *)
   ("dont_preplay", ("preplay_timeout", ["0"]))]
val negated_alias_params =
  [("no_debug", "debug"),
   ("quiet", "verbose"),
   ("no_overlord", "overlord"),
   ("non_blocking", "blocking"),
   ("non_strict", "strict"),
   ("no_uncurried_aliases", "uncurried_aliases"),
   ("dont_learn", "learn"),
   ("no_isar_proofs", "isar_proofs"),
   ("dont_slice", "slice"),
   ("dont_minimize", "minimize")]

val params_for_minimize =
  ["debug", "verbose", "overlord", "type_enc", "strict", "lam_trans",
   "uncurried_aliases", "max_mono_iters", "max_new_mono_instances",
   "learn", "isar_proofs", "isar_shrink", "timeout", "preplay_timeout"]

val property_dependent_params = ["provers", "timeout"]

fun is_known_raw_param s =
  AList.defined (op =) default_default_params s orelse
  AList.defined (op =) alias_params s orelse
  AList.defined (op =) negated_alias_params s orelse
  member (op =) property_dependent_params s orelse s = "expect"

fun is_prover_list ctxt s =
  case space_explode " " s of
    ss as _ :: _ => forall (is_prover_supported ctxt) ss
  | _ => false

fun unalias_raw_param (name, value) =
  case AList.lookup (op =) alias_params name of
    SOME (name', []) => (name', value)
  | SOME (param' as (name', _)) =>
    if value <> ["false"] then
      param'
    else
      error ("Parameter " ^ quote name ^ " cannot be set to \"false\" \
             \(cf. " ^ quote name' ^ ").")
  | NONE =>
    case AList.lookup (op =) negated_alias_params name of
      SOME name' => (name', case value of
                              ["false"] => ["true"]
                            | ["true"] => ["false"]
                            | [] => ["false"]
                            | _ => value)
    | NONE => (name, value)

val any_type_enc = type_enc_from_string Strict "erased"

(* "provers =", "type_enc =", "lam_trans =", "fact_filter =", and "max_facts ="
   can be omitted. For the last four, this is a secret feature. *)
fun normalize_raw_param ctxt =
  unalias_raw_param
  #> (fn (name, value) =>
         if is_known_raw_param name then
           (name, value)
         else if null value then
           if is_prover_list ctxt name then
             ("provers", [name])
           else if can (type_enc_from_string Strict) name then
             ("type_enc", [name])
           else if can (trans_lams_from_string ctxt any_type_enc) name then
             ("lam_trans", [name])
           else if member (op =) fact_filters name then
             ("fact_filter", [name])
           else if is_some (Int.fromString name) then
             ("max_facts", [name])
           else
             error ("Unknown parameter: " ^ quote name ^ ".")
         else
           error ("Unknown parameter: " ^ quote name ^ "."))

(* Ensures that type encodings such as "mono_native?" and "poly_guards!!" are
   read correctly. *)
val implode_param = strip_spaces_except_between_idents o space_implode " "

structure Data = Theory_Data
(
  type T = raw_param list
  val empty = default_default_params |> map (apsnd single)
  val extend = I
  fun merge data : T = AList.merge (op =) (K true) data
)

fun remotify_prover_if_supported_and_not_already_remote ctxt name =
  if String.isPrefix remote_prefix name then
    SOME name
  else
    let val remote_name = remote_prefix ^ name in
      if is_prover_supported ctxt remote_name then SOME remote_name else NONE
    end

fun remotify_prover_if_not_installed ctxt name =
  if is_prover_supported ctxt name andalso is_prover_installed ctxt name then
    SOME name
  else
    remotify_prover_if_supported_and_not_already_remote ctxt name

fun avoid_too_many_threads _ _ [] = []
  | avoid_too_many_threads _ (0, 0) _ = []
  | avoid_too_many_threads ctxt (0, max_remote) provers =
    provers
    |> map_filter (remotify_prover_if_supported_and_not_already_remote ctxt)
    |> take max_remote
  | avoid_too_many_threads _ (max_local, 0) provers =
    provers
    |> filter_out (String.isPrefix remote_prefix)
    |> take max_local
  | avoid_too_many_threads ctxt max_local_and_remote (prover :: provers) =
    let
      val max_local_and_remote =
        max_local_and_remote
        |> (if String.isPrefix remote_prefix prover then apsnd else apfst)
               (Integer.add ~1)
    in prover :: avoid_too_many_threads ctxt max_local_and_remote provers end

val max_default_remote_threads = 4

(* The first ATP of the list is used by Auto Sledgehammer. Because of the low
   timeout, it makes sense to put E first. *)
fun default_provers_param_value ctxt =
  [eN, spassN, vampireN, z3N, e_sineN, waldmeisterN, yicesN]
  |> map_filter (remotify_prover_if_not_installed ctxt)
  |> avoid_too_many_threads ctxt (Multithreading.max_threads_value (),
                                  max_default_remote_threads)
  |> implode_param

fun set_default_raw_param param thy =
  let val ctxt = Proof_Context.init_global thy in
    thy |> Data.map (AList.update (op =) (normalize_raw_param ctxt param))
  end
fun default_raw_params ctxt =
  let val thy = Proof_Context.theory_of ctxt in
    Data.get thy
    |> fold (AList.default (op =))
            [("provers", [case !provers of
                            "" => default_provers_param_value ctxt
                          | s => s]),
             ("timeout", let val timeout = !timeout in
                           [if timeout <= 0 then "none"
                            else string_of_int timeout]
                         end)]
  end

fun extract_params mode default_params override_params =
  let
    val raw_params = rev override_params @ rev default_params
    val lookup = Option.map implode_param o AList.lookup (op =) raw_params
    val lookup_string = the_default "" o lookup
    fun general_lookup_bool option default_value name =
      case lookup name of
        SOME s => parse_bool_option option name s
      | NONE => default_value
    val lookup_bool = the o general_lookup_bool false (SOME false)
    fun lookup_time name =
      case lookup name of
        SOME s => parse_time_option name s
      | NONE => NONE
    fun lookup_int name =
      case lookup name of
        NONE => 0
      | SOME s => case Int.fromString s of
                    SOME n => n
                  | NONE => error ("Parameter " ^ quote name ^
                                   " must be assigned an integer value.")
    fun lookup_real name =
      case lookup name of
        NONE => 0.0
      | SOME s => case Real.fromString s of
                    SOME n => n
                  | NONE => error ("Parameter " ^ quote name ^
                                   " must be assigned a real value.")
    fun lookup_real_pair name =
      case lookup name of
        NONE => (0.0, 0.0)
      | SOME s => case s |> space_explode " " |> map Real.fromString of
                    [SOME r1, SOME r2] => (r1, r2)
                  | _ => error ("Parameter " ^ quote name ^
                                " must be assigned a pair of floating-point \
                                \values (e.g., \"0.6 0.95\")")
    fun lookup_option lookup' name =
      case lookup name of
        SOME "smart" => NONE
      | _ => SOME (lookup' name)
    val debug = mode <> Auto_Try andalso lookup_bool "debug"
    val verbose = debug orelse (mode <> Auto_Try andalso lookup_bool "verbose")
    val overlord = lookup_bool "overlord"
    val blocking =
      Isabelle_Process.is_active () orelse mode <> Normal orelse debug orelse
      lookup_bool "blocking"
    val provers = lookup_string "provers" |> space_explode " "
                  |> mode = Auto_Try ? single o hd
    val type_enc =
      if mode = Auto_Try then
        NONE
      else case lookup_string "type_enc" of
        "smart" => NONE
      | s => (type_enc_from_string Strict s; SOME s)
    val strict = mode = Auto_Try orelse lookup_bool "strict"
    val lam_trans = lookup_option lookup_string "lam_trans"
    val uncurried_aliases = lookup_option lookup_bool "uncurried_aliases"
    val learn = lookup_bool "learn"
    val fact_filter = lookup_option lookup_string "fact_filter"
    val max_facts = lookup_option lookup_int "max_facts"
    val fact_thresholds = lookup_real_pair "fact_thresholds"
    val max_mono_iters = lookup_option lookup_int "max_mono_iters"
    val max_new_mono_instances =
      lookup_option lookup_int "max_new_mono_instances"
    val isar_proofs = lookup_bool "isar_proofs"
    val isar_shrink = Real.max (1.0, lookup_real "isar_shrink")
    val slice = mode <> Auto_Try andalso lookup_bool "slice"
    val minimize =
      if mode = Auto_Try then NONE else lookup_option lookup_bool "minimize"
    val timeout = if mode = Auto_Try then NONE else lookup_time "timeout"
    val preplay_timeout =
      if mode = Auto_Try then SOME Time.zeroTime
      else lookup_time "preplay_timeout"
    val expect = lookup_string "expect"
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

fun get_params mode = extract_params mode o default_raw_params
fun default_params thy = get_params Normal thy o map (apsnd single)

(* Sledgehammer the given subgoal *)

val default_minimize_prover = metisN

fun is_raw_param_relevant_for_minimize (name, _) =
  member (op =) params_for_minimize name
fun string_for_raw_param (key, values) =
  key ^ (case implode_param values of "" => "" | value => " = " ^ value)
fun nice_string_for_raw_param (p as (key, ["false"])) =
    (case AList.find (op =) negated_alias_params key of
       [neg] => neg
     | _ => string_for_raw_param p)
  | nice_string_for_raw_param p = string_for_raw_param p

fun minimize_command override_params i more_override_params prover_name
                     fact_names =
  let
    val params =
      (override_params
       |> filter_out (AList.defined (op =) more_override_params o fst)) @
      more_override_params
      |> filter is_raw_param_relevant_for_minimize
      |> map nice_string_for_raw_param
      |> (if prover_name = default_minimize_prover then I else cons prover_name)
      |> space_implode ", "
  in
    sledgehammerN ^ " " ^ minN ^
    (if params = "" then "" else enclose " [" "]" params) ^
    " (" ^ space_implode " " fact_names ^ ")" ^
    (if i = 1 then "" else " " ^ string_of_int i)
  end

val default_learn_prover_timeout = 2.0

fun hammer_away override_params subcommand opt_i fact_override state =
  let
    (* necessary to avoid problems in jedit *)
    val state = state |> Proof.map_context (Config.put show_markup false)
    val ctxt = Proof.context_of state
    val override_params = override_params |> map (normalize_raw_param ctxt)
    val _ = Isabelle_System.mkdir (Path.explode (getenv "ISABELLE_TMP"))
  in
    if subcommand = runN then
      let val i = the_default 1 opt_i in
        run_sledgehammer (get_params Normal ctxt override_params) Normal i
                         fact_override (minimize_command override_params i)
                         state
        |> K ()
      end
    else if subcommand = minN then
      let
        val ctxt = ctxt |> Config.put instantiate_inducts false
        val i = the_default 1 opt_i
        val params =
          get_params Minimize ctxt (("provers", [default_minimize_prover]) ::
                                    override_params)
        val goal = prop_of (#goal (Proof.goal state))
        val facts = nearly_all_facts ctxt false fact_override Symtab.empty
                                     Termtab.empty [] [] goal
        fun learn prover = mash_learn_proof ctxt params prover goal facts
      in run_minimize params learn i (#add fact_override) state end
    else if subcommand = messagesN then
      messages opt_i
    else if subcommand = supported_proversN then
      supported_provers ctxt
    else if subcommand = kill_allN then
      (kill_provers (); kill_learners ())
    else if subcommand = running_proversN then
      running_provers ()
    else if subcommand = unlearnN then
      mash_unlearn ctxt
    else if subcommand = learn_isarN orelse subcommand = learn_proverN orelse
            subcommand = relearn_isarN orelse subcommand = relearn_proverN then
      (if subcommand = relearn_isarN orelse subcommand = relearn_proverN then
         mash_unlearn ctxt
       else
         ();
       mash_learn ctxt
           (get_params Normal ctxt
                ([("timeout",
                   [string_of_real default_learn_prover_timeout]),
                  ("slice", ["false"])] @
                 override_params @
                 [("minimize", ["true"]),
                  ("preplay_timeout", ["0"])]))
           fact_override (#facts (Proof.goal state))
           (subcommand = learn_proverN orelse subcommand = relearn_proverN))
    else if subcommand = running_learnersN then
      running_learners ()
    else if subcommand = refresh_tptpN then
      refresh_systems_on_tptp ()
    else
      error ("Unknown subcommand: " ^ quote subcommand ^ ".")
  end

fun sledgehammer_trans (((subcommand, params), fact_override), opt_i) =
  Toplevel.keep (hammer_away params subcommand opt_i fact_override
                 o Toplevel.proof_of)

fun string_for_raw_param (name, value) = name ^ " = " ^ implode_param value

fun sledgehammer_params_trans params =
  Toplevel.theory
      (fold set_default_raw_param params
       #> tap (fn thy =>
                  let val ctxt = Proof_Context.init_global thy in
                    writeln ("Default parameters for Sledgehammer:\n" ^
                             (case default_raw_params ctxt |> rev of
                                [] => "none"
                              | params =>
                                params |> map string_for_raw_param
                                       |> sort_strings |> cat_lines))
                  end))

val parse_query_bang = @{keyword "?"} || @{keyword "!"} || @{keyword "!!"}
val parse_key =
  Scan.repeat1 (Parse.typ_group || parse_query_bang) >> implode_param
val parse_value =
  Scan.repeat1 (Parse.xname || Parse.float_number || parse_query_bang)
val parse_param = parse_key -- Scan.optional (@{keyword "="} |-- parse_value) []
val parse_params = Scan.optional (Args.bracks (Parse.list parse_param)) []
val parse_fact_refs =
  Scan.repeat1 (Scan.unless (Parse.name -- Args.colon) Parse_Spec.xthm)
val parse_fact_override_chunk =
  (Args.add |-- Args.colon |-- parse_fact_refs >> add_fact_override)
  || (Args.del |-- Args.colon |-- parse_fact_refs >> del_fact_override)
  || (parse_fact_refs >> only_fact_override)
val parse_fact_override =
  Scan.optional (Args.parens (Scan.repeat parse_fact_override_chunk
                              >> merge_fact_overrides))
                no_fact_override

val _ =
  Outer_Syntax.improper_command @{command_spec "sledgehammer"}
    "search for first-order proof using automatic theorem provers"
    ((Scan.optional Parse.short_ident runN -- parse_params
      -- parse_fact_override -- Scan.option Parse.nat) #>> sledgehammer_trans)
val _ =
  Outer_Syntax.command @{command_spec "sledgehammer_params"}
    "set and display the default parameters for Sledgehammer"
    (parse_params #>> sledgehammer_params_trans)

fun try_sledgehammer auto state =
  let
    val ctxt = Proof.context_of state
    val mode = if auto then Auto_Try else Try
    val i = 1
  in
    run_sledgehammer (get_params mode ctxt []) mode i no_fact_override
                     (minimize_command [] i) state
  end

val setup = Try.register_tool (sledgehammerN, (40, auto, try_sledgehammer))

end;
