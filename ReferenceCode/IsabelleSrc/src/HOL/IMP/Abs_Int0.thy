(* Author: Tobias Nipkow *)

theory Abs_Int0
imports Abs_Int_init
begin

subsection "Orderings"

class preord =
fixes le :: "'a \<Rightarrow> 'a \<Rightarrow> bool" (infix "\<sqsubseteq>" 50)
assumes le_refl[simp]: "x \<sqsubseteq> x"
and le_trans: "x \<sqsubseteq> y \<Longrightarrow> y \<sqsubseteq> z \<Longrightarrow> x \<sqsubseteq> z"
begin

definition mono where "mono f = (\<forall>x y. x \<sqsubseteq> y \<longrightarrow> f x \<sqsubseteq> f y)"

declare le_trans[trans]

end

text{* Note: no antisymmetry. Allows implementations where some abstract
element is implemented by two different values @{prop "x \<noteq> y"}
such that @{prop"x \<sqsubseteq> y"} and @{prop"y \<sqsubseteq> x"}. Antisymmetry is not
needed because we never compare elements for equality but only for @{text"\<sqsubseteq>"}.
*}

class join = preord +
fixes join :: "'a \<Rightarrow> 'a \<Rightarrow> 'a" (infixl "\<squnion>" 65)

class semilattice = join +
fixes Top :: "'a" ("\<top>")
assumes join_ge1 [simp]: "x \<sqsubseteq> x \<squnion> y"
and join_ge2 [simp]: "y \<sqsubseteq> x \<squnion> y"
and join_least: "x \<sqsubseteq> z \<Longrightarrow> y \<sqsubseteq> z \<Longrightarrow> x \<squnion> y \<sqsubseteq> z"
and top[simp]: "x \<sqsubseteq> \<top>"
begin

lemma join_le_iff[simp]: "x \<squnion> y \<sqsubseteq> z \<longleftrightarrow> x \<sqsubseteq> z \<and> y \<sqsubseteq> z"
by (metis join_ge1 join_ge2 join_least le_trans)

lemma le_join_disj: "x \<sqsubseteq> y \<or> x \<sqsubseteq> z \<Longrightarrow> x \<sqsubseteq> y \<squnion> z"
by (metis join_ge1 join_ge2 le_trans)

end

instantiation "fun" :: (type, preord) preord
begin

definition "f \<sqsubseteq> g = (\<forall>x. f x \<sqsubseteq> g x)"

instance
proof
  case goal2 thus ?case by (metis le_fun_def preord_class.le_trans)
qed (simp_all add: le_fun_def)

end


instantiation "fun" :: (type, semilattice) semilattice
begin

definition "f \<squnion> g = (\<lambda>x. f x \<squnion> g x)"
definition "\<top> = (\<lambda>x. \<top>)"

lemma join_apply[simp]: "(f \<squnion> g) x = f x \<squnion> g x"
by (simp add: join_fun_def)

instance
proof
qed (simp_all add: le_fun_def Top_fun_def)

end


instantiation acom :: (preord) preord
begin

fun le_acom :: "('a::preord)acom \<Rightarrow> 'a acom \<Rightarrow> bool" where
"le_acom (SKIP {S}) (SKIP {S'}) = (S \<sqsubseteq> S')" |
"le_acom (x ::= e {S}) (x' ::= e' {S'}) = (x=x' \<and> e=e' \<and> S \<sqsubseteq> S')" |
"le_acom (C1;C2) (D1;D2) = (C1 \<sqsubseteq> D1 \<and> C2 \<sqsubseteq> D2)" |
"le_acom (IF b THEN {p1} C1 ELSE {p2} C2 {S}) (IF b' THEN {q1} D1 ELSE {q2} D2 {S'}) =
  (b=b' \<and> p1 \<sqsubseteq> q1 \<and> C1 \<sqsubseteq> D1 \<and> p2 \<sqsubseteq> q2 \<and> C2 \<sqsubseteq> D2 \<and> S \<sqsubseteq> S')" |
