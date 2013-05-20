(*  Title:      HOL/Probability/Fin_Map.thy
    Author:     Fabian Immler, TU München
*)

header {* Finite Maps *}

theory Fin_Map
imports Finite_Product_Measure
begin

text {* Auxiliary type that is instantiated to @{class polish_space}, needed for the proof of
  projective limit. @{const extensional} functions are used for the representation in order to
  stay close to the developments of (finite) products @{const Pi\<^isub>E} and their sigma-algebra
  @{const Pi\<^isub>M}. *}

typedef ('i, 'a) finmap ("(_ \<Rightarrow>\<^isub>F /_)" [22, 21] 21) =
  "{(I::'i set, f::'i \<Rightarrow> 'a). finite I \<and> f \<in> extensional I}" by auto

subsection {* Domain and Application *}

definition domain where "domain P = fst (Rep_finmap P)"

lemma finite_domain[simp, intro]: "finite (domain P)"
  by (cases P) (auto simp: domain_def Abs_finmap_inverse)

definition proj ("'((_)')\<^isub>F" [0] 1000) where "proj P i = snd (Rep_finmap P) i"

declare [[coercion proj]]

lemma extensional_proj[simp, intro]: "(P)\<^isub>F \<in> extensional (domain P)"
  by (cases P) (auto simp: domain_def Abs_finmap_inverse proj_def[abs_def])

lemma proj_undefined[simp, intro]: "i \<notin> domain P \<Longrightarrow> P i = undefined"
  using extensional_proj[of P] unfolding extensional_def by auto

lemma finmap_eq_iff: "P = Q \<longleftrightarrow> (domain P = domain Q \<and> (\<forall>i\<in>domain P. P i = Q i))"
  by (cases P, cases Q)
     (auto simp add: Abs_finmap_inject extensional_def domain_def proj_def Abs_finmap_inverse
              intro: extensionalityI)

subsection {* Countable Finite Maps *}

instance finmap :: (countable, countable) countable
proof
  obtain mapper where mapper: "\<And>fm :: 'a \<Rightarrow>\<^isub>F 'b. set (mapper fm) = domain fm"
    by (metis finite_list[OF finite_domain])
  have "inj (\<lambda>fm. map (\<lambda>i. (i, (fm)\<^isub>F i)) (mapper fm))" (is "inj ?F")
  proof (rule inj_onI)
    fix f1 f2 assume "?F f1 = ?F f2"
    then have "map fst (?F f1) = map fst (?F f2)" by simp
    then have "mapper f1 = mapper f2" by (simp add: comp_def)
    then have "domain f1 = domain f2" by (simp add: mapper[symmetric])
    with `?F f1 = ?F f2` show "f1 = f2"
      unfolding `mapper f1 = mapper f2` map_eq_conv mapper
      by (simp add: finmap_eq_iff)
  qed
  then show "\<exists>to_nat :: 'a \<Rightarrow>\<^isub>F 'b \<Rightarrow> nat. inj to_nat"
    by (intro exI[of _ "to_nat \<circ> ?F"] inj_comp) auto
qed

subsection {* Constructor of Finite Maps *}

definition "finmap_of inds f = Abs_finmap (inds, restrict f inds)"

lemma proj_finmap_of[simp]:
  assumes "finite inds"
  shows "(finmap_of inds f)\<^isub>F = restrict f inds"
  using assms
  by (auto simp: Abs_finmap_inverse finmap_of_def proj_def)

lemma domain_finmap_of[simp]:
  assumes "finite inds"
  shows "domain (finmap_of inds f) = inds"
  using assms
  by (auto simp: Abs_finmap_inverse finmap_of_def domain_def)

lemma finmap_of_eq_iff[simp]:
  assumes "finite i" "finite j"
  shows "finmap_of i m = finmap_of j n \<longleftrightarrow> i = j \<and> restrict m i = restrict n i"
  using assms
  apply (auto simp: finmap_eq_iff restrict_def) by metis

lemma finmap_of_inj_on_extensional_finite:
  assumes "finite K"
  assumes "S \<subseteq> extensional K"
  shows "inj_on (finmap_of K) S"
proof (rule inj_onI)
  fix x y::"'a \<Rightarrow> 'b"
  assume "finmap_of K x = finmap_of K y"
  hence "(finmap_of K x)\<^isub>F = (finmap_of K y)\<^isub>F" by simp
  moreover
  assume "x \<in> S" "y \<in> S" hence "x \<in> extensional K" "y \<in> extensional K" using assms by auto
  ultimately
  show "x = y" using assms by (simp add: extensional_restrict)
qed

lemma finmap_choice:
  assumes *: "\<And>i. i \<in> I \<Longrightarrow> \<exists>x. P i x" and I: "finite I"
  shows "\<exists>fm. domain fm = I \<and> (\<forall>i\<in>I. P i (fm i))"
proof -
  have "\<exists>f. \<forall>i\<in>I. P i (f i)"
    unfolding bchoice_iff[symmetric] using * by auto
  then guess f ..
  with I show ?thesis
    by (intro exI[of _ "finmap_of I f"]) auto
qed

subsection {* Product set of Finite Maps *}

text {* This is @{term Pi} for Finite Maps, most of this is copied *}

definition Pi' :: "'i set \<Rightarrow> ('i \<Rightarrow> 'a set) \<Rightarrow> ('i \<Rightarrow>\<^isub>F 'a) set" where
  "Pi' I A = { P. domain P = I \<and> (\<forall>i. i \<in> I \<longrightarrow> (P)\<^isub>F i \<in> A i) } "

syntax
  "_Pi'"  :: "[pttrn, 'a set, 'b set] => ('a => 'b) set"  ("(3PI' _:_./ _)" 10)

syntax (xsymbols)
  "_Pi'" :: "[pttrn, 'a set, 'b set] => ('a => 'b) set"  ("(3\<Pi>' _\<in>_./ _)"   10)

syntax (HTML output)
  "_Pi'" :: "[pttrn, 'a set, 'b set] => ('a => 'b) set"  ("(3\<Pi>' _\<in>_./ _)"   10)

translations
  "PI' x:A. B" == "CONST Pi' A (%x. B)"

