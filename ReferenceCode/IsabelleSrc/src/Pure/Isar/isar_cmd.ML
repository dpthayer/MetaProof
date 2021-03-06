(*  Title:      Pure/Isar/isar_cmd.ML
    Author:     Markus Wenzel, TU Muenchen

Miscellaneous Isar commands.
*)

signature ISAR_CMD =
sig
  val global_setup: Symbol_Pos.text * Position.T -> theory -> theory
  val local_setup: Symbol_Pos.text * Position.T -> Proof.context -> Proof.context
  val parse_ast_translation: bool * (Symbol_Pos.text * Position.T) -> theory -> theory
  val parse_translation: bool * (Symbol_Pos.text * Position.T) -> theory -> theory
  val print_translation: bool * (Symbol_Pos.text * Position.T) -> theory -> theory
  val typed_print_translation: bool * (Symbol_Pos.text * Position.T) -> theory -> theory
  val print_ast_translation: bool * (Symbol_Pos.text * Position.T) -> theory -> theory
  val translations: (xstring * string) Syntax.trrule list -> theory -> theory
  val no_translations: (xstring * string) Syntax.trrule list -> theory -> theory
  val oracle: bstring * Position.T -> Symbol_Pos.text * Position.T -> theory -> theory
  val add_defs: (bool * bool) * ((binding * string) * Attrib.src list) list -> theory -> theory
  val declaration: {syntax: bool, pervasive: bool} ->
    Symbol_Pos.text * Position.T -> local_theory -> local_theory
  val simproc_setup: string * Position.T -> string list -> Symbol_Pos.text * Position.T ->
    string list -> local_theory -> local_theory
  val hide_class: bool -> xstring list -> theory -> theory
  val hide_type: bool -> xstring list -> theory -> theory
  val hide_const: bool -> xstring list -> theory -> theory
  val hide_fact: bool -> xstring list -> theory -> theory
  val have: (Attrib.binding * (string * string list) list) list -> bool -> Proof.state -> Proof.state
  val hence: (Attrib.binding * (string * string list) list) list -> bool -> Proof.state -> Proof.state
  val show: (Attrib.binding * (string * string list) list) list -> bool -> Proof.state -> Proof.state
  val thus: (Attrib.binding * (string * string list) list) list -> bool -> Proof.state -> Proof.state
  val qed: Method.text_range option -> Toplevel.transition -> Toplevel.transition
  val terminal_proof: Method.text_range * Method.text_range option ->
    Toplevel.transition -> Toplevel.transition
  val default_proof: Toplevel.transition -> Toplevel.transition
  val immediate_proof: Toplevel.transition -> Toplevel.transition
  val done_proof: Toplevel.transition -> Toplevel.transition
  val skip_proof: Toplevel.transition -> Toplevel.transition
  val ml_diag: bool -> Symbol_Pos.text * Position.T -> Toplevel.transition -> Toplevel.transition
  val diag_state: Proof.context -> Toplevel.state
  val diag_goal: Proof.context -> {context: Proof.context, facts: thm list, goal: thm}
  val display_drafts: string list -> Toplevel.transition -> Toplevel.transition
  val print_drafts: string list -> Toplevel.transition -> Toplevel.transition
  val print_theorems: bool -> Toplevel.transition -> Toplevel.transition
  val thy_deps: Toplevel.transition -> Toplevel.transition
  val locale_deps: Toplevel.transition -> Toplevel.transition
  val class_deps: Toplevel.transition -> Toplevel.transition
  val thm_deps: (Facts.ref * Attrib.src list) list -> Toplevel.transition -> Toplevel.transition
  val unused_thms: (string list * string list option) option ->
    Toplevel.transition -> Toplevel.transition
  val print_stmts: string list * (Facts.ref * Attrib.src list) list
    -> Toplevel.transition -> Toplevel.transition
  val print_thms: string list * (Facts.ref * Attrib.src list) list
    -> Toplevel.transition -> Toplevel.transition
  val print_prfs: bool -> string list * (Facts.ref * Attrib.src list) list option
    -> Toplevel.transition -> Toplevel.transition
  val print_prop: (string list * string) -> Toplevel.transition -> Toplevel.transition
  val print_term: (string list * string) -> Toplevel.transition -> Toplevel.transition
  val print_type: (string list * (string * string option)) ->
    Toplevel.transition -> Toplevel.transition
  val header_markup: Symbol_Pos.text * Position.T -> Toplevel.transition -> Toplevel.transition
  val local_theory_markup: (xstring * Position.T) option * (Symbol_Pos.text * Position.T) ->
    Toplevel.transition -> Toplevel.transition
  val proof_markup: Symbol_Pos.text * Position.T -> Toplevel.transition -> Toplevel.transition
