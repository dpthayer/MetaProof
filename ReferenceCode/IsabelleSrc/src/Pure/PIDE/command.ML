(*  Title:      Pure/PIDE/command.ML
    Author:     Makarius

Prover command execution.
*)

signature COMMAND =
sig
  val range: Token.T list -> Position.range
  val proper_range: Token.T list -> Position.range
  type 'a memo
  val memo: (unit -> 'a) -> 'a memo
  val memo_value: 'a -> 'a memo
  val memo_eval: 'a memo -> 'a
  val memo_result: 'a memo -> 'a
  val run_command: Toplevel.transition * Token.T list ->
    Toplevel.state * bool -> (Toplevel.state * bool) * unit lazy
end;

structure Command: COMMAND =
struct

(* span range *)

val range = Token.position_range_of;
val proper_range = Token.position_range_of o #1 o take_suffix Token.is_space;


(* memo results *)

datatype 'a expr =
  Expr of unit -> 'a |
  Result of 'a Exn.result;

abstype 'a memo = Memo of 'a expr Synchronized.var
with

fun memo e = Memo (Synchronized.var "Command.memo" (Expr e));
fun memo_value a = Memo (Synchronized.var "Command.memo" (Result (Exn.Res a)));

fun memo_eval (Memo v) =
  (case Synchronized.value v of
    Result res => res
  | _ =>
      Synchronized.guarded_access v
        (fn Result res => SOME (res, Result res)
          | Expr e =>
              let val res = Exn.capture e ();  (*memoing of physical interrupts!*)
              in SOME (res, Result res) end))
  |> Exn.release;

fun memo_result (Memo v) =
  (case Synchronized.value v of
    Result res => Exn.release res
  | _ => raise Fail "Unfinished memo result");

end;


(* run command *)

local

fun run int tr st =
  (case Toplevel.transition int tr st of
    SOME (st', NONE) => ([], SOME st')
  | SOME (_, SOME (exn, _)) => (ML_Compiler.exn_messages_ids exn, NONE)
  | NONE => (ML_Compiler.exn_messages_ids Runtime.TERMINATE, NONE));

fun check_cmts tr cmts st =
  Toplevel.setmp_thread_position tr
    (fn () => cmts
      |> maps (fn cmt =>
        (Thy_Output.check_text (Token.source_position_of cmt) st; [])
          handle exn => ML_Compiler.exn_messages_ids exn)) ();

fun timing tr t =
  if Timing.is_relevant t then Toplevel.status tr (Markup.timing t) else ();

fun proof_status tr st =
  (case try Toplevel.proof_of st of
    SOME prf => Toplevel.status tr (Proof.status_markup prf)
  | NONE => ());

val no_print = Lazy.value ();

fun print_state tr st =
  (Lazy.lazy o Toplevel.setmp_thread_position tr)
    (fn () => Toplevel.print_state false st);

in

fun run_command (tr, cmts) (st, malformed) =
  if malformed then ((Toplevel.toplevel, malformed), no_print)
  else
    let
      val malformed' = Toplevel.is_malformed tr;
      val is_init = Toplevel.is_init tr;
      val is_proof = Keyword.is_proof (Toplevel.name_of tr);

      val _ = Multithreading.interrupted ();
      val _ = Toplevel.status tr Markup.running;
      val start = Timing.start ();
      val (errs1, result) = run (is_init orelse is_proof) (Toplevel.set_print false tr) st;
      val errs2 = (case result of NONE => [] | SOME st' => check_cmts tr cmts st');
      val errs = errs1 @ errs2;
      val _ = timing tr (Timing.result start);
      val _ = Toplevel.status tr Markup.finished;
      val _ = List.app (Future.error_msg (Toplevel.pos_of tr)) errs;
    in
      (case result of
        NONE =>
          let
            val _ = if null errs then Exn.interrupt () else ();
            val _ = Toplevel.status tr Markup.failed;
          in ((st, malformed'), no_print) end
      | SOME st' =>
          let
            val _ = proof_status tr st';
            val do_print =
              not is_init andalso
                (Toplevel.print_of tr orelse (is_proof andalso Toplevel.is_proof st'));
          in ((st', malformed'), if do_print then print_state tr st' else no_print) end)
    end;

end;

end;