"le_acom ({I} WHILE b DO {p} C {P}) ({I'} WHILE b' DO {p'} C' {P'}) =
  (b=b' \<and> p \<sqsubseteq> p' \<and> C \<sqsubseteq> C' \<and> I \<sqsubseteq> I' \<and> P \<sqsubseteq> P')" |
"le_acom _ _ = False"

lemma [simp]: "SKIP {S} \<sqsubseteq> C \<longleftrightarrow> (\<exists>S'. C = SKIP {S'} \<and> S \<sqsubseteq> S')"
by (cases C) auto

lemma [simp]: "x ::= e {S} \<sqsubseteq> C \<longleftrightarrow> (\<exists>S'. C = x ::= e {S'} \<and> S \<sqsubseteq> S')"
by (cases C) auto

lemma [simp]: "C1;C2 \<sqsubseteq> C \<longleftrightarrow> (\<exists>D1 D2. C = D1;D2 \<and> C1 \<sqsubseteq> D1 \<and> C2 \<sqsubseteq> D2)"
by (cases C) auto

lemma [simp]: "IF b THEN {p1} C1 ELSE {p2} C2 {S} \<sqsubseteq> C \<longleftrightarrow>
  (\<exists>q1 q2 D1 D2 S'. C = IF b THEN {q1} D1 ELSE {q2} D2 {S'} \<and>
     p1 \<sqsubseteq> q1 \<and> C1 \<sqsubseteq> D1 \<and> p2 \<sqsubseteq> q2 \<and> C2 \<sqsubseteq> D2 \<and> S \<sqsubseteq> S')"
by (cases C) auto

lemma [simp]: "{I} WHILE b DO {p} C {P} \<sqsubseteq> W \<longleftrightarrow>
  (\<exists>I' p' C' P'. W = {I'} WHILE b DO {p'} C' {P'} \<and> p \<sqsubseteq> p' \<and> C \<sqsubseteq> C' \<and> I \<sqsubseteq> I' \<and> P \<sqsubseteq> P')"
by (cases W) auto

instance
proof
  case goal1 thus ?case by (induct x) auto
next
  case goal2 thus ?case
  apply(induct x y arbitrary: z rule: le_acom.induct)
  apply (auto intro: le_trans)
  done
qed

end


instantiation option :: (preord)preord
begin

fun le_option where
"Some x \<sqsubseteq> Some y = (x \<sqsubseteq> y)" |
"None \<sqsubseteq> y = True" |
"Some _ \<sqsubseteq> None = False"

lemma [simp]: "(x \<sqsubseteq> None) = (x = None)"
by (cases x) simp_all

lemma [simp]: "(Some x \<sqsubseteq> u) = (\<exists>y. u = Some y \<and> x \<sqsubseteq> y)"
by (cases u) auto

instance proof
  case goal1 show ?case by(cases x, simp_all)
next
  case goal2 thus ?case
    by(cases z, simp, cases y, simp, cases x, auto intro: le_trans)
qed

end

instantiation option :: (join)join
begin

fun join_option where
"Some x \<squnion> Some y = Some(x \<squnion> y)" |
"None \<squnion> y = y" |
"x \<squnion> None = x"

lemma join_None2[simp]: "x \<squnion> None = x"
by (cases x) simp_all

instance ..

end

instantiation option :: (semilattice)semilattice
begin

definition "\<top> = Some \<top>"

instance proof
  case goal1 thus ?case by(cases x, simp, cases y, simp_all)
next
  case goal2 thus ?case by(cases y, simp, cases x, simp_all)
next
  case goal3 thus ?case by(cases z, simp, cases y, simp, cases x, simp_all)
next
  case goal4 thus ?case by(cases x, simp_all add: Top_option_def)
qed

end

class bot = preord +
fixes bot :: "'a" ("\<bottom>")
assumes bot[simp]: "\<bottom> \<sqsubseteq> x"

instantiation option :: (preord)bot
begin

definition bot_option :: "'a option" where
"\<bottom> = None"

instance
proof
  case goal1 thus ?case by(auto simp: bot_option_def)
qed

end


definition bot :: "com \<Rightarrow> 'a option acom" where
"bot c = anno None c"

lemma bot_least: "strip C = c \<Longrightarrow> bot c \<sqsubseteq> C"
by(induct C arbitrary: c)(auto simp: bot_def)

lemma strip_bot[simp]: "strip(bot c) = c"
by(simp add: bot_def)


subsubsection "Post-fixed point iteration"

definition pfp :: "(('a::preord) \<Rightarrow> 'a) \<Rightarrow> 'a \<Rightarrow> 'a option" where
"pfp f = while_option (\<lambda>x. \<not> f x \<sqsubseteq> x) f"

lemma pfp_pfp: assumes "pfp f x0 = Some x" shows "f x \<sqsubseteq> x"
using while_option_stop[OF assms[simplified pfp_def]] by simp

lemma while_least:
assumes "\<forall>x\<in>L.\<forall>y\<in>L. x \<sqsubseteq> y \<longrightarrow> f x \<sqsubseteq> f y" and "\<forall>x. x \<in> L \<longrightarrow> f x \<in> L"
and "\<forall>x \<in> L. b \<sqsubseteq> x" and "b \<in> L" and "f q \<sqsubseteq> q" and "q \<in> L"
and "while_option P f b = Some p"
shows "p \<sqsubseteq> q"
using while_option_rule[OF _  assms(7)[unfolded pfp_def],
                        where P = "%x. x \<in> L \<and> x \<sqsubseteq> q"]