end;

structure Isar_Cmd: ISAR_CMD =
struct


(** theory declarations **)

(* generic setup *)

fun global_setup (txt, pos) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos "val setup: theory -> theory" "Context.map_theory setup"
  |> Context.theory_map;

fun local_setup (txt, pos) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos "val setup: local_theory -> local_theory" "Context.map_proof setup"
  |> Context.proof_map;


(* translation functions *)

local

fun advancedT false = ""
  | advancedT true = "Proof.context -> ";

fun advancedN false = ""
  | advancedN true = "advanced_";

in

fun parse_ast_translation (a, (txt, pos)) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    ("val parse_ast_translation: (string * (" ^ advancedT a ^
      "Ast.ast list -> Ast.ast)) list")
    ("Context.map_theory (Sign.add_" ^ advancedN a ^ "trfuns (parse_ast_translation, [], [], []))")
  |> Context.theory_map;

fun parse_translation (a, (txt, pos)) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    ("val parse_translation: (string * (" ^ advancedT a ^
      "term list -> term)) list")
    ("Context.map_theory (Sign.add_" ^ advancedN a ^ "trfuns ([], parse_translation, [], []))")
  |> Context.theory_map;

fun print_translation (a, (txt, pos)) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    ("val print_translation: (string * (" ^ advancedT a ^
      "term list -> term)) list")
    ("Context.map_theory (Sign.add_" ^ advancedN a ^ "trfuns ([], [], print_translation, []))")
  |> Context.theory_map;

fun print_ast_translation (a, (txt, pos)) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    ("val print_ast_translation: (string * (" ^ advancedT a ^
      "Ast.ast list -> Ast.ast)) list")
    ("Context.map_theory (Sign.add_" ^ advancedN a ^ "trfuns ([], [], [], print_ast_translation))")
  |> Context.theory_map;

fun typed_print_translation (a, (txt, pos)) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    ("val typed_print_translation: (string * (" ^ advancedT a ^ "typ -> term list -> term)) list")
    ("Context.map_theory (Sign.add_" ^ advancedN a ^ "trfunsT typed_print_translation)")
  |> Context.theory_map;

end;


(* translation rules *)

fun read_trrules thy raw_rules =
  let
    val ctxt = Proof_Context.init_global thy;
  in
    raw_rules |> map (Syntax.map_trrule (fn (r, s) =>
      Syntax_Phases.parse_ast_pattern ctxt (Proof_Context.intern_type ctxt r, s)))
  end;

fun translations args thy = Sign.add_trrules (read_trrules thy args) thy;
fun no_translations args thy = Sign.del_trrules (read_trrules thy args) thy;


(* oracles *)

fun oracle (name, pos) (body_txt, body_pos) =
  let
    val body = ML_Lex.read body_pos body_txt;
    val ants =
      ML_Lex.read Position.none
       ("local\n\
        \  val binding = " ^ ML_Syntax.make_binding (name, pos) ^ ";\n\
        \  val body = ") @ body @ ML_Lex.read Position.none (";\n\
        \in\n\
        \  val " ^ name ^ " = snd (Context.>>> (Context.map_theory_result (Thm.add_oracle (binding, body))));\n\
        \end;\n");
  in Context.theory_map (ML_Context.exec (fn () => ML_Context.eval false body_pos ants)) end;


(* old-style defs *)

fun add_defs ((unchecked, overloaded), args) thy =
  thy |>
    (if unchecked then Global_Theory.add_defs_unchecked_cmd else Global_Theory.add_defs_cmd)
      overloaded
      (map (fn ((b, ax), srcs) => ((b, ax), map (Attrib.attribute_cmd_global thy) srcs)) args)
  |> snd;


