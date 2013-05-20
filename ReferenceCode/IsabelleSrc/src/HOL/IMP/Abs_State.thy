(* Author: Tobias Nipkow *)

theory Abs_State
imports Abs_Int0
begin

subsubsection "Set-based lattices"

instantiation com :: vars
begin

fun vars_com :: "com \<Rightarrow> vname set" where
"vars com.SKIP = {}" |
"vars (x::=e) = {x} \<union> vars e" |
"vars (c1;c2) = vars c1 \<union> vars c2" |
"vars (IF b THEN c1 ELSE c2) = vars b \<union> vars c1 \<union> vars c2" |
"vars (WHILE b DO c) = vars b \<union> vars c"

instance ..

end


lemma finite_avars: "finite(vars(a::aexp))"
by(induction a) simp_all

lemma finite_bvars: "finite(vars(b::bexp))"
by(induction b) (simp_all add: finite_avars)

lemma finite_cvars: "finite(vars(c::com))"
by(induction c) (simp_all add: finite_avars finite_bvars)


class L =
fixes L :: "vname set \<Rightarrow> 'a set"


instantiation acom :: (L)L
begin

definition L_acom where
"L X = {C. vars(strip C) \<subseteq> X \<and> (\<forall>a \<in> set(annos C). a \<in> L X)}"

instance ..

end


instantiation option :: (L)L
begin

definition L_option where
"L X = {opt. case opt of None \<Rightarrow> True | Some x \<Rightarrow> x \<in> L X}"

lemma L_option_simps[simp]: "None \<in> L X" "(Some x \<in> L X) = (x \<in> L X)"
by(simp_all add: L_option_def)

instance ..

end

class semilatticeL = join + L +
fixes top :: "com \<Rightarrow> 'a"
assumes join_ge1 [simp]: "x \<in> L X \<Longrightarrow> y \<in> L X \<Longrightarrow> x \<sqsubseteq> x \<squnion> y"
and join_ge2 [simp]: "x \<in> L X \<Longrightarrow> y \<in> L X \<Longrightarrow> y \<sqsubseteq> x \<squnion> y"
and join_least[simp]: "x \<sqsubseteq> z \<Longrightarrow> y \<sqsubseteq> z \<Longrightarrow> x \<squnion> y \<sqsubseteq> z"
and top[simp]: "x \<in> L(vars c) \<Longrightarrow> x \<sqsubseteq> top c"
and top_in_L[simp]: "top c \<in> L(vars c)"
and join_in_L[simp]: "x \<in> L X \<Longrightarrow> y \<in> L X \<Longrightarrow> x \<squnion> y \<in> L X"

notation (input) top ("\<top>\<^bsub>_\<^esub>")
notation (latex output) top ("\<top>\<^bsub>\<^raw:\isa{>_\<^raw:}>\<^esub>")

instantiation option :: (semilatticeL)semilatticeL
begin

definition top_option where "top c = Some(top c)"

instance proof
  case goal1 thus ?case by(cases x, simp, cases y, simp_all)
next
  case goal2 thus ?case by(cases y, simp, cases x, simp_all)
next
  case goal3 thus ?case by(cases z, simp, cases y, simp, cases x, simp_all)
next
  case goal4 thus ?case by(cases x, simp_all add: top_option_def)
next
  case goal5 thus ?case by(simp add: top_option_def)
next
  case goal6 thus ?case by(simp add: L_option_def split: option.splits)
qed

end


subsection "Abstract State with Computable Ordering"

hide_type  st  --"to avoid long names"

text{* A concrete type of state with computable @{text"\<sqsubseteq>"}: *}

datatype 'a st = FunDom "vname \<Rightarrow> 'a" "vname set"

fun "fun" where "fun (FunDom f X) = f"
fun dom where "dom (FunDom f X) = X"

definition "show_st S = (\<lambda>x. (x, fun S x)) ` dom S"

value [code] "show_st (FunDom (\<lambda>x. 1::int) {''a'',''b''})"

definition "show_acom = map_acom (Option.map show_st)"
definition "show_acom_opt = Option.map show_acom"

definition "update F x y = FunDom ((fun F)(x:=y)) (dom F)"

lemma fun_update[simp]: "fun (update S x y) = (fun S)(x:=y)"
by(rule ext)(auto simp: update_def)