by (metis assms(1-6) le_trans)

lemma pfp_inv:
  "pfp f x = Some y \<Longrightarrow> (\<And>x. P x \<Longrightarrow> P(f x)) \<Longrightarrow> P x \<Longrightarrow> P y"
unfolding pfp_def by (metis (lifting) while_option_rule)

lemma strip_pfp:
assumes "\<And>x. g(f x) = g x" and "pfp f x0 = Some x" shows "g x = g x0"
using pfp_inv[OF assms(2), where P = "%x. g x = g x0"] assms(1) by simp


subsection "Abstract Interpretation"

definition \<gamma>_fun :: "('a \<Rightarrow> 'b set) \<Rightarrow> ('c \<Rightarrow> 'a) \<Rightarrow> ('c \<Rightarrow> 'b)set" where
"\<gamma>_fun \<gamma> F = {f. \<forall>x. f x \<in> \<gamma>(F x)}"

fun \<gamma>_option :: "('a \<Rightarrow> 'b set) \<Rightarrow> 'a option \<Rightarrow> 'b set" where
"\<gamma>_option \<gamma> None = {}" |
"\<gamma>_option \<gamma> (Some a) = \<gamma> a"

text{* The interface for abstract values: *}

locale Val_abs =
fixes \<gamma> :: "'av::semilattice \<Rightarrow> val set"
  assumes mono_gamma: "a \<sqsubseteq> b \<Longrightarrow> \<gamma> a \<subseteq> \<gamma> b"
  and gamma_Top[simp]: "\<gamma> \<top> = UNIV"
fixes num' :: "val \<Rightarrow> 'av"
and plus' :: "'av \<Rightarrow> 'av \<Rightarrow> 'av"
  assumes gamma_num': "i : \<gamma>(num' i)"
  and gamma_plus':
 "i1 : \<gamma> a1 \<Longrightarrow> i2 : \<gamma> a2 \<Longrightarrow> i1+i2 : \<gamma>(plus' a1 a2)"

type_synonym 'av st = "(vname \<Rightarrow> 'av)"

locale Abs_Int_Fun = Val_abs \<gamma> for \<gamma> :: "'av::semilattice \<Rightarrow> val set"
begin

fun aval' :: "aexp \<Rightarrow> 'av st \<Rightarrow> 'av" where
"aval' (N i) S = num' i" |
"aval' (V x) S = S x" |
"aval' (Plus a1 a2) S = plus' (aval' a1 S) (aval' a2 S)"

fun step' :: "'av st option \<Rightarrow> 'av st option acom \<Rightarrow> 'av st option acom"
 where
"step' S (SKIP {P}) = (SKIP {S})" |
"step' S (x ::= e {P}) =
  x ::= e {case S of None \<Rightarrow> None | Some S \<Rightarrow> Some(S(x := aval' e S))}" |
"step' S (C1; C2) = step' S C1; step' (post C1) C2" |
"step' S (IF b THEN {P1} C1 ELSE {P2} C2 {Q}) =
   IF b THEN {S} step' P1 C1 ELSE {S} step' P2 C2 {post C1 \<squnion> post C2}" |
"step' S ({I} WHILE b DO {P} C {Q}) =
  {S \<squnion> post C} WHILE b DO {I} step' P C {I}"

definition AI :: "com \<Rightarrow> 'av st option acom option" where
"AI c = pfp (step' \<top>) (bot c)"


lemma strip_step'[simp]: "strip(step' S C) = strip C"
by(induct C arbitrary: S) (simp_all add: Let_def)


abbreviation \<gamma>\<^isub>s :: "'av st \<Rightarrow> state set"
where "\<gamma>\<^isub>s == \<gamma>_fun \<gamma>"

abbreviation \<gamma>\<^isub>o :: "'av st option \<Rightarrow> state set"
where "\<gamma>\<^isub>o == \<gamma>_option \<gamma>\<^isub>s"

abbreviation \<gamma>\<^isub>c :: "'av st option acom \<Rightarrow> state set acom"
where "\<gamma>\<^isub>c == map_acom \<gamma>\<^isub>o"

lemma gamma_s_Top[simp]: "\<gamma>\<^isub>s Top = UNIV"
by(simp add: Top_fun_def \<gamma>_fun_def)

lemma gamma_o_Top[simp]: "\<gamma>\<^isub>o Top = UNIV"
by (simp add: Top_option_def)

(* FIXME (maybe also le \<rightarrow> sqle?) *)

lemma mono_gamma_s: "f1 \<sqsubseteq> f2 \<Longrightarrow> \<gamma>\<^isub>s f1 \<subseteq> \<gamma>\<^isub>s f2"
by(auto simp: le_fun_def \<gamma>_fun_def dest: mono_gamma)

lemma mono_gamma_o:
  "S1 \<sqsubseteq> S2 \<Longrightarrow> \<gamma>\<^isub>o S1 \<subseteq> \<gamma>\<^isub>o S2"
by(induction S1 S2 rule: le_option.induct)(simp_all add: mono_gamma_s)

lemma mono_gamma_c: "C1 \<sqsubseteq> C2 \<Longrightarrow> \<gamma>\<^isub>c C1 \<le> \<gamma>\<^isub>c C2"
by (induction C1 C2 rule: le_acom.induct) (simp_all add:mono_gamma_o)

text{* Soundness: *}

lemma aval'_sound: "s : \<gamma>\<^isub>s S \<Longrightarrow> aval a s : \<gamma>(aval' a S)"
by (induct a) (auto simp: gamma_num' gamma_plus' \<gamma>_fun_def)

lemma in_gamma_update:
  "\<lbrakk> s : \<gamma>\<^isub>s S; i : \<gamma> a \<rbrakk> \<Longrightarrow> s(x := i) : \<gamma>\<^isub>s(S(x := a))"
by(simp add: \<gamma>_fun_def)

lemma step_step': "step (\<gamma>\<^isub>o S) (\<gamma>\<^isub>c C) \<le> \<gamma>\<^isub>c (step' S C)"
proof(induction C arbitrary: S)
  case SKIP thus ?case by auto