(* declarations *)

fun declaration {syntax, pervasive} (txt, pos) =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    "val declaration: Morphism.declaration"
    ("Context.map_proof (Local_Theory.declaration {syntax = " ^ Bool.toString syntax ^ ", \
      \pervasive = " ^ Bool.toString pervasive ^ "} declaration)")
  |> Context.proof_map;


(* simprocs *)

fun simproc_setup name lhss (txt, pos) identifier =
  ML_Lex.read pos txt
  |> ML_Context.expression pos
    "val proc: Morphism.morphism -> Simplifier.simpset -> cterm -> thm option"
    ("Context.map_proof (Simplifier.def_simproc_cmd {name = " ^ ML_Syntax.make_binding name ^ ", \
      \lhss = " ^ ML_Syntax.print_strings lhss ^ ", proc = proc, \
      \identifier = Library.maps ML_Context.thms " ^ ML_Syntax.print_strings identifier ^ "})")
  |> Context.proof_map;


(* hide names *)

fun hide_names intern check hide fully xnames thy =
  let
    val names = map (intern thy) xnames;
    val bads = filter_out (check thy) names;
  in
    if null bads then fold (hide fully) names thy
    else error ("Attempt to hide undeclared item(s): " ^ commas_quote bads)
  end;

val hide_class = hide_names Sign.intern_class (can o Sign.certify_class) Sign.hide_class;
val hide_type = hide_names Sign.intern_type Sign.declared_tyname Sign.hide_type;
val hide_const = hide_names Sign.intern_const Sign.declared_const Sign.hide_const;
val hide_fact =
  hide_names Global_Theory.intern_fact Global_Theory.defined_fact Global_Theory.hide_fact;


(* goals *)

fun goal opt_chain goal stmt int =
  opt_chain #> goal NONE (K I) stmt int;

val have = goal I Proof.have_cmd;
val hence = goal Proof.chain Proof.have_cmd;
val show = goal I Proof.show_cmd;
val thus = goal Proof.chain Proof.show_cmd;


(* local endings *)

fun local_qed m = Toplevel.proof (Proof.local_qed (m, true));
val local_terminal_proof = Toplevel.proof' o Proof.local_future_terminal_proof;
val local_default_proof = Toplevel.proof Proof.local_default_proof;
val local_immediate_proof = Toplevel.proof Proof.local_immediate_proof;
val local_done_proof = Toplevel.proof Proof.local_done_proof;
val local_skip_proof = Toplevel.proof' Proof.local_skip_proof;

val skip_local_qed = Toplevel.skip_proof (fn i => if i > 1 then i - 1 else raise Toplevel.UNDEF);


(* global endings *)

fun global_qed m = Toplevel.end_proof (K (Proof.global_qed (m, true)));
val global_terminal_proof = Toplevel.end_proof o Proof.global_future_terminal_proof;
val global_default_proof = Toplevel.end_proof (K Proof.global_default_proof);
val global_immediate_proof = Toplevel.end_proof (K Proof.global_immediate_proof);
val global_skip_proof = Toplevel.end_proof Proof.global_skip_proof;
val global_done_proof = Toplevel.end_proof (K Proof.global_done_proof);

val skip_global_qed = Toplevel.skip_proof_to_theory (fn n => n = 1);


(* common endings *)

fun qed m = local_qed m o global_qed m o skip_local_qed o skip_global_qed;
fun terminal_proof m = local_terminal_proof m o global_terminal_proof m;
val default_proof = local_default_proof o global_default_proof;
val immediate_proof = local_immediate_proof o global_immediate_proof;
val done_proof = local_done_proof o global_done_proof;
val skip_proof = local_skip_proof o global_skip_proof;


(* diagnostic ML evaluation *)

structure Diag_State = Proof_Data
(
  type T = Toplevel.state;
  fun init _ = Toplevel.toplevel;
);