subsubsection{*Basic Properties of @{term Pi'}*}

lemma Pi'_I[intro!]: "domain f = A \<Longrightarrow> (\<And>x. x \<in> A \<Longrightarrow> f x \<in> B x) \<Longrightarrow> f \<in> Pi' A B"
  by (simp add: Pi'_def)

lemma Pi'_I'[simp]: "domain f = A \<Longrightarrow> (\<And>x. x \<in> A \<longrightarrow> f x \<in> B x) \<Longrightarrow> f \<in> Pi' A B"
  by (simp add:Pi'_def)

lemma Pi'_mem: "f\<in> Pi' A B \<Longrightarrow> x \<in> A \<Longrightarrow> f x \<in> B x"
  by (simp add: Pi'_def)

lemma Pi'_iff: "f \<in> Pi' I X \<longleftrightarrow> domain f = I \<and> (\<forall>i\<in>I. f i \<in> X i)"
  unfolding Pi'_def by auto

lemma Pi'E [elim]:
  "f \<in> Pi' A B \<Longrightarrow> (f x \<in> B x \<Longrightarrow> domain f = A \<Longrightarrow> Q) \<Longrightarrow> (x \<notin> A \<Longrightarrow> Q) \<Longrightarrow> Q"
  by(auto simp: Pi'_def)

lemma in_Pi'_cong:
  "domain f = domain g \<Longrightarrow> (\<And> w. w \<in> A \<Longrightarrow> f w = g w) \<Longrightarrow> f \<in> Pi' A B \<longleftrightarrow> g \<in> Pi' A B"
  by (auto simp: Pi'_def)

lemma Pi'_eq_empty[simp]:
  assumes "finite A" shows "(Pi' A B) = {} \<longleftrightarrow> (\<exists>x\<in>A. B x = {})"
  using assms
  apply (simp add: Pi'_def, auto)
  apply (drule_tac x = "finmap_of A (\<lambda>u. SOME y. y \<in> B u)" in spec, auto)
  apply (cut_tac P= "%y. y \<in> B i" in some_eq_ex, auto)
  done

lemma Pi'_mono: "(\<And>x. x \<in> A \<Longrightarrow> B x \<subseteq> C x) \<Longrightarrow> Pi' A B \<subseteq> Pi' A C"
  by (auto simp: Pi'_def)

lemma Pi_Pi': "finite A \<Longrightarrow> (Pi\<^isub>E A B) = proj ` Pi' A B"
  apply (auto simp: Pi'_def Pi_def extensional_def)
  apply (rule_tac x = "finmap_of A (restrict x A)" in image_eqI)
  apply auto
  done

subsection {* Metric Space of Finite Maps *}

instantiation finmap :: (type, metric_space) metric_space
begin

definition dist_finmap where
  "dist P Q = (\<Sum>i\<in>domain P \<union> domain Q. dist ((P)\<^isub>F i) ((Q)\<^isub>F i)) +
    card ((domain P - domain Q) \<union> (domain Q - domain P))"

lemma dist_finmap_extend:
  assumes "finite X"
  shows "dist P Q = (\<Sum>i\<in>domain P \<union> domain Q \<union> X. dist ((P)\<^isub>F i) ((Q)\<^isub>F i)) +
    card ((domain P - domain Q) \<union> (domain Q - domain P))"
    unfolding dist_finmap_def add_right_cancel
    using assms extensional_arb[of "(P)\<^isub>F"] extensional_arb[of "(Q)\<^isub>F" "domain Q"]
    by (intro setsum_mono_zero_cong_left) auto

definition open_finmap :: "('a \<Rightarrow>\<^isub>F 'b) set \<Rightarrow> bool" where
  "open_finmap S = (\<forall>x\<in>S. \<exists>e>0. \<forall>y. dist y x < e \<longrightarrow> y \<in> S)"

lemma add_eq_zero_iff[simp]:
  fixes a b::real
  assumes "a \<ge> 0" "b \<ge> 0"
  shows "a + b = 0 \<longleftrightarrow> a = 0 \<and> b = 0"
using assms by auto

lemma dist_le_1_imp_domain_eq:
  assumes "dist P Q < 1"
  shows "domain P = domain Q"
proof -
  have "0 \<le> (\<Sum>i\<in>domain P \<union> domain Q. dist (P i) (Q i))"
    by (simp add: setsum_nonneg)
  with assms have "card (domain P - domain Q \<union> (domain Q - domain P)) = 0"
    unfolding dist_finmap_def by arith
  thus "domain P = domain Q" by auto
qed

lemma dist_proj:
  shows "dist ((x)\<^isub>F i) ((y)\<^isub>F i) \<le> dist x y"
proof -
  have "dist (x i) (y i) = (\<Sum>i\<in>{i}. dist (x i) (y i))" by simp
  also have "\<dots> \<le> (\<Sum>i\<in>domain x \<union> domain y \<union> {i}. dist (x i) (y i))"
    by (intro setsum_mono2) auto
  also have "\<dots> \<le> dist x y" by (simp add: dist_finmap_extend[of "{i}"])
  finally show ?thesis by simp
qed

lemma open_Pi'I:
  assumes open_component: "\<And>i. i \<in> I \<Longrightarrow> open (A i)"
  shows "open (Pi' I A)"
proof (subst open_finmap_def, safe)
  fix x assume x: "x \<in> Pi' I A"
  hence dim_x: "domain x = I" by (simp add: Pi'_def)
  hence [simp]: "finite I" unfolding dim_x[symmetric] by simp
  have "\<exists>ei. \<forall>i\<in>I. 0 < ei i \<and> (\<forall>y. dist y (x i) < ei i \<longrightarrow> y \<in> A i)"
  proof (safe intro!: bchoice)
    fix i assume i: "i \<in> I"
    moreover with open_component have "open (A i)" by simp
    moreover have "x i \<in> A i" using x i
      by (auto simp: proj_def)
    ultimately show "\<exists>e>0. \<forall>y. dist y (x i) < e \<longrightarrow> y \<in> A i"
      using x by (auto simp: open_dist Ball_def)
  qed
  then guess ei .. note ei = this
  def es \<equiv> "ei ` I"
  def e \<equiv> "if es = {} then 0.5 else min 0.5 (Min es)"
  from ei have "e > 0" using x
    by (auto simp add: e_def es_def Pi'_def Ball_def)
  moreover have "\<forall>y. dist y x < e \<longrightarrow> y \<in> Pi' I A"
  proof (intro allI impI)
    fix y
    assume "dist y x < e"
    also have "\<dots> < 1" by (auto simp: e_def)
    finally have "domain y = domain x" by (rule dist_le_1_imp_domain_eq)
    with dim_x have dims: "domain y = domain x" "domain x = I" by auto
    show "y \<in> Pi' I A"
    proof
      show "domain y = I" using dims by simp
    next
      fix i
      assume "i \<in> I"
      have "dist (y i) (x i) \<le> dist y x" using dims `i \<in> I`
        by (auto intro: dist_proj)
      also have "\<dots> < e" using `dist y x < e` dims
        by (simp add: dist_finmap_def)
      also have "e \<le> Min (ei ` I)" using dims `i \<in> I`
        by (auto simp: e_def es_def)
      also have "\<dots> \<le> ei i" using `i \<in> I` by (simp add: e_def)
      finally have "dist (y i) (x i) < ei i" .
      with ei `i \<in> I` show "y i \<in> A  i" by simp
    qed
  qed
  ultimately
  show "\<exists>e>0. \<forall>y. dist y x < e \<longrightarrow> y \<in> Pi' I A" by blast
qed

instance
proof
  fix S::"('a \<Rightarrow>\<^isub>F 'b) set"
  show "open S = (\<forall>x\<in>S. \<exists>e>0. \<forall>y. dist y x < e \<longrightarrow> y \<in> S)"
    unfolding open_finmap_def ..
next
  fix P Q::"'a \<Rightarrow>\<^isub>F 'b"
  show "dist P Q = 0 \<longleftrightarrow> P = Q"
    by (auto simp: finmap_eq_iff dist_finmap_def setsum_nonneg setsum_nonneg_eq_0_iff)
next
  fix P Q R::"'a \<Rightarrow>\<^isub>F 'b"
  let ?symdiff = "\<lambda>a b. domain a - domain b \<union> (domain b - domain a)"
  def E \<equiv> "domain P \<union> domain Q \<union> domain R"
  hence "finite E" by (simp add: E_def)
  have "card (?symdiff P Q) \<le> card (?symdiff P R \<union> ?symdiff Q R)"
    by (auto intro: card_mono)
  also have "\<dots> \<le> card (?symdiff P R) + card (?symdiff Q R)"
    by (subst card_Un_Int) auto
  finally have "dist P Q \<le> (\<Sum>i\<in>E. dist (P i) (R i) + dist (Q i) (R i)) +
    real (card (?symdiff P R) + card (?symdiff Q R))"
    unfolding dist_finmap_extend[OF `finite E`]
    by (intro add_mono) (auto simp: E_def intro: setsum_mono dist_triangle_le)
  also have "\<dots> \<le> dist P R + dist Q R"
    unfolding dist_finmap_extend[OF `finite E`] by (simp add: ac_simps E_def setsum_addf[symmetric])
  finally show "dist P Q \<le> dist P R + dist Q R" by simp
qed

end

lemma open_restricted_space:
  shows "open {m. P (domain m)}"
proof -
  have "{m. P (domain m)} = (\<Union>i \<in> Collect P. {m. domain m = i})" by auto
  also have "open \<dots>"
  proof (rule, safe, cases)
    fix i::"'a set"
    assume "finite i"
    hence "{m. domain m = i} = Pi' i (\<lambda>_. UNIV)" by (auto simp: Pi'_def)
    also have "open \<dots>" by (auto intro: open_Pi'I simp: `finite i`)
    finally show "open {m. domain m = i}" .
  next
    fix i::"'a set"
    assume "\<not> finite i" hence "{m. domain m = i} = {}" by auto
    also have "open \<dots>" by simp
    finally show "open {m. domain m = i}" .
  qed
  finally show ?thesis .
qed

lemma closed_restricted_space:
  shows "closed {m. P (domain m)}"
proof -
  have "{m. P (domain m)} = - (\<Union>i \<in> - Collect P. {m. domain m = i})" by auto
  also have "closed \<dots>"
  proof (rule, rule, rule, cases)
    fix i::"'a set"
    assume "finite i"
    hence "{m. domain m = i} = Pi' i (\<lambda>_. UNIV)" by (auto simp: Pi'_def)
    also have "open \<dots>" by (auto intro: open_Pi'I simp: `finite i`)
    finally show "open {m. domain m = i}" .
  next
    fix i::"'a set"
    assume "\<not> finite i" hence "{m. domain m = i} = {}" by auto
    also have "open \<dots>" by simp
    finally show "open {m. domain m = i}" .
  qed
  finally show ?thesis .
qed

lemma continuous_proj:
  shows "continuous_on s (\<lambda>x. (x)\<^isub>F i)"
  unfolding continuous_on_topological
proof safe
  fix x B assume "x \<in> s" "open B" "x i \<in> B"
  let ?A = "Pi' (domain x) (\<lambda>j. if i = j then B else UNIV)"
  have "open ?A" using `open B` by (auto intro: open_Pi'I)
  moreover have "x \<in> ?A" using `x i \<in> B` by auto
  moreover have "(\<forall>y\<in>s. y \<in> ?A \<longrightarrow> y i \<in> B)"
  proof (cases, safe)
    fix y assume "y \<in> s"
    assume "i \<notin> domain x" hence "undefined \<in> B" using `x i \<in> B`
      by simp
    moreover
    assume "y \<in> ?A" hence "domain y = domain x" by (simp add: Pi'_def)
    hence "y i = undefined" using `i \<notin> domain x` by simp
    ultimately
    show "y i \<in> B" by simp
  qed force
  ultimately
  show "\<exists>A. open A \<and> x \<in> A \<and> (\<forall>y\<in>s. y \<in> A \<longrightarrow> y i \<in> B)" by blast
qed

subsection {* Complete Space of Finite Maps *}

lemma tendsto_dist_zero:
  assumes "(\<lambda>i. dist (f i) g) ----> 0"
  shows "f ----> g"
  using assms by (auto simp: tendsto_iff dist_real_def)

lemma tendsto_dist_zero':
  assumes "(\<lambda>i. dist (f i) g) ----> x"
  assumes "0 = x"
  shows "f ----> g"
  using assms tendsto_dist_zero by simp

lemma tendsto_finmap:
  fixes f::"nat \<Rightarrow> ('i \<Rightarrow>\<^isub>F ('a::metric_space))"
  assumes ind_f:  "\<And>n. domain (f n) = domain g"
  assumes proj_g:  "\<And>i. i \<in> domain g \<Longrightarrow> (\<lambda>n. (f n) i) ----> g i"
  shows "f ----> g"
  apply (rule tendsto_dist_zero')
  unfolding dist_finmap_def assms
  apply (rule tendsto_intros proj_g | simp)+
  done

instance finmap :: (type, complete_space) complete_space
proof
  fix P::"nat \<Rightarrow> 'a \<Rightarrow>\<^isub>F 'b"
  assume "Cauchy P"
  then obtain Nd where Nd: "\<And>n. n \<ge> Nd \<Longrightarrow> dist (P n) (P Nd) < 1"
    by (force simp: cauchy)
  def d \<equiv> "domain (P Nd)"
  with Nd have dim: "\<And>n. n \<ge> Nd \<Longrightarrow> domain (P n) = d" using dist_le_1_imp_domain_eq by auto
  have [simp]: "finite d" unfolding d_def by simp
  def p \<equiv> "\<lambda>i n. (P n) i"
  def q \<equiv> "\<lambda>i. lim (p i)"
  def Q \<equiv> "finmap_of d q"
  have q: "\<And>i. i \<in> d \<Longrightarrow> q i = Q i" by (auto simp add: Q_def Abs_finmap_inverse)
  {
    fix i assume "i \<in> d"
    have "Cauchy (p i)" unfolding cauchy p_def
    proof safe
      fix e::real assume "0 < e"
      with `Cauchy P` obtain N where N: "\<And>n. n\<ge>N \<Longrightarrow> dist (P n) (P N) < min e 1"
        by (force simp: cauchy min_def)
      hence "\<And>n. n \<ge> N \<Longrightarrow> domain (P n) = domain (P N)" using dist_le_1_imp_domain_eq by auto
      with dim have dim: "\<And>n. n \<ge> N \<Longrightarrow> domain (P n) = d" by (metis nat_le_linear)
      show "\<exists>N. \<forall>n\<ge>N. dist ((P n) i) ((P N) i) < e"
      proof (safe intro!: exI[where x="N"])
        fix n assume "N \<le> n" have "N \<le> N" by simp
        have "dist ((P n) i) ((P N) i) \<le> dist (P n) (P N)"
          using dim[OF `N \<le> n`]  dim[OF `N \<le> N`] `i \<in> d`
          by (auto intro!: dist_proj)
        also have "\<dots> < e" using N[OF `N \<le> n`] by simp
        finally show "dist ((P n) i) ((P N) i) < e" .
      qed
    qed
    hence "convergent (p i)" by (metis Cauchy_convergent_iff)
    hence "p i ----> q i" unfolding q_def convergent_def by (metis limI)
  } note p = this
  have "P ----> Q"
  proof (rule metric_LIMSEQ_I)
    fix e::real assume "0 < e"
    def e' \<equiv> "min 1 (e / (card d + 1))"
    hence "0 < e'" using `0 < e` by (auto simp: e'_def intro: divide_pos_pos)
    have "\<exists>ni. \<forall>i\<in>d. \<forall>n\<ge>ni i. dist (p i n) (q i) < e'"
    proof (safe intro!: bchoice)
      fix i assume "i \<in> d"
      from p[OF `i \<in> d`, THEN metric_LIMSEQ_D, OF `0 < e'`]
      show "\<exists>no. \<forall>n\<ge>no. dist (p i n) (q i) < e'" .
    qed then guess ni .. note ni = this
    def N \<equiv> "max Nd (Max (ni ` d))"
    show "\<exists>N. \<forall>n\<ge>N. dist (P n) Q < e"
    proof (safe intro!: exI[where x="N"])
      fix n assume "N \<le> n"
      hence "domain (P n) = d" "domain Q = d" "domain (P n) = domain Q"
        using dim by (simp_all add: N_def Q_def dim_def Abs_finmap_inverse)
      hence "dist (P n) Q = (\<Sum>i\<in>d. dist ((P n) i) (Q i))" by (simp add: dist_finmap_def)
      also have "\<dots> \<le> (\<Sum>i\<in>d. e')"
      proof (intro setsum_mono less_imp_le)
        fix i assume "i \<in> d"
        hence "ni i \<le> Max (ni ` d)" by simp
        also have "\<dots> \<le> N" by (simp add: N_def)
        also have "\<dots> \<le> n" using `N \<le> n` .
        finally
        show "dist ((P n) i) (Q i) < e'"
          using ni `i \<in> d` by (auto simp: p_def q N_def)
      qed
      also have "\<dots> = card d * e'" by (simp add: real_eq_of_nat)
      also have "\<dots> < e" using `0 < e` by (simp add: e'_def field_simps min_def)
      finally show "dist (P n) Q < e" .
    qed
  qed
  thus "convergent P" by (auto simp: convergent_def)
qed

subsection {* Polish Space of Finite Maps *}

instantiation finmap :: (countable, polish_space) polish_space
begin

definition basis_finmap::"('a \<Rightarrow>\<^isub>F 'b) set set"
  where "basis_finmap = {Pi' I S|I S. finite I \<and> (\<forall>i \<in> I. S i \<in> union_closed_basis)}"

lemma in_basis_finmapI:
  assumes "finite I" assumes "\<And>i. i \<in> I \<Longrightarrow> S i \<in> union_closed_basis"
  shows "Pi' I S \<in> basis_finmap"
  using assms unfolding basis_finmap_def by auto

lemma in_basis_finmapE:
  assumes "x \<in> basis_finmap"
  obtains I S where "x = Pi' I S" "finite I" "\<And>i. i \<in> I \<Longrightarrow> S i \<in> union_closed_basis"
  using assms unfolding basis_finmap_def by auto

lemma basis_finmap_eq:
  "basis_finmap = (\<lambda>f. Pi' (domain f) (\<lambda>i. from_nat_into union_closed_basis ((f)\<^isub>F i))) `
    (UNIV::('a \<Rightarrow>\<^isub>F nat) set)" (is "_ = ?f ` _")
  unfolding basis_finmap_def
proof safe
  fix I::"'a set" and S::"'a \<Rightarrow> 'b set"
  assume "finite I" "\<forall>i\<in>I. S i \<in> union_closed_basis"
  hence "Pi' I S = ?f (finmap_of I (\<lambda>x. to_nat_on union_closed_basis (S x)))"
    by (force simp: Pi'_def countable_union_closed_basis)
  thus "Pi' I S \<in> range ?f" by simp
qed (metis (mono_tags) empty_basisI equals0D finite_domain from_nat_into)

lemma countable_basis_finmap: "countable basis_finmap"
  unfolding basis_finmap_eq by simp

lemma finmap_topological_basis:
  "topological_basis basis_finmap"
proof (subst topological_basis_iff, safe)
  fix B' assume "B' \<in> basis_finmap"
  thus "open B'"
    by (auto intro!: open_Pi'I topological_basis_open[OF basis_union_closed_basis]
      simp: topological_basis_def basis_finmap_def Let_def)
next
  fix O'::"('a \<Rightarrow>\<^isub>F 'b) set" and x
  assume "open O'" "x \<in> O'"
  then obtain e where e: "e > 0" "\<And>y. dist y x < e \<Longrightarrow> y \<in> O'"  unfolding open_dist by blast
  def e' \<equiv> "e / (card (domain x) + 1)"

  have "\<exists>B.
    (\<forall>i\<in>domain x. x i \<in> B i \<and> B i \<subseteq> ball (x i) e' \<and> B i \<in> union_closed_basis)"
  proof (rule bchoice, safe)
    fix i assume "i \<in> domain x"
    have "open (ball (x i) e')" "x i \<in> ball (x i) e'" using e
      by (auto simp add: e'_def intro!: divide_pos_pos)
    from topological_basisE[OF basis_union_closed_basis this] guess b' .
    thus "\<exists>y. x i \<in> y \<and> y \<subseteq> ball (x i) e' \<and> y \<in> union_closed_basis" by auto
  qed
  then guess B .. note B = this
  def B' \<equiv> "Pi' (domain x) (\<lambda>i. (B i)::'b set)"
  hence "B' \<in> basis_finmap" unfolding B'_def using B
    by (intro in_basis_finmapI) auto
  moreover have "x \<in> B'" unfolding B'_def using B by auto
  moreover have "B' \<subseteq> O'"
  proof
    fix y assume "y \<in> B'" with B have "domain y = domain x" unfolding B'_def
      by (simp add: Pi'_def)
    show "y \<in> O'"
    proof (rule e)
      have "dist y x = (\<Sum>i \<in> domain x. dist (y i) (x i))"
        using `domain y = domain x` by (simp add: dist_finmap_def)
      also have "\<dots> \<le> (\<Sum>i \<in> domain x. e')"
      proof (rule setsum_mono)
        fix i assume "i \<in> domain x"
        with `y \<in> B'` B have "y i \<in> B i"
          by (simp add: Pi'_def B'_def)
        hence "y i \<in> ball (x i) e'" using B `domain y = domain x` `i \<in> domain x`
          by force
        thus "dist (y i) (x i) \<le> e'" by (simp add: dist_commute)
      qed
      also have "\<dots> = card (domain x) * e'" by (simp add: real_eq_of_nat)
      also have "\<dots> < e" using e by (simp add: e'_def field_simps)
      finally show "dist y x < e" .
    qed
  qed
  ultimately
  show "\<exists>B'\<in>basis_finmap. x \<in> B' \<and> B' \<subseteq> O'" by blast
qed

lemma range_enum_basis_finmap_imp_open:
  assumes "x \<in> basis_finmap"
  shows "open x"
  using finmap_topological_basis assms by (auto simp: topological_basis_def)

instance proof qed (blast intro: finmap_topological_basis countable_basis_finmap)

end

subsection {* Product Measurable Space of Finite Maps *}

definition "PiF I M \<equiv>
  sigma (\<Union>J \<in> I. (\<Pi>' j\<in>J. space (M j))) {(\<Pi>' j\<in>J. X j) |X J. J \<in> I \<and> X \<in> (\<Pi> j\<in>J. sets (M j))}"

abbreviation
  "Pi\<^isub>F I M \<equiv> PiF I M"

syntax
  "_PiF" :: "pttrn \<Rightarrow> 'i set \<Rightarrow> 'a measure \<Rightarrow> ('i => 'a) measure"  ("(3PIF _:_./ _)" 10)

syntax (xsymbols)
  "_PiF" :: "pttrn \<Rightarrow> 'i set \<Rightarrow> 'a measure \<Rightarrow> ('i => 'a) measure"  ("(3\<Pi>\<^isub>F _\<in>_./ _)"  10)

syntax (HTML output)
  "_PiF" :: "pttrn \<Rightarrow> 'i set \<Rightarrow> 'a measure \<Rightarrow> ('i => 'a) measure"  ("(3\<Pi>\<^isub>F _\<in>_./ _)"  10)

translations
  "PIF x:I. M" == "CONST PiF I (%x. M)"

lemma PiF_gen_subset: "{(\<Pi>' j\<in>J. X j) |X J. J \<in> I \<and> X \<in> (\<Pi> j\<in>J. sets (M j))} \<subseteq>
    Pow (\<Union>J \<in> I. (\<Pi>' j\<in>J. space (M j)))"
  by (auto simp: Pi'_def) (blast dest: sets.sets_into_space)

lemma space_PiF: "space (PiF I M) = (\<Union>J \<in> I. (\<Pi>' j\<in>J. space (M j)))"
  unfolding PiF_def using PiF_gen_subset by (rule space_measure_of)

lemma sets_PiF:
  "sets (PiF I M) = sigma_sets (\<Union>J \<in> I. (\<Pi>' j\<in>J. space (M j)))
    {(\<Pi>' j\<in>J. X j) |X J. J \<in> I \<and> X \<in> (\<Pi> j\<in>J. sets (M j))}"
  unfolding PiF_def using PiF_gen_subset by (rule sets_measure_of)

lemma sets_PiF_singleton:
  "sets (PiF {I} M) = sigma_sets (\<Pi>' j\<in>I. space (M j))
    {(\<Pi>' j\<in>I. X j) |X. X \<in> (\<Pi> j\<in>I. sets (M j))}"
  unfolding sets_PiF by simp

lemma in_sets_PiFI:
  assumes "X = (Pi' J S)" "J \<in> I" "\<And>i. i\<in>J \<Longrightarrow> S i \<in> sets (M i)"
  shows "X \<in> sets (PiF I M)"
  unfolding sets_PiF
  using assms by blast

lemma product_in_sets_PiFI:
  assumes "J \<in> I" "\<And>i. i\<in>J \<Longrightarrow> S i \<in> sets (M i)"
  shows "(Pi' J S) \<in> sets (PiF I M)"
  unfolding sets_PiF
  using assms by blast

lemma singleton_space_subset_in_sets:
  fixes J
  assumes "J \<in> I"
  assumes "finite J"
  shows "space (PiF {J} M) \<in> sets (PiF I M)"
  using assms
  by (intro in_sets_PiFI[where J=J and S="\<lambda>i. space (M i)"])
      (auto simp: product_def space_PiF)

lemma singleton_subspace_set_in_sets:
  assumes A: "A \<in> sets (PiF {J} M)"
  assumes "finite J"
  assumes "J \<in> I"
  shows "A \<in> sets (PiF I M)"
  using A[unfolded sets_PiF]
  apply (induct A)
  unfolding sets_PiF[symmetric] unfolding space_PiF[symmetric]
  using assms
  by (auto intro: in_sets_PiFI intro!: singleton_space_subset_in_sets)

lemma finite_measurable_singletonI:
  assumes "finite I"
  assumes "\<And>J. J \<in> I \<Longrightarrow> finite J"
  assumes MN: "\<And>J. J \<in> I \<Longrightarrow> A \<in> measurable (PiF {J} M) N"
  shows "A \<in> measurable (PiF I M) N"
  unfolding measurable_def
proof safe
  fix y assume "y \<in> sets N"
  have "A -` y \<inter> space (PiF I M) = (\<Union>J\<in>I. A -` y \<inter> space (PiF {J} M))"
    by (auto simp: space_PiF)
  also have "\<dots> \<in> sets (PiF I M)"
  proof
    show "finite I" by fact
    fix J assume "J \<in> I"
    with assms have "finite J" by simp
    show "A -` y \<inter> space (PiF {J} M) \<in> sets (PiF I M)"
      by (rule singleton_subspace_set_in_sets[OF measurable_sets[OF assms(3)]]) fact+
  qed
  finally show "A -` y \<inter> space (PiF I M) \<in> sets (PiF I M)" .
next
  fix x assume "x \<in> space (PiF I M)" thus "A x \<in> space N"
    using MN[of "domain x"]
    by (auto simp: space_PiF measurable_space Pi'_def)
qed

lemma countable_finite_comprehension:
  fixes f :: "'a::countable set \<Rightarrow> _"
  assumes "\<And>s. P s \<Longrightarrow> finite s"
  assumes "\<And>s. P s \<Longrightarrow> f s \<in> sets M"
  shows "\<Union>{f s|s. P s} \<in> sets M"
proof -
  have "\<Union>{f s|s. P s} = (\<Union>n::nat. let s = set (from_nat n) in if P s then f s else {})"
  proof safe
    fix x X s assume "x \<in> f s" "P s"
    moreover with assms obtain l where "s = set l" using finite_list by blast
    ultimately show "x \<in> (\<Union>n. let s = set (from_nat n) in if P s then f s else {})" using `P s`
      by (auto intro!: exI[where x="to_nat l"])
  next
    fix x n assume "x \<in> (let s = set (from_nat n) in if P s then f s else {})"
    thus "x \<in> \<Union>{f s|s. P s}" using assms by (auto simp: Let_def split: split_if_asm)
  qed
  hence "\<Union>{f s|s. P s} = (\<Union>n. let s = set (from_nat n) in if P s then f s else {})" by simp
  also have "\<dots> \<in> sets M" using assms by (auto simp: Let_def)
  finally show ?thesis .
qed

lemma space_subset_in_sets:
  fixes J::"'a::countable set set"
  assumes "J \<subseteq> I"
  assumes "\<And>j. j \<in> J \<Longrightarrow> finite j"
  shows "space (PiF J M) \<in> sets (PiF I M)"
proof -
  have "space (PiF J M) = \<Union>{space (PiF {j} M)|j. j \<in> J}"
    unfolding space_PiF by blast
  also have "\<dots> \<in> sets (PiF I M)" using assms
    by (intro countable_finite_comprehension) (auto simp: singleton_space_subset_in_sets)
  finally show ?thesis .
qed

lemma subspace_set_in_sets:
  fixes J::"'a::countable set set"
  assumes A: "A \<in> sets (PiF J M)"
  assumes "J \<subseteq> I"
  assumes "\<And>j. j \<in> J \<Longrightarrow> finite j"
  shows "A \<in> sets (PiF I M)"
  using A[unfolded sets_PiF]
  apply (induct A)
  unfolding sets_PiF[symmetric] unfolding space_PiF[symmetric]
  using assms
  by (auto intro: in_sets_PiFI intro!: space_subset_in_sets)

lemma countable_measurable_PiFI:
  fixes I::"'a::countable set set"
  assumes MN: "\<And>J. J \<in> I \<Longrightarrow> finite J \<Longrightarrow> A \<in> measurable (PiF {J} M) N"
  shows "A \<in> measurable (PiF I M) N"
  unfolding measurable_def
proof safe
  fix y assume "y \<in> sets N"
  have "A -` y = (\<Union>{A -` y \<inter> {x. domain x = J}|J. finite J})" by auto
  { fix x::"'a \<Rightarrow>\<^isub>F 'b"
    from finite_list[of "domain x"] obtain xs where "set xs = domain x" by auto
    hence "\<exists>n. domain x = set (from_nat n)"
      by (intro exI[where x="to_nat xs"]) auto }
  hence "A -` y \<inter> space (PiF I M) = (\<Union>n. A -` y \<inter> space (PiF ({set (from_nat n)}\<inter>I) M))"
    by (auto simp: space_PiF Pi'_def)
  also have "\<dots> \<in> sets (PiF I M)"
    apply (intro sets.Int sets.countable_nat_UN subsetI, safe)
    apply (case_tac "set (from_nat i) \<in> I")
    apply simp_all
    apply (rule singleton_subspace_set_in_sets[OF measurable_sets[OF MN]])
    using assms `y \<in> sets N`
    apply (auto simp: space_PiF)
    done
  finally show "A -` y \<inter> space (PiF I M) \<in> sets (PiF I M)" .
next
  fix x assume "x \<in> space (PiF I M)" thus "A x \<in> space N"
    using MN[of "domain x"] by (auto simp: space_PiF measurable_space Pi'_def)
qed

lemma measurable_PiF:
  assumes f: "\<And>x. x \<in> space N \<Longrightarrow> domain (f x) \<in> I \<and> (\<forall>i\<in>domain (f x). (f x) i \<in> space (M i))"
  assumes S: "\<And>J S. J \<in> I \<Longrightarrow> (\<And>i. i \<in> J \<Longrightarrow> S i \<in> sets (M i)) \<Longrightarrow>
    f -` (Pi' J S) \<inter> space N \<in> sets N"
  shows "f \<in> measurable N (PiF I M)"
  unfolding PiF_def
  using PiF_gen_subset
  apply (rule measurable_measure_of)
  using f apply force
  apply (insert S, auto)
  done

lemma restrict_sets_measurable:
  assumes A: "A \<in> sets (PiF I M)" and "J \<subseteq> I"
  shows "A \<inter> {m. domain m \<in> J} \<in> sets (PiF J M)"
  using A[unfolded sets_PiF]
proof (induct A)
  case (Basic a)
  then obtain K S where S: "a = Pi' K S" "K \<in> I" "(\<forall>i\<in>K. S i \<in> sets (M i))"
    by auto
  show ?case
  proof cases
    assume "K \<in> J"
    hence "a \<inter> {m. domain m \<in> J} \<in> {Pi' K X |X K. K \<in> J \<and> X \<in> (\<Pi> j\<in>K. sets (M j))}" using S
      by (auto intro!: exI[where x=K] exI[where x=S] simp: Pi'_def)
    also have "\<dots> \<subseteq> sets (PiF J M)" unfolding sets_PiF by auto
    finally show ?thesis .
  next
    assume "K \<notin> J"
    hence "a \<inter> {m. domain m \<in> J} = {}" using S by (auto simp: Pi'_def)
    also have "\<dots> \<in> sets (PiF J M)" by simp
    finally show ?thesis .
  qed
next
  case (Union a)
  have "UNION UNIV a \<inter> {m. domain m \<in> J} = (\<Union>i. (a i \<inter> {m. domain m \<in> J}))"
    by simp
  also have "\<dots> \<in> sets (PiF J M)" using Union by (intro sets.countable_nat_UN) auto
  finally show ?case .
next
  case (Compl a)
  have "(space (PiF I M) - a) \<inter> {m. domain m \<in> J} = (space (PiF J M) - (a \<inter> {m. domain m \<in> J}))"
    using `J \<subseteq> I` by (auto simp: space_PiF Pi'_def)
  also have "\<dots> \<in> sets (PiF J M)" using Compl by auto
  finally show ?case by (simp add: space_PiF)
qed simp

lemma measurable_finmap_of:
  assumes f: "\<And>i. (\<exists>x \<in> space N. i \<in> J x) \<Longrightarrow> (\<lambda>x. f x i) \<in> measurable N (M i)"
  assumes J: "\<And>x. x \<in> space N \<Longrightarrow> J x \<in> I" "\<And>x. x \<in> space N \<Longrightarrow> finite (J x)"
  assumes JN: "\<And>S. {x. J x = S} \<inter> space N \<in> sets N"
  shows "(\<lambda>x. finmap_of (J x) (f x)) \<in> measurable N (PiF I M)"
proof (rule measurable_PiF)
  fix x assume "x \<in> space N"
  with J[of x] measurable_space[OF f]
  show "domain (finmap_of (J x) (f x)) \<in> I \<and>
        (\<forall>i\<in>domain (finmap_of (J x) (f x)). (finmap_of (J x) (f x)) i \<in> space (M i))"
    by auto
next
  fix K S assume "K \<in> I" and *: "\<And>i. i \<in> K \<Longrightarrow> S i \<in> sets (M i)"
  with J have eq: "(\<lambda>x. finmap_of (J x) (f x)) -` Pi' K S \<inter> space N =
    (if \<exists>x \<in> space N. K = J x \<and> finite K then if K = {} then {x \<in> space N. J x = K}
      else (\<Inter>i\<in>K. (\<lambda>x. f x i) -` S i \<inter> {x \<in> space N. J x = K}) else {})"
    by (auto simp: Pi'_def)
  have r: "{x \<in> space N. J x = K} = space N \<inter> ({x. J x = K} \<inter> space N)" by auto
  show "(\<lambda>x. finmap_of (J x) (f x)) -` Pi' K S \<inter> space N \<in> sets N"
    unfolding eq r
    apply (simp del: INT_simps add: )
    apply (intro conjI impI sets.finite_INT JN sets.Int[OF sets.top])
    apply simp apply assumption
    apply (subst Int_assoc[symmetric])
    apply (rule sets.Int)
    apply (intro measurable_sets[OF f] *) apply force apply assumption
    apply (intro JN)
    done
qed

lemma measurable_PiM_finmap_of:
  assumes "finite J"
  shows "finmap_of J \<in> measurable (Pi\<^isub>M J M) (PiF {J} M)"
  apply (rule measurable_finmap_of)
  apply (rule measurable_component_singleton)
  apply simp
  apply rule
  apply (rule `finite J`)
  apply simp
  done

lemma proj_measurable_singleton:
  assumes "A \<in> sets (M i)"
  shows "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space (PiF {I} M) \<in> sets (PiF {I} M)"
proof cases
  assume "i \<in> I"
  hence "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space (PiF {I} M) =
    Pi' I (\<lambda>x. if x = i then A else space (M x))"
    using sets.sets_into_space[OF ] `A \<in> sets (M i)` assms
    by (auto simp: space_PiF Pi'_def)
  thus ?thesis  using assms `A \<in> sets (M i)`
    by (intro in_sets_PiFI) auto
next
  assume "i \<notin> I"
  hence "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space (PiF {I} M) =
    (if undefined \<in> A then space (PiF {I} M) else {})" by (auto simp: space_PiF Pi'_def)
  thus ?thesis by simp
qed

lemma measurable_proj_singleton:
  assumes "i \<in> I"
  shows "(\<lambda>x. (x)\<^isub>F i) \<in> measurable (PiF {I} M) (M i)"
  by (unfold measurable_def, intro CollectI conjI ballI proj_measurable_singleton assms)
     (insert `i \<in> I`, auto simp: space_PiF)

lemma measurable_proj_countable:
  fixes I::"'a::countable set set"
  assumes "y \<in> space (M i)"
  shows "(\<lambda>x. if i \<in> domain x then (x)\<^isub>F i else y) \<in> measurable (PiF I M) (M i)"
proof (rule countable_measurable_PiFI)
  fix J assume "J \<in> I" "finite J"
  show "(\<lambda>x. if i \<in> domain x then x i else y) \<in> measurable (PiF {J} M) (M i)"
    unfolding measurable_def
  proof safe
    fix z assume "z \<in> sets (M i)"
    have "(\<lambda>x. if i \<in> domain x then x i else y) -` z \<inter> space (PiF {J} M) =
      (\<lambda>x. if i \<in> J then (x)\<^isub>F i else y) -` z \<inter> space (PiF {J} M)"
      by (auto simp: space_PiF Pi'_def)
    also have "\<dots> \<in> sets (PiF {J} M)" using `z \<in> sets (M i)` `finite J`
      by (cases "i \<in> J") (auto intro!: measurable_sets[OF measurable_proj_singleton])
    finally show "(\<lambda>x. if i \<in> domain x then x i else y) -` z \<inter> space (PiF {J} M) \<in>
      sets (PiF {J} M)" .
  qed (insert `y \<in> space (M i)`, auto simp: space_PiF Pi'_def)
qed

lemma measurable_restrict_proj:
  assumes "J \<in> II" "finite J"
  shows "finmap_of J \<in> measurable (PiM J M) (PiF II M)"
  using assms
  by (intro measurable_finmap_of measurable_component_singleton) auto

lemma measurable_proj_PiM:
  fixes J K ::"'a::countable set" and I::"'a set set"
  assumes "finite J" "J \<in> I"
  assumes "x \<in> space (PiM J M)"
  shows "proj \<in> measurable (PiF {J} M) (PiM J M)"
proof (rule measurable_PiM_single)
  show "proj \<in> space (PiF {J} M) \<rightarrow> (\<Pi>\<^isub>E i \<in> J. space (M i))"
    using assms by (auto simp add: space_PiM space_PiF extensional_def sets_PiF Pi'_def)
next
  fix A i assume A: "i \<in> J" "A \<in> sets (M i)"
  show "{\<omega> \<in> space (PiF {J} M). (\<omega>)\<^isub>F i \<in> A} \<in> sets (PiF {J} M)"
  proof
    have "{\<omega> \<in> space (PiF {J} M). (\<omega>)\<^isub>F i \<in> A} =
      (\<lambda>\<omega>. (\<omega>)\<^isub>F i) -` A \<inter> space (PiF {J} M)" by auto
    also have "\<dots> \<in> sets (PiF {J} M)"
      using assms A by (auto intro: measurable_sets[OF measurable_proj_singleton] simp: space_PiM)
    finally show ?thesis .
  qed simp
qed

lemma space_PiF_singleton_eq_product:
  assumes "finite I"
  shows "space (PiF {I} M) = (\<Pi>' i\<in>I. space (M i))"
  by (auto simp: product_def space_PiF assms)

text {* adapted from @{thm sets_PiM_single} *}

lemma sets_PiF_single:
  assumes "finite I" "I \<noteq> {}"
  shows "sets (PiF {I} M) =
    sigma_sets (\<Pi>' i\<in>I. space (M i))
      {{f\<in>\<Pi>' i\<in>I. space (M i). f i \<in> A} | i A. i \<in> I \<and> A \<in> sets (M i)}"
    (is "_ = sigma_sets ?\<Omega> ?R")
  unfolding sets_PiF_singleton
proof (rule sigma_sets_eqI)
  interpret R: sigma_algebra ?\<Omega> "sigma_sets ?\<Omega> ?R" by (rule sigma_algebra_sigma_sets) auto
  fix A assume "A \<in> {Pi' I X |X. X \<in> (\<Pi> j\<in>I. sets (M j))}"
  then obtain X where X: "A = Pi' I X" "X \<in> (\<Pi> j\<in>I. sets (M j))" by auto
  show "A \<in> sigma_sets ?\<Omega> ?R"
  proof -
    from `I \<noteq> {}` X have "A = (\<Inter>j\<in>I. {f\<in>space (PiF {I} M). f j \<in> X j})"
      using sets.sets_into_space
      by (auto simp: space_PiF product_def) blast
    also have "\<dots> \<in> sigma_sets ?\<Omega> ?R"
      using X `I \<noteq> {}` assms by (intro R.finite_INT) (auto simp: space_PiF)
    finally show "A \<in> sigma_sets ?\<Omega> ?R" .
  qed
next
  fix A assume "A \<in> ?R"
  then obtain i B where A: "A = {f\<in>\<Pi>' i\<in>I. space (M i). f i \<in> B}" "i \<in> I" "B \<in> sets (M i)"
    by auto
  then have "A = (\<Pi>' j \<in> I. if j = i then B else space (M j))"
    using sets.sets_into_space[OF A(3)]
    apply (auto simp: Pi'_iff split: split_if_asm)
    apply blast
    done
  also have "\<dots> \<in> sigma_sets ?\<Omega> {Pi' I X |X. X \<in> (\<Pi> j\<in>I. sets (M j))}"
    using A
    by (intro sigma_sets.Basic )
       (auto intro: exI[where x="\<lambda>j. if j = i then B else space (M j)"])
  finally show "A \<in> sigma_sets ?\<Omega> {Pi' I X |X. X \<in> (\<Pi> j\<in>I. sets (M j))}" .
qed

text {* adapted from @{thm PiE_cong} *}

lemma Pi'_cong:
  assumes "finite I"
  assumes "\<And>i. i \<in> I \<Longrightarrow> f i = g i"
  shows "Pi' I f = Pi' I g"
using assms by (auto simp: Pi'_def)

text {* adapted from @{thm Pi_UN} *}

lemma Pi'_UN:
  fixes A :: "nat \<Rightarrow> 'i \<Rightarrow> 'a set"
  assumes "finite I"
  assumes mono: "\<And>i n m. i \<in> I \<Longrightarrow> n \<le> m \<Longrightarrow> A n i \<subseteq> A m i"
  shows "(\<Union>n. Pi' I (A n)) = Pi' I (\<lambda>i. \<Union>n. A n i)"
proof (intro set_eqI iffI)
  fix f assume "f \<in> Pi' I (\<lambda>i. \<Union>n. A n i)"
  then have "\<forall>i\<in>I. \<exists>n. f i \<in> A n i" "domain f = I" by (auto simp: `finite I` Pi'_def)
  from bchoice[OF this(1)] obtain n where n: "\<And>i. i \<in> I \<Longrightarrow> f i \<in> (A (n i) i)" by auto
  obtain k where k: "\<And>i. i \<in> I \<Longrightarrow> n i \<le> k"
    using `finite I` finite_nat_set_iff_bounded_le[of "n`I"] by auto
  have "f \<in> Pi' I (\<lambda>i. A k i)"
  proof
    fix i assume "i \<in> I"
    from mono[OF this, of "n i" k] k[OF this] n[OF this] `domain f = I` `i \<in> I`
    show "f i \<in> A k i " by (auto simp: `finite I`)
  qed (simp add: `domain f = I` `finite I`)
  then show "f \<in> (\<Union>n. Pi' I (A n))" by auto
qed (auto simp: Pi'_def `finite I`)

text {* adapted from @{thm sigma_prod_algebra_sigma_eq} *}

lemma sigma_fprod_algebra_sigma_eq:
  fixes E :: "'i \<Rightarrow> 'a set set"
  assumes [simp]: "finite I" "I \<noteq> {}"
  assumes S_mono: "\<And>i. i \<in> I \<Longrightarrow> incseq (S i)"
    and S_union: "\<And>i. i \<in> I \<Longrightarrow> (\<Union>j. S i j) = space (M i)"
    and S_in_E: "\<And>i. i \<in> I \<Longrightarrow> range (S i) \<subseteq> E i"
  assumes E_closed: "\<And>i. i \<in> I \<Longrightarrow> E i \<subseteq> Pow (space (M i))"
    and E_generates: "\<And>i. i \<in> I \<Longrightarrow> sets (M i) = sigma_sets (space (M i)) (E i)"
  defines "P == { Pi' I F | F. \<forall>i\<in>I. F i \<in> E i }"
  shows "sets (PiF {I} M) = sigma_sets (space (PiF {I} M)) P"
proof
  let ?P = "sigma (space (Pi\<^isub>F {I} M)) P"
  have P_closed: "P \<subseteq> Pow (space (Pi\<^isub>F {I} M))"
    using E_closed by (auto simp: space_PiF P_def Pi'_iff subset_eq)
  then have space_P: "space ?P = (\<Pi>' i\<in>I. space (M i))"
    by (simp add: space_PiF)
  have "sets (PiF {I} M) =
      sigma_sets (space ?P) {{f \<in> \<Pi>' i\<in>I. space (M i). f i \<in> A} |i A. i \<in> I \<and> A \<in> sets (M i)}"
    using sets_PiF_single[of I M] by (simp add: space_P)
  also have "\<dots> \<subseteq> sets (sigma (space (PiF {I} M)) P)"
  proof (safe intro!: sets.sigma_sets_subset)
    fix i A assume "i \<in> I" and A: "A \<in> sets (M i)"
    have "(\<lambda>x. (x)\<^isub>F i) \<in> measurable ?P (sigma (space (M i)) (E i))"
    proof (subst measurable_iff_measure_of)
      show "E i \<subseteq> Pow (space (M i))" using `i \<in> I` by fact
      from space_P `i \<in> I` show "(\<lambda>x. (x)\<^isub>F i) \<in> space ?P \<rightarrow> space (M i)"
        by auto
      show "\<forall>A\<in>E i. (\<lambda>x. (x)\<^isub>F i) -` A \<inter> space ?P \<in> sets ?P"
      proof
        fix A assume A: "A \<in> E i"
        then have "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space ?P = (\<Pi>' j\<in>I. if i = j then A else space (M j))"
          using E_closed `i \<in> I` by (auto simp: space_P Pi_iff subset_eq split: split_if_asm)
        also have "\<dots> = (\<Pi>' j\<in>I. \<Union>n. if i = j then A else S j n)"
          by (intro Pi'_cong) (simp_all add: S_union)
        also have "\<dots> = (\<Union>n. \<Pi>' j\<in>I. if i = j then A else S j n)"
          using S_mono
          by (subst Pi'_UN[symmetric, OF `finite I`]) (auto simp: incseq_def)
        also have "\<dots> \<in> sets ?P"
        proof (safe intro!: sets.countable_UN)
          fix n show "(\<Pi>' j\<in>I. if i = j then A else S j n) \<in> sets ?P"
            using A S_in_E
            by (simp add: P_closed)
               (auto simp: P_def subset_eq intro!: exI[of _ "\<lambda>j. if i = j then A else S j n"])
        qed
        finally show "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space ?P \<in> sets ?P"
          using P_closed by simp
      qed
    qed
    from measurable_sets[OF this, of A] A `i \<in> I` E_closed
    have "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space ?P \<in> sets ?P"
      by (simp add: E_generates)
    also have "(\<lambda>x. (x)\<^isub>F i) -` A \<inter> space ?P = {f \<in> \<Pi>' i\<in>I. space (M i). f i \<in> A}"
      using P_closed by (auto simp: space_PiF)
    finally show "\<dots> \<in> sets ?P" .
  qed
  finally show "sets (PiF {I} M) \<subseteq> sigma_sets (space (PiF {I} M)) P"
    by (simp add: P_closed)
  show "sigma_sets (space (PiF {I} M)) P \<subseteq> sets (PiF {I} M)"
    using `finite I` `I \<noteq> {}`
    by (auto intro!: sets.sigma_sets_subset product_in_sets_PiFI simp: E_generates P_def)
qed

lemma sets_PiF_eq_sigma_union_closed_basis_single:
  assumes "I \<noteq> {}"
  assumes [simp]: "finite I"
  shows "sets (PiF {I} (\<lambda>_. borel)) = sigma_sets (space (PiF {I} (\<lambda>_. borel)))
    {Pi' I F |F. (\<forall>i\<in>I. F i \<in> union_closed_basis)}"
proof -
  from open_incseqE[OF open_UNIV] guess S::"nat \<Rightarrow> 'b set" . note S = this
  show ?thesis
  proof (rule sigma_fprod_algebra_sigma_eq)
    show "finite I" by simp
    show "I \<noteq> {}" by fact
    show "incseq S" "(\<Union>j. S j) = space borel" "range S \<subseteq> union_closed_basis"
      using S by simp_all
    show "union_closed_basis \<subseteq> Pow (space borel)" by simp
    show "sets borel = sigma_sets (space borel) union_closed_basis"
      by (simp add: borel_eq_union_closed_basis)
  qed
qed

text {* adapted from @{thm sets_PiF_eq_sigma_union_closed_basis_single} *}

lemma sets_PiM_eq_sigma_union_closed_basis:
  assumes "I \<noteq> {}"
  assumes [simp]: "finite I"
  shows "sets (PiM I (\<lambda>_. borel)) = sigma_sets (space (PiM I (\<lambda>_. borel)))
    {Pi\<^isub>E I F |F. \<forall>i\<in>I. F i \<in> union_closed_basis}"
proof -
  from open_incseqE[OF open_UNIV] guess S::"nat \<Rightarrow> 'b set" . note S = this
  show ?thesis
  proof (rule sigma_prod_algebra_sigma_eq)
    show "finite I" by simp note[[show_types]]
    fix i show "(\<Union>j. S j) = space borel" "range S \<subseteq> union_closed_basis"
      using S by simp_all
    show "union_closed_basis \<subseteq> Pow (space borel)" by simp
    show "sets borel = sigma_sets (space borel) union_closed_basis"
      by (simp add: borel_eq_union_closed_basis)
  qed
qed

lemma product_open_generates_sets_PiF_single:
  assumes "I \<noteq> {}"
  assumes [simp]: "finite I"
  shows "sets (PiF {I} (\<lambda>_. borel::'b::second_countable_topology measure)) =
    sigma_sets (space (PiF {I} (\<lambda>_. borel))) {Pi' I F |F. (\<forall>i\<in>I. F i \<in> Collect open)}"
proof -
  from open_incseqE[OF open_UNIV] guess S::"nat \<Rightarrow> 'b set" . note S = this
  show ?thesis
  proof (rule sigma_fprod_algebra_sigma_eq)
    show "finite I" by simp
    show "I \<noteq> {}" by fact
    show "incseq S" "(\<Union>j. S j) = space borel" "range S \<subseteq> Collect open"
      using S by (auto simp: open_union_closed_basis)
    show "Collect open \<subseteq> Pow (space borel)" by simp
    show "sets borel = sigma_sets (space borel) (Collect open)"
      by (simp add: borel_def)
  qed
qed

lemma product_open_generates_sets_PiM:
  assumes "I \<noteq> {}"
  assumes [simp]: "finite I"
  shows "sets (PiM I (\<lambda>_. borel::'b::second_countable_topology measure)) =
    sigma_sets (space (PiM I (\<lambda>_. borel))) {Pi\<^isub>E I F |F. \<forall>i\<in>I. F i \<in> Collect open}"
proof -
  from open_incseqE[OF open_UNIV] guess S::"nat \<Rightarrow> 'b set" . note S = this
  show ?thesis
  proof (rule sigma_prod_algebra_sigma_eq)
    show "finite I" by simp note[[show_types]]
    fix i show "(\<Union>j. S j) = space borel" "range S \<subseteq> Collect open"
      using S by (auto simp: open_union_closed_basis)
    show "Collect open \<subseteq> Pow (space borel)" by simp
    show "sets borel = sigma_sets (space borel) (Collect open)"
      by (simp add: borel_def)
  qed
qed

lemma finmap_UNIV[simp]: "(\<Union>J\<in>Collect finite. PI' j : J. UNIV) = UNIV" by auto

lemma borel_eq_PiF_borel:
  shows "(borel :: ('i::countable \<Rightarrow>\<^isub>F 'a::polish_space) measure) =
    PiF (Collect finite) (\<lambda>_. borel :: 'a measure)"
  unfolding borel_def PiF_def
proof (rule measure_eqI, clarsimp, rule sigma_sets_eqI)
  fix a::"('i \<Rightarrow>\<^isub>F 'a) set" assume "a \<in> Collect open" hence "open a" by simp
  then obtain B' where B': "B'\<subseteq>basis_finmap" "a = \<Union>B'"
    using finmap_topological_basis by (force simp add: topological_basis_def)
  have "a \<in> sigma UNIV {Pi' J X |X J. finite J \<and> X \<in> J \<rightarrow> sigma_sets UNIV (Collect open)}"
    unfolding `a = \<Union>B'`
  proof (rule sets.countable_Union)
    from B' countable_basis_finmap show "countable B'" by (metis countable_subset)
  next
    show "B' \<subseteq> sets (sigma UNIV
      {Pi' J X |X J. finite J \<and> X \<in> J \<rightarrow> sigma_sets UNIV (Collect open)})" (is "_ \<subseteq> sets ?s")
    proof
      fix x assume "x \<in> B'" with B' have "x \<in> basis_finmap" by auto
      then obtain J X where "x = Pi' J X" "finite J" "X \<in> J \<rightarrow> sigma_sets UNIV (Collect open)"
        by (auto simp: basis_finmap_def open_union_closed_basis)
      thus "x \<in> sets ?s" by auto
    qed
  qed
  thus "a \<in> sigma_sets UNIV {Pi' J X |X J. finite J \<and> X \<in> J \<rightarrow> sigma_sets UNIV (Collect open)}"
    by simp
next
  fix b::"('i \<Rightarrow>\<^isub>F 'a) set"
  assume "b \<in> {Pi' J X |X J. finite J \<and> X \<in> J \<rightarrow> sigma_sets UNIV (Collect open)}"
  hence b': "b \<in> sets (Pi\<^isub>F (Collect finite) (\<lambda>_. borel))" by (auto simp: sets_PiF borel_def)
  let ?b = "\<lambda>J. b \<inter> {x. domain x = J}"
  have "b = \<Union>((\<lambda>J. ?b J) ` Collect finite)" by auto
  also have "\<dots> \<in> sets borel"
  proof (rule sets.countable_Union, safe)
    fix J::"'i set" assume "finite J"
    { assume ef: "J = {}"
      have "?b J \<in> sets borel"
      proof cases
        assume "?b J \<noteq> {}"
        then obtain f where "f \<in> b" "domain f = {}" using ef by auto
        hence "?b J = {f}" using `J = {}`
          by (auto simp: finmap_eq_iff)
        also have "{f} \<in> sets borel" by simp
        finally show ?thesis .
      qed simp
    } moreover {
      assume "J \<noteq> ({}::'i set)"
      have "(?b J) = b \<inter> {m. domain m \<in> {J}}" by auto
      also have "\<dots> \<in> sets (PiF {J} (\<lambda>_. borel))"
        using b' by (rule restrict_sets_measurable) (auto simp: `finite J`)
      also have "\<dots> = sigma_sets (space (PiF {J} (\<lambda>_. borel)))
        {Pi' (J) F |F. (\<forall>j\<in>J. F j \<in> Collect open)}"
        (is "_ = sigma_sets _ ?P")
       by (rule product_open_generates_sets_PiF_single[OF `J \<noteq> {}` `finite J`])
      also have "\<dots> \<subseteq> sigma_sets UNIV (Collect open)"
        by (intro sigma_sets_mono'') (auto intro!: open_Pi'I simp: space_PiF)
      finally have "(?b J) \<in> sets borel" by (simp add: borel_def)
    } ultimately show "(?b J) \<in> sets borel" by blast
  qed (simp add: countable_Collect_finite)
  finally show "b \<in> sigma_sets UNIV (Collect open)" by (simp add: borel_def)
qed (simp add: emeasure_sigma borel_def PiF_def)

subsection {* Isomorphism between Functions and Finite Maps *}

lemma measurable_finmap_compose:
  shows "(\<lambda>m. compose J m f) \<in> measurable (PiM (f ` J) (\<lambda>_. M)) (PiM J (\<lambda>_. M))"
  unfolding compose_def by measurable

lemma measurable_compose_inv:
  assumes inj: "\<And>j. j \<in> J \<Longrightarrow> f' (f j) = j"
  shows "(\<lambda>m. compose (f ` J) m f') \<in> measurable (PiM J (\<lambda>_. M)) (PiM (f ` J) (\<lambda>_. M))"
  unfolding compose_def by (rule measurable_restrict) (auto simp: inj)

locale function_to_finmap =
  fixes J::"'a set" and f :: "'a \<Rightarrow> 'b::countable" and f'
  assumes [simp]: "finite J"
  assumes inv: "i \<in> J \<Longrightarrow> f' (f i) = i"
begin

text {* to measure finmaps *}

definition "fm = (finmap_of (f ` J)) o (\<lambda>g. compose (f ` J) g f')"

lemma domain_fm[simp]: "domain (fm x) = f ` J"
  unfolding fm_def by simp

lemma fm_restrict[simp]: "fm (restrict y J) = fm y"
  unfolding fm_def by (auto simp: compose_def inv intro: restrict_ext)

lemma fm_product:
  assumes "\<And>i. space (M i) = UNIV"
  shows "fm -` Pi' (f ` J) S \<inter> space (Pi\<^isub>M J M) = (\<Pi>\<^isub>E j \<in> J. S (f j))"
  using assms
  by (auto simp: inv fm_def compose_def space_PiM Pi'_def)

lemma fm_measurable:
  assumes "f ` J \<in> N"
  shows "fm \<in> measurable (Pi\<^isub>M J (\<lambda>_. M)) (Pi\<^isub>F N (\<lambda>_. M))"
  unfolding fm_def
proof (rule measurable_comp, rule measurable_compose_inv)
  show "finmap_of (f ` J) \<in> measurable (Pi\<^isub>M (f ` J) (\<lambda>_. M)) (PiF N (\<lambda>_. M)) "
    using assms by (intro measurable_finmap_of measurable_component_singleton) auto
qed (simp_all add: inv)

lemma proj_fm:
  assumes "x \<in> J"
  shows "fm m (f x) = m x"
  using assms by (auto simp: fm_def compose_def o_def inv)

lemma inj_on_compose_f': "inj_on (\<lambda>g. compose (f ` J) g f') (extensional J)"
proof (rule inj_on_inverseI)
  fix x::"'a \<Rightarrow> 'c" assume "x \<in> extensional J"
  thus "(\<lambda>x. compose J x f) (compose (f ` J) x f') = x"
    by (auto simp: compose_def inv extensional_def)
qed

lemma inj_on_fm:
  assumes "\<And>i. space (M i) = UNIV"
  shows "inj_on fm (space (Pi\<^isub>M J M))"
  using assms
  apply (auto simp: fm_def space_PiM PiE_def)
  apply (rule comp_inj_on)
  apply (rule inj_on_compose_f')
  apply (rule finmap_of_inj_on_extensional_finite)
  apply simp
  apply (auto)
  done

text {* to measure functions *}

definition "mf = (\<lambda>g. compose J g f) o proj"

lemma mf_fm:
  assumes "x \<in> space (Pi\<^isub>M J (\<lambda>_. M))"
  shows "mf (fm x) = x"
proof -
  have "mf (fm x) \<in> extensional J"
    by (auto simp: mf_def extensional_def compose_def)
  moreover
  have "x \<in> extensional J" using assms sets.sets_into_space
    by (force simp: space_PiM PiE_def)
  moreover
  { fix i assume "i \<in> J"
    hence "mf (fm x) i = x i"
      by (auto simp: inv mf_def compose_def fm_def)
  }
  ultimately
  show ?thesis by (rule extensionalityI)
qed

lemma mf_measurable:
  assumes "space M = UNIV"
  shows "mf \<in> measurable (PiF {f ` J} (\<lambda>_. M)) (PiM J (\<lambda>_. M))"
  unfolding mf_def
proof (rule measurable_comp, rule measurable_proj_PiM)
  show "(\<lambda>g. compose J g f) \<in> measurable (Pi\<^isub>M (f ` J) (\<lambda>x. M)) (Pi\<^isub>M J (\<lambda>_. M))"
    by (rule measurable_finmap_compose)
qed (auto simp add: space_PiM extensional_def assms)

lemma fm_image_measurable:
  assumes "space M = UNIV"
  assumes "X \<in> sets (Pi\<^isub>M J (\<lambda>_. M))"
  shows "fm ` X \<in> sets (PiF {f ` J} (\<lambda>_. M))"
proof -
  have "fm ` X = (mf) -` X \<inter> space (PiF {f ` J} (\<lambda>_. M))"
  proof safe
    fix x assume "x \<in> X"
    with mf_fm[of x] sets.sets_into_space[OF assms(2)] show "fm x \<in> mf -` X" by auto
    show "fm x \<in> space (PiF {f ` J} (\<lambda>_. M))" by (simp add: space_PiF assms)
  next
    fix y x
    assume x: "mf y \<in> X"
    assume y: "y \<in> space (PiF {f ` J} (\<lambda>_. M))"
    thus "y \<in> fm ` X"
      by (intro image_eqI[OF _ x], unfold finmap_eq_iff)
         (auto simp: space_PiF fm_def mf_def compose_def inv Pi'_def)
  qed
  also have "\<dots> \<in> sets (PiF {f ` J} (\<lambda>_. M))"
    using assms
    by (intro measurable_sets[OF mf_measurable]) auto
  finally show ?thesis .
qed

lemma fm_image_measurable_finite:
  assumes "space M = UNIV"
  assumes "X \<in> sets (Pi\<^isub>M J (\<lambda>_. M::'c measure))"
  shows "fm ` X \<in> sets (PiF (Collect finite) (\<lambda>_. M::'c measure))"
  using fm_image_measurable[OF assms]
  by (rule subspace_set_in_sets) (auto simp: finite_subset)

text {* measure on finmaps *}

definition "mapmeasure M N = distr M (PiF (Collect finite) N) (fm)"

lemma sets_mapmeasure[simp]: "sets (mapmeasure M N) = sets (PiF (Collect finite) N)"
  unfolding mapmeasure_def by simp

lemma space_mapmeasure[simp]: "space (mapmeasure M N) = space (PiF (Collect finite) N)"
  unfolding mapmeasure_def by simp

lemma mapmeasure_PiF:
  assumes s1: "space M = space (Pi\<^isub>M J (\<lambda>_. N))"
  assumes s2: "sets M = sets (Pi\<^isub>M J (\<lambda>_. N))"
  assumes "space N = UNIV"
  assumes "X \<in> sets (PiF (Collect finite) (\<lambda>_. N))"
  shows "emeasure (mapmeasure M (\<lambda>_. N)) X = emeasure M ((fm -` X \<inter> extensional J))"
  using assms
  by (auto simp: measurable_eqI[OF s1 refl s2 refl] mapmeasure_def emeasure_distr
    fm_measurable space_PiM PiE_def)

lemma mapmeasure_PiM:
  fixes N::"'c measure"
  assumes s1: "space M = space (Pi\<^isub>M J (\<lambda>_. N))"
  assumes s2: "sets M = (Pi\<^isub>M J (\<lambda>_. N))"
  assumes N: "space N = UNIV"
  assumes X: "X \<in> sets M"
  shows "emeasure M X = emeasure (mapmeasure M (\<lambda>_. N)) (fm ` X)"
  unfolding mapmeasure_def
proof (subst emeasure_distr, subst measurable_eqI[OF s1 refl s2 refl], rule fm_measurable)
  have "X \<subseteq> space (Pi\<^isub>M J (\<lambda>_. N))" using assms by (simp add: sets.sets_into_space)
  from assms inj_on_fm[of "\<lambda>_. N"] set_mp[OF this] have "fm -` fm ` X \<inter> space (Pi\<^isub>M J (\<lambda>_. N)) = X"
    by (auto simp: vimage_image_eq inj_on_def)
  thus "emeasure M X = emeasure M (fm -` fm ` X \<inter> space M)" using s1
    by simp
  show "fm ` X \<in> sets (PiF (Collect finite) (\<lambda>_. N))"
    by (rule fm_image_measurable_finite[OF N X[simplified s2]])
qed simp

end

end