next
  case Assign thus ?case
    by (fastforce intro: aval'_sound in_gamma_update split: option.splits)
next
  case Seq thus ?case by auto
next
  case If thus ?case by (auto simp: mono_gamma_o)
next
  case While thus ?case by (auto simp: mono_gamma_o)
qed

lemma AI_sound: "AI c = Some C \<Longrightarrow> CS c \<le> \<gamma>\<^isub>c C"
proof(simp add: CS_def AI_def)
  assume 1: "pfp (step' \<top>) (bot c) = Some C"
  have pfp': "step' \<top> C \<sqsubseteq> C" by(rule pfp_pfp[OF 1])
  have 2: "step (\<gamma>\<^isub>o \<top>) (\<gamma>\<^isub>c C) \<le> \<gamma>\<^isub>c C"  --"transfer the pfp'"
  proof(rule order_trans)
    show "step (\<gamma>\<^isub>o \<top>) (\<gamma>\<^isub>c C) \<le> \<gamma>\<^isub>c (step' \<top> C)" by(rule step_step')
    show "... \<le> \<gamma>\<^isub>c C" by (metis mono_gamma_c[OF pfp'])
  qed
  have 3: "strip (\<gamma>\<^isub>c C) = c" by(simp add: strip_pfp[OF _ 1])
  have "lfp c (step (\<gamma>\<^isub>o \<top>)) \<le> \<gamma>\<^isub>c C"
    by(rule lfp_lowerbound[simplified,where f="step (\<gamma>\<^isub>o \<top>)", OF 3 2])
  thus "lfp c (step UNIV) \<le> \<gamma>\<^isub>c C" by simp
qed

end


subsubsection "Monotonicity"

lemma mono_post: "C1 \<sqsubseteq> C2 \<Longrightarrow> post C1 \<sqsubseteq> post C2"
by(induction C1 C2 rule: le_acom.induct) (auto)

locale Abs_Int_Fun_mono = Abs_Int_Fun +
assumes mono_plus': "a1 \<sqsubseteq> b1 \<Longrightarrow> a2 \<sqsubseteq> b2 \<Longrightarrow> plus' a1 a2 \<sqsubseteq> plus' b1 b2"
begin

lemma mono_aval': "S \<sqsubseteq> S' \<Longrightarrow> aval' e S \<sqsubseteq> aval' e S'"
by(induction e)(auto simp: le_fun_def mono_plus')

lemma mono_update: "a \<sqsubseteq> a' \<Longrightarrow> S \<sqsubseteq> S' \<Longrightarrow> S(x := a) \<sqsubseteq> S'(x := a')"
by(simp add: le_fun_def)

lemma mono_step': "S1 \<sqsubseteq> S2 \<Longrightarrow> C1 \<sqsubseteq> C2 \<Longrightarrow> step' S1 C1 \<sqsubseteq> step' S2 C2"
apply(induction C1 C2 arbitrary: S1 S2 rule: le_acom.induct)
apply (auto simp: Let_def mono_update mono_aval' mono_post le_join_disj
            split: option.split)
done

end

text{* Problem: not executable because of the comparison of abstract states,
i.e. functions, in the post-fixedpoint computation. *}

end