fun ml_diag verbose (txt, pos) = Toplevel.keep (fn state =>
  let val opt_ctxt =
    try Toplevel.generic_theory_of state
    |> Option.map (Context.proof_of #> Diag_State.put state)
  in ML_Context.eval_text_in opt_ctxt verbose pos txt end);

val diag_state = Diag_State.get;

fun diag_goal ctxt =
  Proof.goal (Toplevel.proof_of (diag_state ctxt))
    handle Toplevel.UNDEF => error "No goal present";

val _ =
  Context.>> (Context.map_theory
   (ML_Antiquote.value (Binding.qualify true "Isar" (Binding.name "state"))
      (Scan.succeed "Isar_Cmd.diag_state ML_context") #>
    ML_Antiquote.value (Binding.qualify true "Isar" (Binding.name "goal"))
      (Scan.succeed "Isar_Cmd.diag_goal ML_context")));


(* present draft files *)

fun display_drafts names = Toplevel.imperative (fn () =>
  let
    val paths = map Path.explode names;
    val outfile = File.shell_path (Present.drafts (getenv "ISABELLE_DOC_FORMAT") paths);
  in Isabelle_System.isabelle_tool "display" ("-c " ^ outfile ^ " &"); () end);

fun print_drafts names = Toplevel.imperative (fn () =>
  let
    val paths = map Path.explode names;
    val outfile = File.shell_path (Present.drafts "ps" paths);
  in Isabelle_System.isabelle_tool "print" ("-c " ^ outfile); () end);


(* print theorems *)

val print_theorems_proof =
  Toplevel.keep (Proof_Context.print_lthms o Proof.context_of o Toplevel.proof_of);

fun print_theorems_theory verbose = Toplevel.keep (fn state =>
  Toplevel.theory_of state |>
  (case Toplevel.previous_context_of state of
    SOME prev => Proof_Display.print_theorems_diff verbose (Proof_Context.theory_of prev)
  | NONE => Proof_Display.print_theorems verbose));

fun print_theorems verbose =
  Toplevel.unknown_context o print_theorems_theory verbose o print_theorems_proof;


(* display dependencies *)

val thy_deps = Toplevel.unknown_theory o Toplevel.keep (fn state =>
  let
    val thy = Toplevel.theory_of state;
    val thy_session = Present.session_name thy;

    val gr = rev (Theory.nodes_of thy) |> map (fn node =>
      let
        val name = Context.theory_name node;
        val parents = map Context.theory_name (Theory.parents_of node);
        val session = Present.session_name node;
        val unfold = (session = thy_session);
      in
       {name = name, ID = name, parents = parents, dir = session,
        unfold = unfold, path = "", content = []}
      end);
  in Graph_Display.display_graph gr end);

val locale_deps = Toplevel.unknown_theory o Toplevel.keep (fn state =>
  let
    val thy = Toplevel.theory_of state;
    val gr = Locale.pretty_locale_deps thy |> map (fn {name, parents, body} =>
     {name = Locale.extern thy name, ID = name, parents = parents,
      dir = "", unfold = true, path = "", content = [body]});
  in Graph_Display.display_graph gr end);

val class_deps = Toplevel.unknown_theory o Toplevel.keep (fn state =>
  let
    val ctxt = Toplevel.context_of state;
    val {classes = (space, algebra), ...} = Type.rep_tsig (Proof_Context.tsig_of ctxt);
    val classes = Sorts.classes_of algebra;
    fun entry (c, (i, (_, cs))) =
      (i, {name = Name_Space.extern ctxt space c, ID = c, parents = Graph.Keys.dest cs,
            dir = "", unfold = true, path = "", content = []});
    val gr =
      Graph.fold (cons o entry) classes []
      |> sort (int_ord o pairself #1) |> map #2;
  in Graph_Display.display_graph gr end);

fun thm_deps args = Toplevel.unknown_theory o Toplevel.keep (fn state =>
  Thm_Deps.thm_deps (Toplevel.theory_of state)
    (Attrib.eval_thms (Toplevel.context_of state) args));


(* find unused theorems *)

fun unused_thms opt_range = Toplevel.keep (fn state =>
  let
    val thy = Toplevel.theory_of state;
    val ctxt = Toplevel.context_of state;
    fun pretty_thm (a, th) = Proof_Context.pretty_fact ctxt (a, [th]);
    val get_theory = Context.get_theory thy;
  in
    Thm_Deps.unused_thms
      (case opt_range of
        NONE => (Theory.parents_of thy, [thy])
      | SOME (xs, NONE) => (map get_theory xs, [thy])
      | SOME (xs, SOME ys) => (map get_theory xs, map get_theory ys))
    |> map pretty_thm |> Pretty.chunks |> Pretty.writeln
  end);


(* print theorems, terms, types etc. *)

local

fun string_of_stmts ctxt args =
  Attrib.eval_thms ctxt args
  |> map (Element.pretty_statement ctxt Thm.theoremK)
  |> Pretty.chunks2 |> Pretty.string_of;

fun string_of_thms ctxt args =
  Pretty.string_of (Display.pretty_thms ctxt (Attrib.eval_thms ctxt args));

fun string_of_prfs full state arg =
  Pretty.string_of
    (case arg of
      NONE =>
        let
          val {context = ctxt, goal = thm} = Proof.simple_goal (Toplevel.proof_of state);
          val thy = Proof_Context.theory_of ctxt;
          val prf = Thm.proof_of thm;
          val prop = Thm.full_prop_of thm;
          val prf' = Proofterm.rewrite_proof_notypes ([], []) prf;
        in
          Proof_Syntax.pretty_proof ctxt
            (if full then Reconstruct.reconstruct_proof thy prop prf' else prf')
        end
    | SOME srcs =>
        let val ctxt = Toplevel.context_of state
        in map (Proof_Syntax.pretty_proof_of ctxt full) (Attrib.eval_thms ctxt srcs) end
        |> Pretty.chunks);

fun string_of_prop ctxt s =
  let
    val prop = Syntax.read_prop ctxt s;
    val ctxt' = Variable.auto_fixes prop ctxt;
  in Pretty.string_of (Pretty.quote (Syntax.pretty_term ctxt' prop)) end;

fun string_of_term ctxt s =
  let
    val t = Syntax.read_term ctxt s;
    val T = Term.type_of t;
    val ctxt' = Variable.auto_fixes t ctxt;
  in
    Pretty.string_of
      (Pretty.block [Pretty.quote (Syntax.pretty_term ctxt' t), Pretty.fbrk,
        Pretty.str "::", Pretty.brk 1, Pretty.quote (Syntax.pretty_typ ctxt' T)])
  end;

fun string_of_type ctxt (s, NONE) =
      let val T = Syntax.read_typ ctxt s
      in Pretty.string_of (Pretty.quote (Syntax.pretty_typ ctxt T)) end
  | string_of_type ctxt (s1, SOME s2) =
      let
        val ctxt' = Config.put show_sorts true ctxt;
        val raw_T = Syntax.parse_typ ctxt' s1;
        val S = Syntax.read_sort ctxt' s2;
        val T =
          Syntax.check_term ctxt'
            (Logic.mk_type raw_T |> Type.constraint (Term.itselfT (Type_Infer.anyT S)))
          |> Logic.dest_type;
      in Pretty.string_of (Pretty.quote (Syntax.pretty_typ ctxt' T)) end;

fun print_item string_of (modes, arg) = Toplevel.keep (fn state =>
  Print_Mode.with_modes modes (fn () => writeln (string_of state arg)) ());

in

val print_stmts = print_item (string_of_stmts o Toplevel.context_of);
val print_thms = print_item (string_of_thms o Toplevel.context_of);
val print_prfs = print_item o string_of_prfs;
val print_prop = print_item (string_of_prop o Toplevel.context_of);
val print_term = print_item (string_of_term o Toplevel.context_of);
val print_type = print_item (string_of_type o Toplevel.context_of);

end;


(* markup commands *)

fun header_markup txt = Toplevel.keep (fn state =>
  if Toplevel.is_toplevel state then Thy_Output.check_text txt state
  else raise Toplevel.UNDEF);

fun local_theory_markup (loc, txt) = Toplevel.present_local_theory loc (Thy_Output.check_text txt);
val proof_markup = Toplevel.present_proof o Thy_Output.check_text;

end;