lemma dom_update[simp]: "dom (update S x y) = dom S"
by(simp add: update_def)

definition "\<gamma>_st \<gamma> F = {f. \<forall>x\<in>dom F. f x \<in> \<gamma>(fun F x)}"


instantiation st :: (preord) preord
begin

definition le_st :: "'a st \<Rightarrow> 'a st \<Rightarrow> bool" where
"F \<sqsubseteq> G = (dom F = dom G \<and> (\<forall>x \<in> dom F. fun F x \<sqsubseteq> fun G x))"

instance
proof
  case goal2 thus ?case by(auto simp: le_st_def)(metis preord_class.le_trans)
qed (auto simp: le_st_def)

end

instantiation st :: (join) join
begin

definition join_st :: "'a st \<Rightarrow> 'a st \<Rightarrow> 'a st" where
"F \<squnion> G = FunDom (\<lambda>x. fun F x \<squnion> fun G x) (dom F)"

instance ..

end

instantiation st :: (type) L
begin

definition L_st :: "vname set \<Rightarrow> 'a st set" where
"L X = {F. dom F = X}"

instance ..

end

instantiation st :: (semilattice) semilatticeL
begin

definition top_st where "top c = FunDom (\<lambda>x. \<top>) (vars c)"

instance
proof
qed (auto simp: le_st_def join_st_def top_st_def L_st_def)

end


text{* Trick to make code generator happy. *}
lemma [code]: "L = (L :: _ \<Rightarrow> _ st set)"
by(rule refl)
(* L is not used in the code but is part of a type class that is used.
   Hence the code generator wants to build a dictionary with L in it.
   But L is not executable. This looping defn makes it look as if it were. *)


lemma mono_fun: "F \<sqsubseteq> G \<Longrightarrow> x : dom F \<Longrightarrow> fun F x \<sqsubseteq> fun G x"
by(auto simp: le_st_def)

lemma mono_update[simp]:
  "a1 \<sqsubseteq> a2 \<Longrightarrow> S1 \<sqsubseteq> S2 \<Longrightarrow> update S1 x a1 \<sqsubseteq> update S2 x a2"
by(auto simp add: le_st_def update_def)


locale Gamma = Val_abs where \<gamma>=\<gamma> for \<gamma> :: "'av::semilattice \<Rightarrow> val set"
begin

abbreviation \<gamma>\<^isub>s :: "'av st \<Rightarrow> state set"
where "\<gamma>\<^isub>s == \<gamma>_st \<gamma>"

abbreviation \<gamma>\<^isub>o :: "'av st option \<Rightarrow> state set"
where "\<gamma>\<^isub>o == \<gamma>_option \<gamma>\<^isub>s"

abbreviation \<gamma>\<^isub>c :: "'av st option acom \<Rightarrow> state set acom"
where "\<gamma>\<^isub>c == map_acom \<gamma>\<^isub>o"

lemma gamma_s_Top[simp]: "\<gamma>\<^isub>s (top c) = UNIV"
by(auto simp: top_st_def \<gamma>_st_def)

lemma gamma_o_Top[simp]: "\<gamma>\<^isub>o (top c) = UNIV"
by (simp add: top_option_def)

(* FIXME (maybe also le \<rightarrow> sqle?) *)

lemma mono_gamma_s: "f \<sqsubseteq> g \<Longrightarrow> \<gamma>\<^isub>s f \<subseteq> \<gamma>\<^isub>s g"
apply(simp add:\<gamma>_st_def subset_iff le_st_def split: if_splits)
by (metis mono_gamma subsetD)

lemma mono_gamma_o:
  "S1 \<sqsubseteq> S2 \<Longrightarrow> \<gamma>\<^isub>o S1 \<subseteq> \<gamma>\<^isub>o S2"
by(induction S1 S2 rule: le_option.induct)(simp_all add: mono_gamma_s)

lemma mono_gamma_c: "C1 \<sqsubseteq> C2 \<Longrightarrow> \<gamma>\<^isub>c C1 \<le> \<gamma>\<^isub>c C2"
by (induction C1 C2 rule: le_acom.induct) (simp_all add:mono_gamma_o)

lemma in_gamma_option_iff:
  "x : \<gamma>_option r u \<longleftrightarrow> (\<exists>u'. u = Some u' \<and> x : r u')"
by (cases u) auto

end

end
