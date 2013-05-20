(*  title:      HOL/Library/Topology_Euclidian_Space.thy
    Author:     Amine Chaieb, University of Cambridge
    Author:     Robert Himmelmann, TU Muenchen
    Author:     Brian Huffman, Portland State University
*)

header {* Elementary topology in Euclidean space. *}

theory Topology_Euclidean_Space
imports
  Complex_Main
  "~~/src/HOL/Library/Countable_Set"
  "~~/src/HOL/Library/Glbs"
  "~~/src/HOL/Library/FuncSet"
  Linear_Algebra
  Norm_Arith
begin

lemma dist_0_norm:
  fixes x :: "'a::real_normed_vector"
  shows "dist 0 x = norm x"
unfolding dist_norm by simp

lemma dist_double: "dist x y < d / 2 \<Longrightarrow> dist x z < d / 2 \<Longrightarrow> dist y z < d"
  using dist_triangle[of y z x] by (simp add: dist_commute)

(* LEGACY *)
lemma lim_subseq: "subseq r \<Longrightarrow> s ----> l \<Longrightarrow> (s o r) ----> l"
  by (rule LIMSEQ_subseq_LIMSEQ)

(* TODO: Move this to RComplete.thy -- would need to include Glb into RComplete *)
lemma real_isGlb_unique: "[| isGlb R S x; isGlb R S y |] ==> x = (y::real)"
  apply (frule isGlb_isLb)
  apply (frule_tac x = y in isGlb_isLb)
  apply (blast intro!: order_antisym dest!: isGlb_le_isLb)
  done

lemma countable_PiE: 
  "finite I \<Longrightarrow> (\<And>i. i \<in> I \<Longrightarrow> countable (F i)) \<Longrightarrow> countable (PiE I F)"
  by (induct I arbitrary: F rule: finite_induct) (auto simp: PiE_insert_eq)

subsection {* Topological Basis *}

context topological_space
begin

definition "topological_basis B =
  ((\<forall>b\<in>B. open b) \<and> (\<forall>x. open x \<longrightarrow> (\<exists>B'. B' \<subseteq> B \<and> Union B' = x)))"

lemma topological_basis_iff:
  assumes "\<And>B'. B' \<in> B \<Longrightarrow> open B'"
  shows "topological_basis B \<longleftrightarrow> (\<forall>O'. open O' \<longrightarrow> (\<forall>x\<in>O'. \<exists>B'\<in>B. x \<in> B' \<and> B' \<subseteq> O'))"
    (is "_ \<longleftrightarrow> ?rhs")
proof safe
  fix O' and x::'a
  assume H: "topological_basis B" "open O'" "x \<in> O'"
  hence "(\<exists>B'\<subseteq>B. \<Union>B' = O')" by (simp add: topological_basis_def)
  then obtain B' where "B' \<subseteq> B" "O' = \<Union>B'" by auto
  thus "\<exists>B'\<in>B. x \<in> B' \<and> B' \<subseteq> O'" using H by auto
next
  assume H: ?rhs
  show "topological_basis B" using assms unfolding topological_basis_def
  proof safe
    fix O'::"'a set" assume "open O'"
    with H obtain f where "\<forall>x\<in>O'. f x \<in> B \<and> x \<in> f x \<and> f x \<subseteq> O'"
      by (force intro: bchoice simp: Bex_def)
    thus "\<exists>B'\<subseteq>B. \<Union>B' = O'"
      by (auto intro: exI[where x="{f x |x. x \<in> O'}"])
  qed
qed

lemma topological_basisI:
  assumes "\<And>B'. B' \<in> B \<Longrightarrow> open B'"
  assumes "\<And>O' x. open O' \<Longrightarrow> x \<in> O' \<Longrightarrow> \<exists>B'\<in>B. x \<in> B' \<and> B' \<subseteq> O'"
  shows "topological_basis B"
  using assms by (subst topological_basis_iff) auto

lemma topological_basisE:
  fixes O'
  assumes "topological_basis B"
  assumes "open O'"
  assumes "x \<in> O'"
  obtains B' where "B' \<in> B" "x \<in> B'" "B' \<subseteq> O'"
proof atomize_elim
  from assms have "\<And>B'. B'\<in>B \<Longrightarrow> open B'" by (simp add: topological_basis_def)
  with topological_basis_iff assms
  show  "\<exists>B'. B' \<in> B \<and> x \<in> B' \<and> B' \<subseteq> O'" using assms by (simp add: Bex_def)
qed

lemma topological_basis_open:
  assumes "topological_basis B"
  assumes "X \<in> B"
  shows "open X"
  using assms
  by (simp add: topological_basis_def)

lemma basis_dense:
  fixes B::"'a set set" and f::"'a set \<Rightarrow> 'a"
  assumes "topological_basis B"
  assumes choosefrom_basis: "\<And>B'. B' \<noteq> {} \<Longrightarrow> f B' \<in> B'"
  shows "(\<forall>X. open X \<longrightarrow> X \<noteq> {} \<longrightarrow> (\<exists>B' \<in> B. f B' \<in> X))"
proof (intro allI impI)
  fix X::"'a set" assume "open X" "X \<noteq> {}"
  from topological_basisE[OF `topological_basis B` `open X` choosefrom_basis[OF `X \<noteq> {}`]]
  guess B' . note B' = this
  thus "\<exists>B'\<in>B. f B' \<in> X" by (auto intro!: choosefrom_basis)
qed

end

lemma topological_basis_prod:
  assumes A: "topological_basis A" and B: "topological_basis B"
  shows "topological_basis ((\<lambda>(a, b). a \<times> b) ` (A \<times> B))"
  unfolding topological_basis_def
proof (safe, simp_all del: ex_simps add: subset_image_iff ex_simps(1)[symmetric])
  fix S :: "('a \<times> 'b) set" assume "open S"
  then show "\<exists>X\<subseteq>A \<times> B. (\<Union>(a,b)\<in>X. a \<times> b) = S"
  proof (safe intro!: exI[of _ "{x\<in>A \<times> B. fst x \<times> snd x \<subseteq> S}"])
    fix x y assume "(x, y) \<in> S"
    from open_prod_elim[OF `open S` this]
    obtain a b where a: "open a""x \<in> a" and b: "open b" "y \<in> b" and "a \<times> b \<subseteq> S"
      by (metis mem_Sigma_iff)
    moreover from topological_basisE[OF A a] guess A0 .
    moreover from topological_basisE[OF B b] guess B0 .
    ultimately show "(x, y) \<in> (\<Union>(a, b)\<in>{X \<in> A \<times> B. fst X \<times> snd X \<subseteq> S}. a \<times> b)"
      by (intro UN_I[of "(A0, B0)"]) auto
  qed auto
qed (metis A B topological_basis_open open_Times)

subsection {* Countable Basis *}

locale countable_basis =
  fixes B::"'a::topological_space set set"
  assumes is_basis: "topological_basis B"
  assumes countable_basis: "countable B"
begin

lemma open_countable_basis_ex:
  assumes "open X"
  shows "\<exists>B' \<subseteq> B. X = Union B'"
  using assms countable_basis is_basis unfolding topological_basis_def by blast

lemma open_countable_basisE:
  assumes "open X"
  obtains B' where "B' \<subseteq> B" "X = Union B'"
  using assms open_countable_basis_ex by (atomize_elim) simp

lemma countable_dense_exists:
  shows "\<exists>D::'a set. countable D \<and> (\<forall>X. open X \<longrightarrow> X \<noteq> {} \<longrightarrow> (\<exists>d \<in> D. d \<in> X))"
proof -
  let ?f = "(\<lambda>B'. SOME x. x \<in> B')"
  have "countable (?f ` B)" using countable_basis by simp
  with basis_dense[OF is_basis, of ?f] show ?thesis
    by (intro exI[where x="?f ` B"]) (metis (mono_tags) all_not_in_conv imageI someI)
qed

lemma countable_dense_setE:
  obtains D :: "'a set"
  where "countable D" "\<And>X. open X \<Longrightarrow> X \<noteq> {} \<Longrightarrow> \<exists>d \<in> D. d \<in> X"
  using countable_dense_exists by blast

text {* Construction of an increasing sequence approximating open sets,
  therefore basis which is closed under union. *}

definition union_closed_basis::"'a set set" where
  "union_closed_basis = (\<lambda>l. \<Union>set l) ` lists B"

lemma basis_union_closed_basis: "topological_basis union_closed_basis"
proof (rule topological_basisI)
  fix O' and x::'a assume "open O'" "x \<in> O'"
  from topological_basisE[OF is_basis this] guess B' . note B' = this
  thus "\<exists>B'\<in>union_closed_basis. x \<in> B' \<and> B' \<subseteq> O'" unfolding union_closed_basis_def
    by (auto intro!: bexI[where x="[B']"])
next
  fix B' assume "B' \<in> union_closed_basis"
  thus "open B'"
    using topological_basis_open[OF is_basis]
    by (auto simp: union_closed_basis_def)
qed

lemma countable_union_closed_basis: "countable union_closed_basis"
  unfolding union_closed_basis_def using countable_basis by simp

lemmas open_union_closed_basis = topological_basis_open[OF basis_union_closed_basis]

lemma union_closed_basis_ex:
 assumes X: "X \<in> union_closed_basis"
 shows "\<exists>B'. finite B' \<and> X = \<Union>B' \<and> B' \<subseteq> B"
proof -
  from X obtain l where "\<And>x. x\<in>set l \<Longrightarrow> x\<in>B" "X = \<Union>set l" by (auto simp: union_closed_basis_def)
  thus ?thesis by auto
qed

lemma union_closed_basisE:
  assumes "X \<in> union_closed_basis"
  obtains B' where "finite B'" "X = \<Union>B'" "B' \<subseteq> B" using union_closed_basis_ex[OF assms] by blast

lemma union_closed_basisI:
  assumes "finite B'" "X = \<Union>B'" "B' \<subseteq> B"
  shows "X \<in> union_closed_basis"
proof -
  from finite_list[OF `finite B'`] guess l ..
  thus ?thesis using assms unfolding union_closed_basis_def by (auto intro!: image_eqI[where x=l])
qed

lemma empty_basisI[intro]: "{} \<in> union_closed_basis"
  by (rule union_closed_basisI[of "{}"]) auto

lemma union_basisI[intro]:
  assumes "X \<in> union_closed_basis" "Y \<in> union_closed_basis"
  shows "X \<union> Y \<in> union_closed_basis"
  using assms by (auto intro: union_closed_basisI elim!:union_closed_basisE)

lemma open_imp_Union_of_incseq:
  assumes "open X"
  shows "\<exists>S. incseq S \<and> (\<Union>j. S j) = X \<and> range S \<subseteq> union_closed_basis"
proof -
  from open_countable_basis_ex[OF `open X`]
  obtain B' where B': "B'\<subseteq>B" "X = \<Union>B'" by auto
  from this(1) countable_basis have "countable B'" by (rule countable_subset)
  show ?thesis
  proof cases
    assume "B' \<noteq> {}"
    def S \<equiv> "\<lambda>n. \<Union>i\<in>{0..n}. from_nat_into B' i"
    have S:"\<And>n. S n = \<Union>{from_nat_into B' i|i. i\<in>{0..n}}" unfolding S_def by force
    have "incseq S" by (force simp: S_def incseq_Suc_iff)
    moreover
    have "(\<Union>j. S j) = X" unfolding B'
    proof safe
      fix x X assume "X \<in> B'" "x \<in> X"
      then obtain n where "X = from_nat_into B' n"
        by (metis `countable B'` from_nat_into_surj)
      also have "\<dots> \<subseteq> S n" by (auto simp: S_def)
      finally show "x \<in> (\<Union>j. S j)" using `x \<in> X` by auto
    next
      fix x n
      assume "x \<in> S n"
      also have "\<dots> = (\<Union>i\<in>{0..n}. from_nat_into B' i)"
        by (simp add: S_def)
      also have "\<dots> \<subseteq> (\<Union>i. from_nat_into B' i)" by auto
      also have "\<dots> \<subseteq> \<Union>B'" using `B' \<noteq> {}` by (auto intro: from_nat_into)
      finally show "x \<in> \<Union>B'" .
    qed
    moreover have "range S \<subseteq> union_closed_basis" using B'
      by (auto intro!: union_closed_basisI[OF _ S] simp: from_nat_into `B' \<noteq> {}`)
    ultimately show ?thesis by auto
  qed (auto simp: B')
qed

lemma open_incseqE:
  assumes "open X"
  obtains S where "incseq S" "(\<Union>j. S j) = X" "range S \<subseteq> union_closed_basis"
  using open_imp_Union_of_incseq assms by atomize_elim

end

class first_countable_topology = topological_space +
  assumes first_countable_basis:
    "\<exists>A. countable A \<and> (\<forall>a\<in>A. x \<in> a \<and> open a) \<and> (\<forall>S. open S \<and> x \<in> S \<longrightarrow> (\<exists>a\<in>A. a \<subseteq> S))"

lemma (in first_countable_topology) countable_basis_at_decseq:
  obtains A :: "nat \<Rightarrow> 'a set" where
    "\<And>i. open (A i)" "\<And>i. x \<in> (A i)"
    "\<And>S. open S \<Longrightarrow> x \<in> S \<Longrightarrow> eventually (\<lambda>i. A i \<subseteq> S) sequentially"
proof atomize_elim
  from first_countable_basis[of x] obtain A
    where "countable A"
    and nhds: "\<And>a. a \<in> A \<Longrightarrow> open a" "\<And>a. a \<in> A \<Longrightarrow> x \<in> a"
    and incl: "\<And>S. open S \<Longrightarrow> x \<in> S \<Longrightarrow> \<exists>a\<in>A. a \<subseteq> S"  by auto
  then have "A \<noteq> {}" by auto
  with `countable A` have r: "A = range (from_nat_into A)" by auto
  def F \<equiv> "\<lambda>n. \<Inter>i\<le>n. from_nat_into A i"
  show "\<exists>A. (\<forall>i. open (A i)) \<and> (\<forall>i. x \<in> A i) \<and>
      (\<forall>S. open S \<longrightarrow> x \<in> S \<longrightarrow> eventually (\<lambda>i. A i \<subseteq> S) sequentially)"
  proof (safe intro!: exI[of _ F])
    fix i
    show "open (F i)" using nhds(1) r by (auto simp: F_def intro!: open_INT)
    show "x \<in> F i" using nhds(2) r by (auto simp: F_def)
  next
    fix S assume "open S" "x \<in> S"
    from incl[OF this] obtain i where "F i \<subseteq> S"
      by (subst (asm) r) (auto simp: F_def)
    moreover have "\<And>j. i \<le> j \<Longrightarrow> F j \<subseteq> F i"
      by (auto simp: F_def)
    ultimately show "eventually (\<lambda>i. F i \<subseteq> S) sequentially"
      by (auto simp: eventually_sequentially)
  qed
qed

lemma (in first_countable_topology) first_countable_basisE:
  obtains A where "countable A" "\<And>a. a \<in> A \<Longrightarrow> x \<in> a" "\<And>a. a \<in> A \<Longrightarrow> open a"
    "\<And>S. open S \<Longrightarrow> x \<in> S \<Longrightarrow> (\<exists>a\<in>A. a \<subseteq> S)"
  using first_countable_basis[of x]
  by atomize_elim auto

instance prod :: (first_countable_topology, first_countable_topology) first_countable_topology
proof
  fix x :: "'a \<times> 'b"
  from first_countable_basisE[of "fst x"] guess A :: "'a set set" . note A = this
  from first_countable_basisE[of "snd x"] guess B :: "'b set set" . note B = this
  show "\<exists>A::('a\<times>'b) set set. countable A \<and> (\<forall>a\<in>A. x \<in> a \<and> open a) \<and> (\<forall>S. open S \<and> x \<in> S \<longrightarrow> (\<exists>a\<in>A. a \<subseteq> S))"
  proof (intro exI[of _ "(\<lambda>(a, b). a \<times> b) ` (A \<times> B)"], safe)
    fix a b assume x: "a \<in> A" "b \<in> B"
    with A(2, 3)[of a] B(2, 3)[of b] show "x \<in> a \<times> b" "open (a \<times> b)"
      unfolding mem_Times_iff by (auto intro: open_Times)
  next
    fix S assume "open S" "x \<in> S"
    from open_prod_elim[OF this] guess a' b' .
    moreover with A(4)[of a'] B(4)[of b']
    obtain a b where "a \<in> A" "a \<subseteq> a'" "b \<in> B" "b \<subseteq> b'" by auto
    ultimately show "\<exists>a\<in>(\<lambda>(a, b). a \<times> b) ` (A \<times> B). a \<subseteq> S"
      by (auto intro!: bexI[of _ "a \<times> b"] bexI[of _ a] bexI[of _ b])
  qed (simp add: A B)
qed

instance metric_space \<subseteq> first_countable_topology
proof
  fix x :: 'a
  show "\<exists>A. countable A \<and> (\<forall>a\<in>A. x \<in> a \<and> open a) \<and> (\<forall>S. open S \<and> x \<in> S \<longrightarrow> (\<exists>a\<in>A. a \<subseteq> S))"
  proof (intro exI, safe)
    fix S assume "open S" "x \<in> S"
    then obtain r where "0 < r" "{y. dist x y < r} \<subseteq> S"
      by (auto simp: open_dist dist_commute subset_eq)
    moreover from reals_Archimedean[OF `0 < r`] guess n ..
    moreover
    then have "{y. dist x y < inverse (Suc n)} \<subseteq> {y. dist x y < r}"
      by (auto simp: inverse_eq_divide)
    ultimately show "\<exists>a\<in>range (\<lambda>n. {y. dist x y < inverse (Suc n)}). a \<subseteq> S"
      by auto
  qed (auto intro: open_ball)
qed

class second_countable_topology = topological_space +
  assumes ex_countable_basis:
    "\<exists>B::'a::topological_space set set. countable B \<and> topological_basis B"

sublocale second_countable_topology < countable_basis "SOME B. countable B \<and> topological_basis B"
  using someI_ex[OF ex_countable_basis] by unfold_locales safe

instance prod :: (second_countable_topology, second_countable_topology) second_countable_topology
proof
  obtain A :: "'a set set" where "countable A" "topological_basis A"
    using ex_countable_basis by auto
  moreover
  obtain B :: "'b set set" where "countable B" "topological_basis B"
    using ex_countable_basis by auto
  ultimately show "\<exists>B::('a \<times> 'b) set set. countable B \<and> topological_basis B"
    by (auto intro!: exI[of _ "(\<lambda>(a, b). a \<times> b) ` (A \<times> B)"] topological_basis_prod)
qed

instance second_countable_topology \<subseteq> first_countable_topology
proof
  fix x :: 'a
  def B \<equiv> "SOME B::'a set set. countable B \<and> topological_basis B"
  then have B: "countable B" "topological_basis B"
    using countable_basis is_basis
    by (auto simp: countable_basis is_basis)
  then show "\<exists>A. countable A \<and> (\<forall>a\<in>A. x \<in> a \<and> open a) \<and> (\<forall>S. open S \<and> x \<in> S \<longrightarrow> (\<exists>a\<in>A. a \<subseteq> S))"
    by (intro exI[of _ "{b\<in>B. x \<in> b}"])
       (fastforce simp: topological_space_class.topological_basis_def)
qed

subsection {* Polish spaces *}

text {* Textbooks define Polish spaces as completely metrizable.
  We assume the topology to be complete for a given metric. *}

class polish_space = complete_space + second_countable_topology

subsection {* General notion of a topology as a value *}

definition "istopology L \<longleftrightarrow> L {} \<and> (\<forall>S T. L S \<longrightarrow> L T \<longrightarrow> L (S \<inter> T)) \<and> (\<forall>K. Ball K L \<longrightarrow> L (\<Union> K))"
typedef 'a topology = "{L::('a set) \<Rightarrow> bool. istopology L}"
  morphisms "openin" "topology"
  unfolding istopology_def by blast

lemma istopology_open_in[intro]: "istopology(openin U)"
  using openin[of U] by blast

lemma topology_inverse': "istopology U \<Longrightarrow> openin (topology U) = U"
  using topology_inverse[unfolded mem_Collect_eq] .

lemma topology_inverse_iff: "istopology U \<longleftrightarrow> openin (topology U) = U"
  using topology_inverse[of U] istopology_open_in[of "topology U"] by auto

lemma topology_eq: "T1 = T2 \<longleftrightarrow> (\<forall>S. openin T1 S \<longleftrightarrow> openin T2 S)"
proof-
  { assume "T1=T2"
    hence "\<forall>S. openin T1 S \<longleftrightarrow> openin T2 S" by simp }
  moreover
  { assume H: "\<forall>S. openin T1 S \<longleftrightarrow> openin T2 S"
    hence "openin T1 = openin T2" by (simp add: fun_eq_iff)
    hence "topology (openin T1) = topology (openin T2)" by simp
    hence "T1 = T2" unfolding openin_inverse .
  }
  ultimately show ?thesis by blast
qed

text{* Infer the "universe" from union of all sets in the topology. *}

definition "topspace T =  \<Union>{S. openin T S}"

subsubsection {* Main properties of open sets *}

lemma openin_clauses:
  fixes U :: "'a topology"
  shows "openin U {}"
  "\<And>S T. openin U S \<Longrightarrow> openin U T \<Longrightarrow> openin U (S\<inter>T)"
  "\<And>K. (\<forall>S \<in> K. openin U S) \<Longrightarrow> openin U (\<Union>K)"
  using openin[of U] unfolding istopology_def mem_Collect_eq
  by fast+

lemma openin_subset[intro]: "openin U S \<Longrightarrow> S \<subseteq> topspace U"
  unfolding topspace_def by blast
lemma openin_empty[simp]: "openin U {}" by (simp add: openin_clauses)

lemma openin_Int[intro]: "openin U S \<Longrightarrow> openin U T \<Longrightarrow> openin U (S \<inter> T)"
  using openin_clauses by simp

lemma openin_Union[intro]: "(\<forall>S \<in>K. openin U S) \<Longrightarrow> openin U (\<Union> K)"
  using openin_clauses by simp

lemma openin_Un[intro]: "openin U S \<Longrightarrow> openin U T \<Longrightarrow> openin U (S \<union> T)"
  using openin_Union[of "{S,T}" U] by auto

lemma openin_topspace[intro, simp]: "openin U (topspace U)" by (simp add: openin_Union topspace_def)

lemma openin_subopen: "openin U S \<longleftrightarrow> (\<forall>x \<in> S. \<exists>T. openin U T \<and> x \<in> T \<and> T \<subseteq> S)"
  (is "?lhs \<longleftrightarrow> ?rhs")
proof
  assume ?lhs
  then show ?rhs by auto
next
  assume H: ?rhs
  let ?t = "\<Union>{T. openin U T \<and> T \<subseteq> S}"
  have "openin U ?t" by (simp add: openin_Union)
  also have "?t = S" using H by auto
  finally show "openin U S" .
qed


subsubsection {* Closed sets *}

definition "closedin U S \<longleftrightarrow> S \<subseteq> topspace U \<and> openin U (topspace U - S)"

lemma closedin_subset: "closedin U S \<Longrightarrow> S \<subseteq> topspace U" by (metis closedin_def)
lemma closedin_empty[simp]: "closedin U {}" by (simp add: closedin_def)
lemma closedin_topspace[intro,simp]:
  "closedin U (topspace U)" by (simp add: closedin_def)
lemma closedin_Un[intro]: "closedin U S \<Longrightarrow> closedin U T \<Longrightarrow> closedin U (S \<union> T)"
  by (auto simp add: Diff_Un closedin_def)

lemma Diff_Inter[intro]: "A - \<Inter>S = \<Union> {A - s|s. s\<in>S}" by auto
lemma closedin_Inter[intro]: assumes Ke: "K \<noteq> {}" and Kc: "\<forall>S \<in>K. closedin U S"
  shows "closedin U (\<Inter> K)"  using Ke Kc unfolding closedin_def Diff_Inter by auto

lemma closedin_Int[intro]: "closedin U S \<Longrightarrow> closedin U T \<Longrightarrow> closedin U (S \<inter> T)"
  using closedin_Inter[of "{S,T}" U] by auto

lemma Diff_Diff_Int: "A - (A - B) = A \<inter> B" by blast
lemma openin_closedin_eq: "openin U S \<longleftrightarrow> S \<subseteq> topspace U \<and> closedin U (topspace U - S)"
  apply (auto simp add: closedin_def Diff_Diff_Int inf_absorb2)
  apply (metis openin_subset subset_eq)
  done

lemma openin_closedin:  "S \<subseteq> topspace U \<Longrightarrow> (openin U S \<longleftrightarrow> closedin U (topspace U - S))"
  by (simp add: openin_closedin_eq)

lemma openin_diff[intro]: assumes oS: "openin U S" and cT: "closedin U T" shows "openin U (S - T)"
proof-
  have "S - T = S \<inter> (topspace U - T)" using openin_subset[of U S]  oS cT
    by (auto simp add: topspace_def openin_subset)
  then show ?thesis using oS cT by (auto simp add: closedin_def)
qed

lemma closedin_diff[intro]: assumes oS: "closedin U S" and cT: "openin U T" shows "closedin U (S - T)"
proof-
  have "S - T = S \<inter> (topspace U - T)" using closedin_subset[of U S]  oS cT
    by (auto simp add: topspace_def )
  then show ?thesis using oS cT by (auto simp add: openin_closedin_eq)
qed

subsubsection {* Subspace topology *}

definition "subtopology U V = topology (\<lambda>T. \<exists>S. T = S \<inter> V \<and> openin U S)"

lemma istopology_subtopology: "istopology (\<lambda>T. \<exists>S. T = S \<inter> V \<and> openin U S)"
  (is "istopology ?L")
proof-
  have "?L {}" by blast
  {fix A B assume A: "?L A" and B: "?L B"
    from A B obtain Sa and Sb where Sa: "openin U Sa" "A = Sa \<inter> V" and Sb: "openin U Sb" "B = Sb \<inter> V" by blast
    have "A\<inter>B = (Sa \<inter> Sb) \<inter> V" "openin U (Sa \<inter> Sb)"  using Sa Sb by blast+
    then have "?L (A \<inter> B)" by blast}
  moreover
  {fix K assume K: "K \<subseteq> Collect ?L"
    have th0: "Collect ?L = (\<lambda>S. S \<inter> V) ` Collect (openin U)"
      apply (rule set_eqI)
      apply (simp add: Ball_def image_iff)
      by metis
    from K[unfolded th0 subset_image_iff]
    obtain Sk where Sk: "Sk \<subseteq> Collect (openin U)" "K = (\<lambda>S. S \<inter> V) ` Sk" by blast
    have "\<Union>K = (\<Union>Sk) \<inter> V" using Sk by auto
    moreover have "openin U (\<Union> Sk)" using Sk by (auto simp add: subset_eq)
    ultimately have "?L (\<Union>K)" by blast}
  ultimately show ?thesis
    unfolding subset_eq mem_Collect_eq istopology_def by blast
qed

lemma openin_subtopology:
  "openin (subtopology U V) S \<longleftrightarrow> (\<exists> T. (openin U T) \<and> (S = T \<inter> V))"
  unfolding subtopology_def topology_inverse'[OF istopology_subtopology]
  by auto

lemma topspace_subtopology: "topspace(subtopology U V) = topspace U \<inter> V"
  by (auto simp add: topspace_def openin_subtopology)

lemma closedin_subtopology:
  "closedin (subtopology U V) S \<longleftrightarrow> (\<exists>T. closedin U T \<and> S = T \<inter> V)"
  unfolding closedin_def topspace_subtopology
  apply (simp add: openin_subtopology)
  apply (rule iffI)
  apply clarify
  apply (rule_tac x="topspace U - T" in exI)
  by auto

lemma openin_subtopology_refl: "openin (subtopology U V) V \<longleftrightarrow> V \<subseteq> topspace U"
  unfolding openin_subtopology
  apply (rule iffI, clarify)
  apply (frule openin_subset[of U])  apply blast
  apply (rule exI[where x="topspace U"])
  apply auto
  done

lemma subtopology_superset:
  assumes UV: "topspace U \<subseteq> V"
  shows "subtopology U V = U"
proof-
  {fix S
    {fix T assume T: "openin U T" "S = T \<inter> V"
      from T openin_subset[OF T(1)] UV have eq: "S = T" by blast
      have "openin U S" unfolding eq using T by blast}
    moreover
    {assume S: "openin U S"
      hence "\<exists>T. openin U T \<and> S = T \<inter> V"
        using openin_subset[OF S] UV by auto}
    ultimately have "(\<exists>T. openin U T \<and> S = T \<inter> V) \<longleftrightarrow> openin U S" by blast}
  then show ?thesis unfolding topology_eq openin_subtopology by blast
qed

lemma subtopology_topspace[simp]: "subtopology U (topspace U) = U"
  by (simp add: subtopology_superset)

lemma subtopology_UNIV[simp]: "subtopology U UNIV = U"
  by (simp add: subtopology_superset)

subsubsection {* The standard Euclidean topology *}

definition
  euclidean :: "'a::topological_space topology" where
  "euclidean = topology open"

lemma open_openin: "open S \<longleftrightarrow> openin euclidean S"
  unfolding euclidean_def
  apply (rule cong[where x=S and y=S])
  apply (rule topology_inverse[symmetric])
  apply (auto simp add: istopology_def)
  done

lemma topspace_euclidean: "topspace euclidean = UNIV"
  apply (simp add: topspace_def)
  apply (rule set_eqI)
  by (auto simp add: open_openin[symmetric])

lemma topspace_euclidean_subtopology[simp]: "topspace (subtopology euclidean S) = S"
  by (simp add: topspace_euclidean topspace_subtopology)

lemma closed_closedin: "closed S \<longleftrightarrow> closedin euclidean S"
  by (simp add: closed_def closedin_def topspace_euclidean open_openin Compl_eq_Diff_UNIV)

lemma open_subopen: "open S \<longleftrightarrow> (\<forall>x\<in>S. \<exists>T. open T \<and> x \<in> T \<and> T \<subseteq> S)"
  by (simp add: open_openin openin_subopen[symmetric])

text {* Basic "localization" results are handy for connectedness. *}

lemma openin_open: "openin (subtopology euclidean U) S \<longleftrightarrow> (\<exists>T. open T \<and> (S = U \<inter> T))"
  by (auto simp add: openin_subtopology open_openin[symmetric])

lemma openin_open_Int[intro]: "open S \<Longrightarrow> openin (subtopology euclidean U) (U \<inter> S)"
  by (auto simp add: openin_open)

lemma open_openin_trans[trans]:
 "open S \<Longrightarrow> open T \<Longrightarrow> T \<subseteq> S \<Longrightarrow> openin (subtopology euclidean S) T"
  by (metis Int_absorb1  openin_open_Int)

lemma open_subset:  "S \<subseteq> T \<Longrightarrow> open S \<Longrightarrow> openin (subtopology euclidean T) S"
  by (auto simp add: openin_open)

lemma closedin_closed: "closedin (subtopology euclidean U) S \<longleftrightarrow> (\<exists>T. closed T \<and> S = U \<inter> T)"
  by (simp add: closedin_subtopology closed_closedin Int_ac)

lemma closedin_closed_Int: "closed S ==> closedin (subtopology euclidean U) (U \<inter> S)"
  by (metis closedin_closed)

lemma closed_closedin_trans: "closed S \<Longrightarrow> closed T \<Longrightarrow> T \<subseteq> S \<Longrightarrow> closedin (subtopology euclidean S) T"
  apply (subgoal_tac "S \<inter> T = T" )
  apply auto
  apply (frule closedin_closed_Int[of T S])
  by simp

lemma closed_subset: "S \<subseteq> T \<Longrightarrow> closed S \<Longrightarrow> closedin (subtopology euclidean T) S"
  by (auto simp add: closedin_closed)

lemma openin_euclidean_subtopology_iff:
  fixes S U :: "'a::metric_space set"
  shows "openin (subtopology euclidean U) S
  \<longleftrightarrow> S \<subseteq> U \<and> (\<forall>x\<in>S. \<exists>e>0. \<forall>x'\<in>U. dist x' x < e \<longrightarrow> x'\<in> S)" (is "?lhs \<longleftrightarrow> ?rhs")
proof
  assume ?lhs thus ?rhs unfolding openin_open open_dist by blast
next
  def T \<equiv> "{x. \<exists>a\<in>S. \<exists>d>0. (\<forall>y\<in>U. dist y a < d \<longrightarrow> y \<in> S) \<and> dist x a < d}"
  have 1: "\<forall>x\<in>T. \<exists>e>0. \<forall>y. dist y x < e \<longrightarrow> y \<in> T"
    unfolding T_def
    apply clarsimp
    apply (rule_tac x="d - dist x a" in exI)
    apply (clarsimp simp add: less_diff_eq)
    apply (erule rev_bexI)
    apply (rule_tac x=d in exI, clarify)
    apply (erule le_less_trans [OF dist_triangle])
    done
  assume ?rhs hence 2: "S = U \<inter> T"
    unfolding T_def
    apply auto
    apply (drule (1) bspec, erule rev_bexI)
    apply auto
    done
  from 1 2 show ?lhs
    unfolding openin_open open_dist by fast
qed

text {* These "transitivity" results are handy too *}

lemma openin_trans[trans]: "openin (subtopology euclidean T) S \<Longrightarrow> openin (subtopology euclidean U) T
  \<Longrightarrow> openin (subtopology euclidean U) S"
  unfolding open_openin openin_open by blast

lemma openin_open_trans: "openin (subtopology euclidean T) S \<Longrightarrow> open T \<Longrightarrow> open S"
  by (auto simp add: openin_open intro: openin_trans)

lemma closedin_trans[trans]:
 "closedin (subtopology euclidean T) S \<Longrightarrow>
           closedin (subtopology euclidean U) T
           ==> closedin (subtopology euclidean U) S"
  by (auto simp add: closedin_closed closed_closedin closed_Inter Int_assoc)

lemma closedin_closed_trans: "closedin (subtopology euclidean T) S \<Longrightarrow> closed T \<Longrightarrow> closed S"
  by (auto simp add: closedin_closed intro: closedin_trans)


subsection {* Open and closed balls *}

definition
  ball :: "'a::metric_space \<Rightarrow> real \<Rightarrow> 'a set" where
  "ball x e = {y. dist x y < e}"

definition
  cball :: "'a::metric_space \<Rightarrow> real \<Rightarrow> 'a set" where
  "cball x e = {y. dist x y \<le> e}"

lemma mem_ball [simp]: "y \<in> ball x e \<longleftrightarrow> dist x y < e"
  by (simp add: ball_def)

lemma mem_cball [simp]: "y \<in> cball x e \<longleftrightarrow> dist x y \<le> e"
  by (simp add: cball_def)

lemma mem_ball_0:
  fixes x :: "'a::real_normed_vector"
  shows "x \<in> ball 0 e \<longleftrightarrow> norm x < e"
  by (simp add: dist_norm)

lemma mem_cball_0:
  fixes x :: "'a::real_normed_vector"
  shows "x \<in> cball 0 e \<longleftrightarrow> norm x \<le> e"
  by (simp add: dist_norm)

lemma centre_in_ball: "x \<in> ball x e \<longleftrightarrow> 0 < e"
  by simp

lemma centre_in_cball: "x \<in> cball x e \<longleftrightarrow> 0 \<le> e"
  by simp

lemma ball_subset_cball[simp,intro]: "ball x e \<subseteq> cball x e" by (simp add: subset_eq)
lemma subset_ball[intro]: "d <= e ==> ball x d \<subseteq> ball x e" by (simp add: subset_eq)
lemma subset_cball[intro]: "d <= e ==> cball x d \<subseteq> cball x e" by (simp add: subset_eq)
lemma ball_max_Un: "ball a (max r s) = ball a r \<union> ball a s"
  by (simp add: set_eq_iff) arith

lemma ball_min_Int: "ball a (min r s) = ball a r \<inter> ball a s"
  by (simp add: set_eq_iff)

lemma diff_less_iff: "(a::real) - b > 0 \<longleftrightarrow> a > b"
  "(a::real) - b < 0 \<longleftrightarrow> a < b"
  "a - b < c \<longleftrightarrow> a < c +b" "a - b > c \<longleftrightarrow> a > c +b" by arith+
lemma diff_le_iff: "(a::real) - b \<ge> 0 \<longleftrightarrow> a \<ge> b" "(a::real) - b \<le> 0 \<longleftrightarrow> a \<le> b"
  "a - b \<le> c \<longleftrightarrow> a \<le> c +b" "a - b \<ge> c \<longleftrightarrow> a \<ge> c +b"  by arith+

lemma open_ball[intro, simp]: "open (ball x e)"
  unfolding open_dist ball_def mem_Collect_eq Ball_def
  unfolding dist_commute
  apply clarify
  apply (rule_tac x="e - dist xa x" in exI)
  using dist_triangle_alt[where z=x]
  apply (clarsimp simp add: diff_less_iff)
  apply atomize
  apply (erule_tac x="y" in allE)
  apply (erule_tac x="xa" in allE)
  by arith

lemma open_contains_ball: "open S \<longleftrightarrow> (\<forall>x\<in>S. \<exists>e>0. ball x e \<subseteq> S)"
  unfolding open_dist subset_eq mem_ball Ball_def dist_commute ..

lemma openE[elim?]:
  assumes "open S" "x\<in>S" 
  obtains e where "e>0" "ball x e \<subseteq> S"
  using assms unfolding open_contains_ball by auto

lemma open_contains_ball_eq: "open S \<Longrightarrow> \<forall>x. x\<in>S \<longleftrightarrow> (\<exists>e>0. ball x e \<subseteq> S)"
  by (metis open_contains_ball subset_eq centre_in_ball)

lemma ball_eq_empty[simp]: "ball x e = {} \<longleftrightarrow> e \<le> 0"
  unfolding mem_ball set_eq_iff
  apply (simp add: not_less)
  by (metis zero_le_dist order_trans dist_self)

lemma ball_empty[intro]: "e \<le> 0 ==> ball x e = {}" by simp

lemma euclidean_dist_l2:
  fixes x y :: "'a :: euclidean_space"
  shows "dist x y = setL2 (\<lambda>i. dist (x \<bullet> i) (y \<bullet> i)) Basis"
  unfolding dist_norm norm_eq_sqrt_inner setL2_def
  by (subst euclidean_inner) (simp add: power2_eq_square inner_diff_left)

definition "box a b = {x. \<forall>i\<in>Basis. a \<bullet> i < x \<bullet> i \<and> x \<bullet> i < b \<bullet> i}"

lemma rational_boxes:
  fixes x :: "'a\<Colon>euclidean_space"
  assumes "0 < e"
  shows "\<exists>a b. (\<forall>i\<in>Basis. a \<bullet> i \<in> \<rat> \<and> b \<bullet> i \<in> \<rat> ) \<and> x \<in> box a b \<and> box a b \<subseteq> ball x e"
proof -
  def e' \<equiv> "e / (2 * sqrt (real (DIM ('a))))"
  then have e: "0 < e'" using assms by (auto intro!: divide_pos_pos simp: DIM_positive)
  have "\<forall>i. \<exists>y. y \<in> \<rat> \<and> y < x \<bullet> i \<and> x \<bullet> i - y < e'" (is "\<forall>i. ?th i")
  proof
    fix i from Rats_dense_in_real[of "x \<bullet> i - e'" "x \<bullet> i"] e show "?th i" by auto
  qed
  from choice[OF this] guess a .. note a = this
  have "\<forall>i. \<exists>y. y \<in> \<rat> \<and> x \<bullet> i < y \<and> y - x \<bullet> i < e'" (is "\<forall>i. ?th i")
  proof
    fix i from Rats_dense_in_real[of "x \<bullet> i" "x \<bullet> i + e'"] e show "?th i" by auto
  qed
  from choice[OF this] guess b .. note b = this
  let ?a = "\<Sum>i\<in>Basis. a i *\<^sub>R i" and ?b = "\<Sum>i\<in>Basis. b i *\<^sub>R i"
  show ?thesis
  proof (rule exI[of _ ?a], rule exI[of _ ?b], safe)
    fix y :: 'a assume *: "y \<in> box ?a ?b"
    have "dist x y = sqrt (\<Sum>i\<in>Basis. (dist (x \<bullet> i) (y \<bullet> i))\<twosuperior>)"
      unfolding setL2_def[symmetric] by (rule euclidean_dist_l2)
    also have "\<dots> < sqrt (\<Sum>(i::'a)\<in>Basis. e^2 / real (DIM('a)))"
    proof (rule real_sqrt_less_mono, rule setsum_strict_mono)
      fix i :: "'a" assume i: "i \<in> Basis"
      have "a i < y\<bullet>i \<and> y\<bullet>i < b i" using * i by (auto simp: box_def)
      moreover have "a i < x\<bullet>i" "x\<bullet>i - a i < e'" using a by auto
      moreover have "x\<bullet>i < b i" "b i - x\<bullet>i < e'" using b by auto
      ultimately have "\<bar>x\<bullet>i - y\<bullet>i\<bar> < 2 * e'" by auto
      then have "dist (x \<bullet> i) (y \<bullet> i) < e/sqrt (real (DIM('a)))"
        unfolding e'_def by (auto simp: dist_real_def)
      then have "(dist (x \<bullet> i) (y \<bullet> i))\<twosuperior> < (e/sqrt (real (DIM('a))))\<twosuperior>"
        by (rule power_strict_mono) auto
      then show "(dist (x \<bullet> i) (y \<bullet> i))\<twosuperior> < e\<twosuperior> / real DIM('a)"
        by (simp add: power_divide)
    qed auto
    also have "\<dots> = e" using `0 < e` by (simp add: real_eq_of_nat)
    finally show "y \<in> ball x e" by (auto simp: ball_def)
  qed (insert a b, auto simp: box_def)
qed
 
lemma open_UNION_box:
  fixes M :: "'a\<Colon>euclidean_space set"
  assumes "open M" 
  defines "a' \<equiv> \<lambda>f :: 'a \<Rightarrow> real \<times> real. (\<Sum>(i::'a)\<in>Basis. fst (f i) *\<^sub>R i)"
  defines "b' \<equiv> \<lambda>f :: 'a \<Rightarrow> real \<times> real. (\<Sum>(i::'a)\<in>Basis. snd (f i) *\<^sub>R i)"
  defines "I \<equiv> {f\<in>Basis \<rightarrow>\<^isub>E \<rat> \<times> \<rat>. box (a' f) (b' f) \<subseteq> M}"
  shows "M = (\<Union>f\<in>I. box (a' f) (b' f))"
proof safe
  fix x assume "x \<in> M"
  obtain e where e: "e > 0" "ball x e \<subseteq> M"
    using openE[OF `open M` `x \<in> M`] by auto
  moreover then obtain a b where ab: "x \<in> box a b"
    "\<forall>i \<in> Basis. a \<bullet> i \<in> \<rat>" "\<forall>i\<in>Basis. b \<bullet> i \<in> \<rat>" "box a b \<subseteq> ball x e"
    using rational_boxes[OF e(1)] by metis
  ultimately show "x \<in> (\<Union>f\<in>I. box (a' f) (b' f))"
     by (intro UN_I[of "\<lambda>i\<in>Basis. (a \<bullet> i, b \<bullet> i)"])
        (auto simp: euclidean_representation I_def a'_def b'_def)
qed (auto simp: I_def)

subsection{* Connectedness *}

definition "connected S \<longleftrightarrow>
  ~(\<exists>e1 e2. open e1 \<and> open e2 \<and> S \<subseteq> (e1 \<union> e2) \<and> (e1 \<inter> e2 \<inter> S = {})
  \<and> ~(e1 \<inter> S = {}) \<and> ~(e2 \<inter> S = {}))"

lemma connected_local:
 "connected S \<longleftrightarrow> ~(\<exists>e1 e2.
                 openin (subtopology euclidean S) e1 \<and>
                 openin (subtopology euclidean S) e2 \<and>
                 S \<subseteq> e1 \<union> e2 \<and>
                 e1 \<inter> e2 = {} \<and>
                 ~(e1 = {}) \<and>
                 ~(e2 = {}))"
unfolding connected_def openin_open by (safe, blast+)

lemma exists_diff:
  fixes P :: "'a set \<Rightarrow> bool"
  shows "(\<exists>S. P(- S)) \<longleftrightarrow> (\<exists>S. P S)" (is "?lhs \<longleftrightarrow> ?rhs")
proof-
  {assume "?lhs" hence ?rhs by blast }
  moreover
  {fix S assume H: "P S"
    have "S = - (- S)" by auto
    with H have "P (- (- S))" by metis }
  ultimately show ?thesis by metis
qed

lemma connected_clopen: "connected S \<longleftrightarrow>
        (\<forall>T. openin (subtopology euclidean S) T \<and>
            closedin (subtopology euclidean S) T \<longrightarrow> T = {} \<or> T = S)" (is "?lhs \<longleftrightarrow> ?rhs")
proof-
  have " \<not> connected S \<longleftrightarrow> (\<exists>e1 e2. open e1 \<and> open (- e2) \<and> S \<subseteq> e1 \<union> (- e2) \<and> e1 \<inter> (- e2) \<inter> S = {} \<and> e1 \<inter> S \<noteq> {} \<and> (- e2) \<inter> S \<noteq> {})"
    unfolding connected_def openin_open closedin_closed
    apply (subst exists_diff) by blast
  hence th0: "connected S \<longleftrightarrow> \<not> (\<exists>e2 e1. closed e2 \<and> open e1 \<and> S \<subseteq> e1 \<union> (- e2) \<and> e1 \<inter> (- e2) \<inter> S = {} \<and> e1 \<inter> S \<noteq> {} \<and> (- e2) \<inter> S \<noteq> {})"
    (is " _ \<longleftrightarrow> \<not> (\<exists>e2 e1. ?P e2 e1)") apply (simp add: closed_def) by metis

  have th1: "?rhs \<longleftrightarrow> \<not> (\<exists>t' t. closed t'\<and>t = S\<inter>t' \<and> t\<noteq>{} \<and> t\<noteq>S \<and> (\<exists>t'. open t' \<and> t = S \<inter> t'))"
    (is "_ \<longleftrightarrow> \<not> (\<exists>t' t. ?Q t' t)")
    unfolding connected_def openin_open closedin_closed by auto
  {fix e2
    {fix e1 have "?P e2 e1 \<longleftrightarrow> (\<exists>t.  closed e2 \<and> t = S\<inter>e2 \<and> open e1 \<and> t = S\<inter>e1 \<and> t\<noteq>{} \<and> t\<noteq>S)"
        by auto}
    then have "(\<exists>e1. ?P e2 e1) \<longleftrightarrow> (\<exists>t. ?Q e2 t)" by metis}
  then have "\<forall>e2. (\<exists>e1. ?P e2 e1) \<longleftrightarrow> (\<exists>t. ?Q e2 t)" by blast
  then show ?thesis unfolding th0 th1 by simp
qed

lemma connected_empty[simp, intro]: "connected {}"
  by (simp add: connected_def)


subsection{* Limit points *}

definition (in topological_space)
  islimpt:: "'a \<Rightarrow> 'a set \<Rightarrow> bool" (infixr "islimpt" 60) where
  "x islimpt S \<longleftrightarrow> (\<forall>T. x\<in>T \<longrightarrow> open T \<longrightarrow> (\<exists>y\<in>S. y\<in>T \<and> y\<noteq>x))"

lemma islimptI:
  assumes "\<And>T. x \<in> T \<Longrightarrow> open T \<Longrightarrow> \<exists>y\<in>S. y \<in> T \<and> y \<noteq> x"
  shows "x islimpt S"
  using assms unfolding islimpt_def by auto

lemma islimptE:
  assumes "x islimpt S" and "x \<in> T" and "open T"
  obtains y where "y \<in> S" and "y \<in> T" and "y \<noteq> x"
  using assms unfolding islimpt_def by auto

lemma islimpt_iff_eventually: "x islimpt S \<longleftrightarrow> \<not> eventually (\<lambda>y. y \<notin> S) (at x)"
  unfolding islimpt_def eventually_at_topological by auto

lemma islimpt_subset: "\<lbrakk>x islimpt S; S \<subseteq> T\<rbrakk> \<Longrightarrow> x islimpt T"
  unfolding islimpt_def by fast

lemma islimpt_approachable:
  fixes x :: "'a::metric_space"
  shows "x islimpt S \<longleftrightarrow> (\<forall>e>0. \<exists>x'\<in>S. x' \<noteq> x \<and> dist x' x < e)"
  unfolding islimpt_iff_eventually eventually_at by fast

lemma islimpt_approachable_le:
  fixes x :: "'a::metric_space"
  shows "x islimpt S \<longleftrightarrow> (\<forall>e>0. \<exists>x'\<in> S. x' \<noteq> x \<and> dist x' x <= e)"
  unfolding islimpt_approachable
  using approachable_lt_le [where f="\<lambda>y. dist y x" and P="\<lambda>y. y \<notin> S \<or> y = x",
    THEN arg_cong [where f=Not]]
  by (simp add: Bex_def conj_commute conj_left_commute)

lemma islimpt_UNIV_iff: "x islimpt UNIV \<longleftrightarrow> \<not> open {x}"
  unfolding islimpt_def by (safe, fast, case_tac "T = {x}", fast, fast)

text {* A perfect space has no isolated points. *}

lemma islimpt_UNIV [simp, intro]: "(x::'a::perfect_space) islimpt UNIV"
  unfolding islimpt_UNIV_iff by (rule not_open_singleton)

lemma perfect_choose_dist:
  fixes x :: "'a::{perfect_space, metric_space}"
  shows "0 < r \<Longrightarrow> \<exists>a. a \<noteq> x \<and> dist a x < r"
using islimpt_UNIV [of x]
by (simp add: islimpt_approachable)

lemma closed_limpt: "closed S \<longleftrightarrow> (\<forall>x. x islimpt S \<longrightarrow> x \<in> S)"
  unfolding closed_def
  apply (subst open_subopen)
  apply (simp add: islimpt_def subset_eq)
  by (metis ComplE ComplI)

lemma islimpt_EMPTY[simp]: "\<not> x islimpt {}"
  unfolding islimpt_def by auto

lemma finite_set_avoid:
  fixes a :: "'a::metric_space"
  assumes fS: "finite S" shows  "\<exists>d>0. \<forall>x\<in>S. x \<noteq> a \<longrightarrow> d <= dist a x"
proof(induct rule: finite_induct[OF fS])
  case 1 thus ?case by (auto intro: zero_less_one)
next
  case (2 x F)
  from 2 obtain d where d: "d >0" "\<forall>x\<in>F. x\<noteq>a \<longrightarrow> d \<le> dist a x" by blast
  {assume "x = a" hence ?case using d by auto  }
  moreover
  {assume xa: "x\<noteq>a"
    let ?d = "min d (dist a x)"
    have dp: "?d > 0" using xa d(1) using dist_nz by auto
    from d have d': "\<forall>x\<in>F. x\<noteq>a \<longrightarrow> ?d \<le> dist a x" by auto
    with dp xa have ?case by(auto intro!: exI[where x="?d"]) }
  ultimately show ?case by blast
qed

lemma islimpt_Un: "x islimpt (S \<union> T) \<longleftrightarrow> x islimpt S \<or> x islimpt T"
  by (simp add: islimpt_iff_eventually eventually_conj_iff)

lemma discrete_imp_closed:
  fixes S :: "'a::metric_space set"
  assumes e: "0 < e" and d: "\<forall>x \<in> S. \<forall>y \<in> S. dist y x < e \<longrightarrow> y = x"
  shows "closed S"
proof-
  {fix x assume C: "\<forall>e>0. \<exists>x'\<in>S. x' \<noteq> x \<and> dist x' x < e"
    from e have e2: "e/2 > 0" by arith
    from C[rule_format, OF e2] obtain y where y: "y \<in> S" "y\<noteq>x" "dist y x < e/2" by blast
    let ?m = "min (e/2) (dist x y) "
    from e2 y(2) have mp: "?m > 0" by (simp add: dist_nz[THEN sym])
    from C[rule_format, OF mp] obtain z where z: "z \<in> S" "z\<noteq>x" "dist z x < ?m" by blast
    have th: "dist z y < e" using z y
      by (intro dist_triangle_lt [where z=x], simp)
    from d[rule_format, OF y(1) z(1) th] y z
    have False by (auto simp add: dist_commute)}
  then show ?thesis by (metis islimpt_approachable closed_limpt [where 'a='a])
qed


subsection {* Interior of a Set *}

definition "interior S = \<Union>{T. open T \<and> T \<subseteq> S}"

lemma interiorI [intro?]:
  assumes "open T" and "x \<in> T" and "T \<subseteq> S"
  shows "x \<in> interior S"
  using assms unfolding interior_def by fast

lemma interiorE [elim?]:
  assumes "x \<in> interior S"
  obtains T where "open T" and "x \<in> T" and "T \<subseteq> S"
  using assms unfolding interior_def by fast

lemma open_interior [simp, intro]: "open (interior S)"
  by (simp add: interior_def open_Union)

lemma interior_subset: "interior S \<subseteq> S"
  by (auto simp add: interior_def)

lemma interior_maximal: "T \<subseteq> S \<Longrightarrow> open T \<Longrightarrow> T \<subseteq> interior S"
  by (auto simp add: interior_def)

lemma interior_open: "open S \<Longrightarrow> interior S = S"
  by (intro equalityI interior_subset interior_maximal subset_refl)

lemma interior_eq: "interior S = S \<longleftrightarrow> open S"
  by (metis open_interior interior_open)

lemma open_subset_interior: "open S \<Longrightarrow> S \<subseteq> interior T \<longleftrightarrow> S \<subseteq> T"
  by (metis interior_maximal interior_subset subset_trans)

lemma interior_empty [simp]: "interior {} = {}"
  using open_empty by (rule interior_open)

lemma interior_UNIV [simp]: "interior UNIV = UNIV"
  using open_UNIV by (rule interior_open)

lemma interior_interior [simp]: "interior (interior S) = interior S"
  using open_interior by (rule interior_open)

lemma interior_mono: "S \<subseteq> T \<Longrightarrow> interior S \<subseteq> interior T"
  by (auto simp add: interior_def)

lemma interior_unique:
  assumes "T \<subseteq> S" and "open T"
  assumes "\<And>T'. T' \<subseteq> S \<Longrightarrow> open T' \<Longrightarrow> T' \<subseteq> T"
  shows "interior S = T"
  by (intro equalityI assms interior_subset open_interior interior_maximal)

lemma interior_inter [simp]: "interior (S \<inter> T) = interior S \<inter> interior T"
  by (intro equalityI Int_mono Int_greatest interior_mono Int_lower1
    Int_lower2 interior_maximal interior_subset open_Int open_interior)

lemma mem_interior: "x \<in> interior S \<longleftrightarrow> (\<exists>e>0. ball x e \<subseteq> S)"
  using open_contains_ball_eq [where S="interior S"]
  by (simp add: open_subset_interior)

lemma interior_limit_point [intro]:
  fixes x :: "'a::perfect_space"
  assumes x: "x \<in> interior S" shows "x islimpt S"
  using x islimpt_UNIV [of x]
  unfolding interior_def islimpt_def
  apply (clarsimp, rename_tac T T')
  apply (drule_tac x="T \<inter> T'" in spec)
  apply (auto simp add: open_Int)
  done

lemma interior_closed_Un_empty_interior:
  assumes cS: "closed S" and iT: "interior T = {}"
  shows "interior (S \<union> T) = interior S"
proof
  show "interior S \<subseteq> interior (S \<union> T)"
    by (rule interior_mono, rule Un_upper1)
next
  show "interior (S \<union> T) \<subseteq> interior S"
  proof
    fix x assume "x \<in> interior (S \<union> T)"
    then obtain R where "open R" "x \<in> R" "R \<subseteq> S \<union> T" ..
    show "x \<in> interior S"
    proof (rule ccontr)
      assume "x \<notin> interior S"
      with `x \<in> R` `open R` obtain y where "y \<in> R - S"
        unfolding interior_def by fast
      from `open R` `closed S` have "open (R - S)" by (rule open_Diff)
      from `R \<subseteq> S \<union> T` have "R - S \<subseteq> T" by fast
      from `y \<in> R - S` `open (R - S)` `R - S \<subseteq> T` `interior T = {}`
      show "False" unfolding interior_def by fast
    qed
  qed
qed

lemma interior_Times: "interior (A \<times> B) = interior A \<times> interior B"
proof (rule interior_unique)
  show "interior A \<times> interior B \<subseteq> A \<times> B"
    by (intro Sigma_mono interior_subset)
  show "open (interior A \<times> interior B)"
    by (intro open_Times open_interior)
  fix T assume "T \<subseteq> A \<times> B" and "open T" thus "T \<subseteq> interior A \<times> interior B"
  proof (safe)
    fix x y assume "(x, y) \<in> T"
    then obtain C D where "open C" "open D" "C \<times> D \<subseteq> T" "x \<in> C" "y \<in> D"
      using `open T` unfolding open_prod_def by fast
    hence "open C" "open D" "C \<subseteq> A" "D \<subseteq> B" "x \<in> C" "y \<in> D"
      using `T \<subseteq> A \<times> B` by auto
    thus "x \<in> interior A" and "y \<in> interior B"
      by (auto intro: interiorI)
  qed
qed


subsection {* Closure of a Set *}

definition "closure S = S \<union> {x | x. x islimpt S}"

lemma interior_closure: "interior S = - (closure (- S))"
  unfolding interior_def closure_def islimpt_def by auto

lemma closure_interior: "closure S = - interior (- S)"
  unfolding interior_closure by simp

lemma closed_closure[simp, intro]: "closed (closure S)"
  unfolding closure_interior by (simp add: closed_Compl)

lemma closure_subset: "S \<subseteq> closure S"
  unfolding closure_def by simp

lemma closure_hull: "closure S = closed hull S"
  unfolding hull_def closure_interior interior_def by auto

lemma closure_eq: "closure S = S \<longleftrightarrow> closed S"
  unfolding closure_hull using closed_Inter by (rule hull_eq)

lemma closure_closed [simp]: "closed S \<Longrightarrow> closure S = S"
  unfolding closure_eq .

lemma closure_closure [simp]: "closure (closure S) = closure S"
  unfolding closure_hull by (rule hull_hull)

lemma closure_mono: "S \<subseteq> T \<Longrightarrow> closure S \<subseteq> closure T"
  unfolding closure_hull by (rule hull_mono)

lemma closure_minimal: "S \<subseteq> T \<Longrightarrow> closed T \<Longrightarrow> closure S \<subseteq> T"
  unfolding closure_hull by (rule hull_minimal)

lemma closure_unique:
  assumes "S \<subseteq> T" and "closed T"
  assumes "\<And>T'. S \<subseteq> T' \<Longrightarrow> closed T' \<Longrightarrow> T \<subseteq> T'"
  shows "closure S = T"
  using assms unfolding closure_hull by (rule hull_unique)

lemma closure_empty [simp]: "closure {} = {}"
  using closed_empty by (rule closure_closed)

lemma closure_UNIV [simp]: "closure UNIV = UNIV"
  using closed_UNIV by (rule closure_closed)

lemma closure_union [simp]: "closure (S \<union> T) = closure S \<union> closure T"
  unfolding closure_interior by simp

lemma closure_eq_empty: "closure S = {} \<longleftrightarrow> S = {}"
  using closure_empty closure_subset[of S]
  by blast

lemma closure_subset_eq: "closure S \<subseteq> S \<longleftrightarrow> closed S"
  using closure_eq[of S] closure_subset[of S]
  by simp

lemma open_inter_closure_eq_empty:
  "open S \<Longrightarrow> (S \<inter> closure T) = {} \<longleftrightarrow> S \<inter> T = {}"
  using open_subset_interior[of S "- T"]
  using interior_subset[of "- T"]
  unfolding closure_interior
  by auto

lemma open_inter_closure_subset:
  "open S \<Longrightarrow> (S \<inter> (closure T)) \<subseteq> closure(S \<inter> T)"
proof
  fix x
  assume as: "open S" "x \<in> S \<inter> closure T"
  { assume *:"x islimpt T"
    have "x islimpt (S \<inter> T)"
    proof (rule islimptI)
      fix A
      assume "x \<in> A" "open A"
      with as have "x \<in> A \<inter> S" "open (A \<inter> S)"
        by (simp_all add: open_Int)
      with * obtain y where "y \<in> T" "y \<in> A \<inter> S" "y \<noteq> x"
        by (rule islimptE)
      hence "y \<in> S \<inter> T" "y \<in> A \<and> y \<noteq> x"
        by simp_all
      thus "\<exists>y\<in>(S \<inter> T). y \<in> A \<and> y \<noteq> x" ..
    qed
  }
  then show "x \<in> closure (S \<inter> T)" using as
    unfolding closure_def
    by blast
qed

lemma closure_complement: "closure (- S) = - interior S"
  unfolding closure_interior by simp

lemma interior_complement: "interior (- S) = - closure S"
  unfolding closure_interior by simp

lemma closure_Times: "closure (A \<times> B) = closure A \<times> closure B"
proof (rule closure_unique)
  show "A \<times> B \<subseteq> closure A \<times> closure B"
    by (intro Sigma_mono closure_subset)
  show "closed (closure A \<times> closure B)"
    by (intro closed_Times closed_closure)
  fix T assume "A \<times> B \<subseteq> T" and "closed T" thus "closure A \<times> closure B \<subseteq> T"
    apply (simp add: closed_def open_prod_def, clarify)
    apply (rule ccontr)
    apply (drule_tac x="(a, b)" in bspec, simp, clarify, rename_tac C D)
    apply (simp add: closure_interior interior_def)
    apply (drule_tac x=C in spec)
    apply (drule_tac x=D in spec)
    apply auto
    done
qed


subsection {* Frontier (aka boundary) *}

definition "frontier S = closure S - interior S"

lemma frontier_closed: "closed(frontier S)"
  by (simp add: frontier_def closed_Diff)

lemma frontier_closures: "frontier S = (closure S) \<inter> (closure(- S))"
  by (auto simp add: frontier_def interior_closure)

lemma frontier_straddle:
  fixes a :: "'a::metric_space"
  shows "a \<in> frontier S \<longleftrightarrow> (\<forall>e>0. (\<exists>x\<in>S. dist a x < e) \<and> (\<exists>x. x \<notin> S \<and> dist a x < e))"
  unfolding frontier_def closure_interior
  by (auto simp add: mem_interior subset_eq ball_def)

lemma frontier_subset_closed: "closed S \<Longrightarrow> frontier S \<subseteq> S"
  by (metis frontier_def closure_closed Diff_subset)

lemma frontier_empty[simp]: "frontier {} = {}"
  by (simp add: frontier_def)

lemma frontier_subset_eq: "frontier S \<subseteq> S \<longleftrightarrow> closed S"
proof-
  { assume "frontier S \<subseteq> S"
    hence "closure S \<subseteq> S" using interior_subset unfolding frontier_def by auto
    hence "closed S" using closure_subset_eq by auto
  }
  thus ?thesis using frontier_subset_closed[of S] ..
qed

lemma frontier_complement: "frontier(- S) = frontier S"
  by (auto simp add: frontier_def closure_complement interior_complement)

lemma frontier_disjoint_eq: "frontier S \<inter> S = {} \<longleftrightarrow> open S"
  using frontier_complement frontier_subset_eq[of "- S"]
  unfolding open_closed by auto

subsection {* Filters and the ``eventually true'' quantifier *}

definition
  indirection :: "'a::real_normed_vector \<Rightarrow> 'a \<Rightarrow> 'a filter"
    (infixr "indirection" 70) where
  "a indirection v = (at a) within {b. \<exists>c\<ge>0. b - a = scaleR c v}"

text {* Identify Trivial limits, where we can't approach arbitrarily closely. *}

lemma trivial_limit_within:
  shows "trivial_limit (at a within S) \<longleftrightarrow> \<not> a islimpt S"
proof
  assume "trivial_limit (at a within S)"
  thus "\<not> a islimpt S"
    unfolding trivial_limit_def
    unfolding eventually_within eventually_at_topological
    unfolding islimpt_def
    apply (clarsimp simp add: set_eq_iff)
    apply (rename_tac T, rule_tac x=T in exI)
    apply (clarsimp, drule_tac x=y in bspec, simp_all)
    done
next
  assume "\<not> a islimpt S"
  thus "trivial_limit (at a within S)"
    unfolding trivial_limit_def
    unfolding eventually_within eventually_at_topological
    unfolding islimpt_def
    apply clarsimp
    apply (rule_tac x=T in exI)
    apply auto
    done
qed

lemma trivial_limit_at_iff: "trivial_limit (at a) \<longleftrightarrow> \<not> a islimpt UNIV"
  using trivial_limit_within [of a UNIV] by simp

lemma trivial_limit_at:
  fixes a :: "'a::perfect_space"
  shows "\<not> trivial_limit (at a)"
  by (rule at_neq_bot)

lemma trivial_limit_at_infinity:
  "\<not> trivial_limit (at_infinity :: ('a::{real_normed_vector,perfect_space}) filter)"
  unfolding trivial_limit_def eventually_at_infinity
  apply clarsimp
  apply (subgoal_tac "\<exists>x::'a. x \<noteq> 0", clarify)
   apply (rule_tac x="scaleR (b / norm x) x" in exI, simp)
  apply (cut_tac islimpt_UNIV [of "0::'a", unfolded islimpt_def])
  apply (drule_tac x=UNIV in spec, simp)
  done

text {* Some property holds "sufficiently close" to the limit point. *}

lemma eventually_at: (* FIXME: this replaces Limits.eventually_at *)
  "eventually P (at a) \<longleftrightarrow> (\<exists>d>0. \<forall>x. 0 < dist x a \<and> dist x a < d \<longrightarrow> P x)"
unfolding eventually_at dist_nz by auto

lemma eventually_within: (* FIXME: this replaces Limits.eventually_within *)
  "eventually P (at a within S) \<longleftrightarrow>
        (\<exists>d>0. \<forall>x\<in>S. 0 < dist x a \<and> dist x a < d \<longrightarrow> P x)"
  by (rule eventually_within_less)

lemma eventually_happens: "eventually P net ==> trivial_limit net \<or> (\<exists>x. P x)"
  unfolding trivial_limit_def
  by (auto elim: eventually_rev_mp)

lemma trivial_limit_eventually: "trivial_limit net \<Longrightarrow> eventually P net"
  by simp

lemma trivial_limit_eq: "trivial_limit net \<longleftrightarrow> (\<forall>P. eventually P net)"
  by (simp add: filter_eq_iff)

text{* Combining theorems for "eventually" *}

lemma eventually_rev_mono:
  "eventually P net \<Longrightarrow> (\<forall>x. P x \<longrightarrow> Q x) \<Longrightarrow> eventually Q net"
using eventually_mono [of P Q] by fast

lemma not_eventually: "(\<forall>x. \<not> P x ) \<Longrightarrow> ~(trivial_limit net) ==> ~(eventually (\<lambda>x. P x) net)"
  by (simp add: eventually_False)


subsection {* Limits *}

text{* Notation Lim to avoid collition with lim defined in analysis *}

definition Lim :: "'a filter \<Rightarrow> ('a \<Rightarrow> 'b::t2_space) \<Rightarrow> 'b"
  where "Lim A f = (THE l. (f ---> l) A)"

lemma Lim:
 "(f ---> l) net \<longleftrightarrow>
        trivial_limit net \<or>
        (\<forall>e>0. eventually (\<lambda>x. dist (f x) l < e) net)"
  unfolding tendsto_iff trivial_limit_eq by auto

text{* Show that they yield usual definitions in the various cases. *}

lemma Lim_within_le: "(f ---> l)(at a within S) \<longleftrightarrow>
           (\<forall>e>0. \<exists>d>0. \<forall>x\<in>S. 0 < dist x a  \<and> dist x a  <= d \<longrightarrow> dist (f x) l < e)"
  by (auto simp add: tendsto_iff eventually_within_le)

lemma Lim_within: "(f ---> l) (at a within S) \<longleftrightarrow>
        (\<forall>e >0. \<exists>d>0. \<forall>x \<in> S. 0 < dist x a  \<and> dist x a  < d  \<longrightarrow> dist (f x) l < e)"
  by (auto simp add: tendsto_iff eventually_within)

lemma Lim_at: "(f ---> l) (at a) \<longleftrightarrow>
        (\<forall>e >0. \<exists>d>0. \<forall>x. 0 < dist x a  \<and> dist x a  < d  \<longrightarrow> dist (f x) l < e)"
  by (auto simp add: tendsto_iff eventually_at)

lemma Lim_at_infinity:
  "(f ---> l) at_infinity \<longleftrightarrow> (\<forall>e>0. \<exists>b. \<forall>x. norm x >= b \<longrightarrow> dist (f x) l < e)"
  by (auto simp add: tendsto_iff eventually_at_infinity)

lemma Lim_eventually: "eventually (\<lambda>x. f x = l) net \<Longrightarrow> (f ---> l) net"
  by (rule topological_tendstoI, auto elim: eventually_rev_mono)

text{* The expected monotonicity property. *}

lemma Lim_within_empty: "(f ---> l) (net within {})"
  unfolding tendsto_def Limits.eventually_within by simp

lemma Lim_within_subset: "(f ---> l) (net within S) \<Longrightarrow> T \<subseteq> S \<Longrightarrow> (f ---> l) (net within T)"
  unfolding tendsto_def Limits.eventually_within
  by (auto elim!: eventually_elim1)

lemma Lim_Un: assumes "(f ---> l) (net within S)" "(f ---> l) (net within T)"
  shows "(f ---> l) (net within (S \<union> T))"
  using assms unfolding tendsto_def Limits.eventually_within
  apply clarify
  apply (drule spec, drule (1) mp, drule (1) mp)
  apply (drule spec, drule (1) mp, drule (1) mp)
  apply (auto elim: eventually_elim2)
  done

lemma Lim_Un_univ:
 "(f ---> l) (net within S) \<Longrightarrow> (f ---> l) (net within T) \<Longrightarrow>  S \<union> T = UNIV
        ==> (f ---> l) net"
  by (metis Lim_Un within_UNIV)

text{* Interrelations between restricted and unrestricted limits. *}

lemma Lim_at_within: "(f ---> l) net ==> (f ---> l)(net within S)"
  (* FIXME: rename *)
  unfolding tendsto_def Limits.eventually_within
  apply (clarify, drule spec, drule (1) mp, drule (1) mp)
  by (auto elim!: eventually_elim1)

lemma eventually_within_interior:
  assumes "x \<in> interior S"
  shows "eventually P (at x within S) \<longleftrightarrow> eventually P (at x)" (is "?lhs = ?rhs")
proof-
  from assms obtain T where T: "open T" "x \<in> T" "T \<subseteq> S" ..
  { assume "?lhs"
    then obtain A where "open A" "x \<in> A" "\<forall>y\<in>A. y \<noteq> x \<longrightarrow> y \<in> S \<longrightarrow> P y"
      unfolding Limits.eventually_within Limits.eventually_at_topological
      by auto
    with T have "open (A \<inter> T)" "x \<in> A \<inter> T" "\<forall>y\<in>(A \<inter> T). y \<noteq> x \<longrightarrow> P y"
      by auto
    then have "?rhs"
      unfolding Limits.eventually_at_topological by auto
  } moreover
  { assume "?rhs" hence "?lhs"
      unfolding Limits.eventually_within
      by (auto elim: eventually_elim1)
  } ultimately
  show "?thesis" ..
qed

lemma at_within_interior:
  "x \<in> interior S \<Longrightarrow> at x within S = at x"
  by (simp add: filter_eq_iff eventually_within_interior)

lemma at_within_open:
  "\<lbrakk>x \<in> S; open S\<rbrakk> \<Longrightarrow> at x within S = at x"
  by (simp only: at_within_interior interior_open)

lemma Lim_within_open:
  fixes f :: "'a::topological_space \<Rightarrow> 'b::topological_space"
  assumes"a \<in> S" "open S"
  shows "(f ---> l)(at a within S) \<longleftrightarrow> (f ---> l)(at a)"
  using assms by (simp only: at_within_open)

lemma Lim_within_LIMSEQ:
  fixes a :: "'a::metric_space"
  assumes "\<forall>S. (\<forall>n. S n \<noteq> a \<and> S n \<in> T) \<and> S ----> a \<longrightarrow> (\<lambda>n. X (S n)) ----> L"
  shows "(X ---> L) (at a within T)"
  using assms unfolding tendsto_def [where l=L]
  by (simp add: sequentially_imp_eventually_within)

lemma Lim_right_bound:
  fixes f :: "real \<Rightarrow> real"
  assumes mono: "\<And>a b. a \<in> I \<Longrightarrow> b \<in> I \<Longrightarrow> x < a \<Longrightarrow> a \<le> b \<Longrightarrow> f a \<le> f b"
  assumes bnd: "\<And>a. a \<in> I \<Longrightarrow> x < a \<Longrightarrow> K \<le> f a"
  shows "(f ---> Inf (f ` ({x<..} \<inter> I))) (at x within ({x<..} \<inter> I))"
proof cases
  assume "{x<..} \<inter> I = {}" then show ?thesis by (simp add: Lim_within_empty)
next
  assume [simp]: "{x<..} \<inter> I \<noteq> {}"
  show ?thesis
  proof (rule Lim_within_LIMSEQ, safe)
    fix S assume S: "\<forall>n. S n \<noteq> x \<and> S n \<in> {x <..} \<inter> I" "S ----> x"
    
    show "(\<lambda>n. f (S n)) ----> Inf (f ` ({x<..} \<inter> I))"
    proof (rule LIMSEQ_I, rule ccontr)
      fix r :: real assume "0 < r"
      with Inf_close[of "f ` ({x<..} \<inter> I)" r]
      obtain y where y: "x < y" "y \<in> I" "f y < Inf (f ` ({x <..} \<inter> I)) + r" by auto
      from `x < y` have "0 < y - x" by auto
      from S(2)[THEN LIMSEQ_D, OF this]
      obtain N where N: "\<And>n. N \<le> n \<Longrightarrow> \<bar>S n - x\<bar> < y - x" by auto
      
      assume "\<not> (\<exists>N. \<forall>n\<ge>N. norm (f (S n) - Inf (f ` ({x<..} \<inter> I))) < r)"
      moreover have "\<And>n. Inf (f ` ({x<..} \<inter> I)) \<le> f (S n)"
        using S bnd by (intro Inf_lower[where z=K]) auto
      ultimately obtain n where n: "N \<le> n" "r + Inf (f ` ({x<..} \<inter> I)) \<le> f (S n)"
        by (auto simp: not_less field_simps)
      with N[OF n(1)] mono[OF _ `y \<in> I`, of "S n"] S(1)[THEN spec, of n] y
      show False by auto
    qed
  qed
qed

text{* Another limit point characterization. *}

lemma islimpt_sequential:
  fixes x :: "'a::first_countable_topology"
  shows "x islimpt S \<longleftrightarrow> (\<exists>f. (\<forall>n::nat. f n \<in> S - {x}) \<and> (f ---> x) sequentially)"
    (is "?lhs = ?rhs")
proof
  assume ?lhs
  from countable_basis_at_decseq[of x] guess A . note A = this
  def f \<equiv> "\<lambda>n. SOME y. y \<in> S \<and> y \<in> A n \<and> x \<noteq> y"
  { fix n
    from `?lhs` have "\<exists>y. y \<in> S \<and> y \<in> A n \<and> x \<noteq> y"
      unfolding islimpt_def using A(1,2)[of n] by auto
    then have "f n \<in> S \<and> f n \<in> A n \<and> x \<noteq> f n"
      unfolding f_def by (rule someI_ex)
    then have "f n \<in> S" "f n \<in> A n" "x \<noteq> f n" by auto }
  then have "\<forall>n. f n \<in> S - {x}" by auto
  moreover have "(\<lambda>n. f n) ----> x"
  proof (rule topological_tendstoI)
    fix S assume "open S" "x \<in> S"
    from A(3)[OF this] `\<And>n. f n \<in> A n`
    show "eventually (\<lambda>x. f x \<in> S) sequentially" by (auto elim!: eventually_elim1)
  qed
  ultimately show ?rhs by fast
next
  assume ?rhs
  then obtain f :: "nat \<Rightarrow> 'a" where f: "\<And>n. f n \<in> S - {x}" and lim: "f ----> x" by auto
  show ?lhs
    unfolding islimpt_def
  proof safe
    fix T assume "open T" "x \<in> T"
    from lim[THEN topological_tendstoD, OF this] f
    show "\<exists>y\<in>S. y \<in> T \<and> y \<noteq> x"
      unfolding eventually_sequentially by auto
  qed
qed

lemma Lim_inv: (* TODO: delete *)
  fixes f :: "'a \<Rightarrow> real" and A :: "'a filter"
  assumes "(f ---> l) A" and "l \<noteq> 0"
  shows "((inverse o f) ---> inverse l) A"
  unfolding o_def using assms by (rule tendsto_inverse)

lemma Lim_null:
  fixes f :: "'a \<Rightarrow> 'b::real_normed_vector"
  shows "(f ---> l) net \<longleftrightarrow> ((\<lambda>x. f(x) - l) ---> 0) net"
  by (simp add: Lim dist_norm)

lemma Lim_null_comparison:
  fixes f :: "'a \<Rightarrow> 'b::real_normed_vector"
  assumes "eventually (\<lambda>x. norm (f x) \<le> g x) net" "(g ---> 0) net"
  shows "(f ---> 0) net"
proof (rule metric_tendsto_imp_tendsto)
  show "(g ---> 0) net" by fact
  show "eventually (\<lambda>x. dist (f x) 0 \<le> dist (g x) 0) net"
    using assms(1) by (rule eventually_elim1, simp add: dist_norm)
qed

lemma Lim_transform_bound:
  fixes f :: "'a \<Rightarrow> 'b::real_normed_vector"
  fixes g :: "'a \<Rightarrow> 'c::real_normed_vector"
  assumes "eventually (\<lambda>n. norm(f n) <= norm(g n)) net"  "(g ---> 0) net"
  shows "(f ---> 0) net"
  using assms(1) tendsto_norm_zero [OF assms(2)]
  by (rule Lim_null_comparison)

text{* Deducing things about the limit from the elements. *}

lemma Lim_in_closed_set:
  assumes "closed S" "eventually (\<lambda>x. f(x) \<in> S) net" "\<not>(trivial_limit net)" "(f ---> l) net"
  shows "l \<in> S"
proof (rule ccontr)
  assume "l \<notin> S"
  with `closed S` have "open (- S)" "l \<in> - S"
    by (simp_all add: open_Compl)
  with assms(4) have "eventually (\<lambda>x. f x \<in> - S) net"
    by (rule topological_tendstoD)
  with assms(2) have "eventually (\<lambda>x. False) net"
    by (rule eventually_elim2) simp
  with assms(3) show "False"
    by (simp add: eventually_False)
qed

text{* Need to prove closed(cball(x,e)) before deducing this as a corollary. *}

lemma Lim_dist_ubound:
  assumes "\<not>(trivial_limit net)" "(f ---> l) net" "eventually (\<lambda>x. dist a (f x) <= e) net"
  shows "dist a l <= e"
proof-
  have "dist a l \<in> {..e}"
  proof (rule Lim_in_closed_set)
    show "closed {..e}" by simp
    show "eventually (\<lambda>x. dist a (f x) \<in> {..e}) net" by (simp add: assms)
    show "\<not> trivial_limit net" by fact
    show "((\<lambda>x. dist a (f x)) ---> dist a l) net" by (intro tendsto_intros assms)
  qed
  thus ?thesis by simp
qed

lemma Lim_norm_ubound:
  fixes f :: "'a \<Rightarrow> 'b::real_normed_vector"
  assumes "\<not>(trivial_limit net)" "(f ---> l) net" "eventually (\<lambda>x. norm(f x) <= e) net"
  shows "norm(l) <= e"
proof-
  have "norm l \<in> {..e}"
  proof (rule Lim_in_closed_set)
    show "closed {..e}" by simp
    show "eventually (\<lambda>x. norm (f x) \<in> {..e}) net" by (simp add: assms)
    show "\<not> trivial_limit net" by fact
    show "((\<lambda>x. norm (f x)) ---> norm l) net" by (intro tendsto_intros assms)
  qed
  thus ?thesis by simp
qed

lemma Lim_norm_lbound:
  fixes f :: "'a \<Rightarrow> 'b::real_normed_vector"
  assumes "\<not> (trivial_limit net)"  "(f ---> l) net"  "eventually (\<lambda>x. e <= norm(f x)) net"
  shows "e \<le> norm l"
proof-
  have "norm l \<in> {e..}"
  proof (rule Lim_in_closed_set)
    show "closed {e..}" by simp
    show "eventually (\<lambda>x. norm (f x) \<in> {e..}) net" by (simp add: assms)
    show "\<not> trivial_limit net" by fact
    show "((\<lambda>x. norm (f x)) ---> norm l) net" by (intro tendsto_intros assms)
  qed
  thus ?thesis by simp
qed

text{* Uniqueness of the limit, when nontrivial. *}

lemma tendsto_Lim:
  fixes f :: "'a \<Rightarrow> 'b::t2_space"
  shows "~(trivial_limit net) \<Longrightarrow> (f ---> l) net ==> Lim net f = l"
  unfolding Lim_def using tendsto_unique[of net f] by auto

text{* Limit under bilinear function *}

lemma Lim_bilinear:
  assumes "(f ---> l) net" and "(g ---> m) net" and "bounded_bilinear h"
  shows "((\<lambda>x. h (f x) (g x)) ---> (h l m)) net"
using `bounded_bilinear h` `(f ---> l) net` `(g ---> m) net`
by (rule bounded_bilinear.tendsto)

text{* These are special for limits out of the same vector space. *}

lemma Lim_within_id: "(id ---> a) (at a within s)"
  unfolding id_def by (rule tendsto_ident_at_within)

lemma Lim_at_id: "(id ---> a) (at a)"
  unfolding id_def by (rule tendsto_ident_at)

lemma Lim_at_zero:
  fixes a :: "'a::real_normed_vector"
  fixes l :: "'b::topological_space"
  shows "(f ---> l) (at a) \<longleftrightarrow> ((\<lambda>x. f(a + x)) ---> l) (at 0)" (is "?lhs = ?rhs")
  using LIM_offset_zero LIM_offset_zero_cancel ..

text{* It's also sometimes useful to extract the limit point from the filter. *}

definition
  netlimit :: "'a::t2_space filter \<Rightarrow> 'a" where
  "netlimit net = (SOME a. ((\<lambda>x. x) ---> a) net)"

lemma netlimit_within:
  assumes "\<not> trivial_limit (at a within S)"
  shows "netlimit (at a within S) = a"
unfolding netlimit_def
apply (rule some_equality)
apply (rule Lim_at_within)
apply (rule tendsto_ident_at)
apply (erule tendsto_unique [OF assms])
apply (rule Lim_at_within)
apply (rule tendsto_ident_at)
done

lemma netlimit_at:
  fixes a :: "'a::{perfect_space,t2_space}"
  shows "netlimit (at a) = a"
  using netlimit_within [of a UNIV] by simp

lemma lim_within_interior:
  "x \<in> interior S \<Longrightarrow> (f ---> l) (at x within S) \<longleftrightarrow> (f ---> l) (at x)"
  by (simp add: at_within_interior)

lemma netlimit_within_interior:
  fixes x :: "'a::{t2_space,perfect_space}"
  assumes "x \<in> interior S"
  shows "netlimit (at x within S) = x"
using assms by (simp add: at_within_interior netlimit_at)

text{* Transformation of limit. *}

lemma Lim_transform:
  fixes f g :: "'a::type \<Rightarrow> 'b::real_normed_vector"
  assumes "((\<lambda>x. f x - g x) ---> 0) net" "(f ---> l) net"
  shows "(g ---> l) net"
  using tendsto_diff [OF assms(2) assms(1)] by simp

lemma Lim_transform_eventually:
  "eventually (\<lambda>x. f x = g x) net \<Longrightarrow> (f ---> l) net \<Longrightarrow> (g ---> l) net"
  apply (rule topological_tendstoI)
  apply (drule (2) topological_tendstoD)
  apply (erule (1) eventually_elim2, simp)
  done

lemma Lim_transform_within:
  assumes "0 < d" and "\<forall>x'\<in>S. 0 < dist x' x \<and> dist x' x < d \<longrightarrow> f x' = g x'"
  and "(f ---> l) (at x within S)"
  shows "(g ---> l) (at x within S)"
proof (rule Lim_transform_eventually)
  show "eventually (\<lambda>x. f x = g x) (at x within S)"
    unfolding eventually_within
    using assms(1,2) by auto
  show "(f ---> l) (at x within S)" by fact
qed

lemma Lim_transform_at:
  assumes "0 < d" and "\<forall>x'. 0 < dist x' x \<and> dist x' x < d \<longrightarrow> f x' = g x'"
  and "(f ---> l) (at x)"
  shows "(g ---> l) (at x)"
proof (rule Lim_transform_eventually)
  show "eventually (\<lambda>x. f x = g x) (at x)"
    unfolding eventually_at
    using assms(1,2) by auto
  show "(f ---> l) (at x)" by fact
qed

text{* Common case assuming being away from some crucial point like 0. *}

lemma Lim_transform_away_within:
  fixes a b :: "'a::t1_space"
  assumes "a \<noteq> b" and "\<forall>x\<in>S. x \<noteq> a \<and> x \<noteq> b \<longrightarrow> f x = g x"
  and "(f ---> l) (at a within S)"
  shows "(g ---> l) (at a within S)"
proof (rule Lim_transform_eventually)
  show "(f ---> l) (at a within S)" by fact
  show "eventually (\<lambda>x. f x = g x) (at a within S)"
    unfolding Limits.eventually_within eventually_at_topological
    by (rule exI [where x="- {b}"], simp add: open_Compl assms)
qed

lemma Lim_transform_away_at:
  fixes a b :: "'a::t1_space"
  assumes ab: "a\<noteq>b" and fg: "\<forall>x. x \<noteq> a \<and> x \<noteq> b \<longrightarrow> f x = g x"
  and fl: "(f ---> l) (at a)"
  shows "(g ---> l) (at a)"
  using Lim_transform_away_within[OF ab, of UNIV f g l] fg fl
  by simp

text{* Alternatively, within an open set. *}

lemma Lim_transform_within_open:
  assumes "open S" and "a \<in> S" and "\<forall>x\<in>S. x \<noteq> a \<longrightarrow> f x = g x"
  and "(f ---> l) (at a)"
  shows "(g ---> l) (at a)"
proof (rule Lim_transform_eventually)
  show "eventually (\<lambda>x. f x = g x) (at a)"
    unfolding eventually_at_topological
    using assms(1,2,3) by auto
  show "(f ---> l) (at a)" by fact
qed

text{* A congruence rule allowing us to transform limits assuming not at point. *}

(* FIXME: Only one congruence rule for tendsto can be used at a time! *)

lemma Lim_cong_within(*[cong add]*):
  assumes "a = b" "x = y" "S = T"
  assumes "\<And>x. x \<noteq> b \<Longrightarrow> x \<in> T \<Longrightarrow> f x = g x"
  shows "(f ---> x) (at a within S) \<longleftrightarrow> (g ---> y) (at b within T)"
  unfolding tendsto_def Limits.eventually_within eventually_at_topological
  using assms by simp

lemma Lim_cong_at(*[cong add]*):
  assumes "a = b" "x = y"
  assumes "\<And>x. x \<noteq> a \<Longrightarrow> f x = g x"
  shows "((\<lambda>x. f x) ---> x) (at a) \<longleftrightarrow> ((g ---> y) (at a))"
  unfolding tendsto_def eventually_at_topological
  using assms by simp

text{* Useful lemmas on closure and set of possible sequential limits.*}

lemma closure_sequential:
  fixes l :: "'a::first_countable_topology"
  shows "l \<in> closure S \<longleftrightarrow> (\<exists>x. (\<forall>n. x n \<in> S) \<and> (x ---> l) sequentially)" (is "?lhs = ?rhs")
proof
  assume "?lhs" moreover
  { assume "l \<in> S"
    hence "?rhs" using tendsto_const[of l sequentially] by auto
  } moreover
  { assume "l islimpt S"
    hence "?rhs" unfolding islimpt_sequential by auto
  } ultimately
  show "?rhs" unfolding closure_def by auto
next
  assume "?rhs"
  thus "?lhs" unfolding closure_def unfolding islimpt_sequential by auto
qed

lemma closed_sequential_limits:
  fixes S :: "'a::first_countable_topology set"
  shows "closed S \<longleftrightarrow> (\<forall>x l. (\<forall>n. x n \<in> S) \<and> (x ---> l) sequentially \<longrightarrow> l \<in> S)"
  unfolding closed_limpt
  using closure_sequential [where 'a='a] closure_closed [where 'a='a] closed_limpt [where 'a='a] islimpt_sequential [where 'a='a] mem_delete [where 'a='a]
  by metis

lemma closure_approachable:
  fixes S :: "'a::metric_space set"
  shows "x \<in> closure S \<longleftrightarrow> (\<forall>e>0. \<exists>y\<in>S. dist y x < e)"
  apply (auto simp add: closure_def islimpt_approachable)
  by (metis dist_self)

lemma closed_approachable:
  fixes S :: "'a::metric_space set"
  shows "closed S ==> (\<forall>e>0. \<exists>y\<in>S. dist y x < e) \<longleftrightarrow> x \<in> S"
  by (metis closure_closed closure_approachable)

subsection {* Infimum Distance *}

definition "infdist x A = (if A = {} then 0 else Inf {dist x a|a. a \<in> A})"

lemma infdist_notempty: "A \<noteq> {} \<Longrightarrow> infdist x A = Inf {dist x a|a. a \<in> A}"
  by (simp add: infdist_def)

lemma infdist_nonneg:
  shows "0 \<le> infdist x A"
  using assms by (auto simp add: infdist_def)

lemma infdist_le:
  assumes "a \<in> A"
  assumes "d = dist x a"
  shows "infdist x A \<le> d"
  using assms by (auto intro!: SupInf.Inf_lower[where z=0] simp add: infdist_def)

lemma infdist_zero[simp]:
  assumes "a \<in> A" shows "infdist a A = 0"
proof -
  from infdist_le[OF assms, of "dist a a"] have "infdist a A \<le> 0" by auto
  with infdist_nonneg[of a A] assms show "infdist a A = 0" by auto
qed

lemma infdist_triangle:
  shows "infdist x A \<le> infdist y A + dist x y"
proof cases
  assume "A = {}" thus ?thesis by (simp add: infdist_def)
next
  assume "A \<noteq> {}" then obtain a where "a \<in> A" by auto
  have "infdist x A \<le> Inf {dist x y + dist y a |a. a \<in> A}"
  proof
    from `A \<noteq> {}` show "{dist x y + dist y a |a. a \<in> A} \<noteq> {}" by simp
    fix d assume "d \<in> {dist x y + dist y a |a. a \<in> A}"
    then obtain a where d: "d = dist x y + dist y a" "a \<in> A" by auto
    show "infdist x A \<le> d"
      unfolding infdist_notempty[OF `A \<noteq> {}`]
    proof (rule Inf_lower2)
      show "dist x a \<in> {dist x a |a. a \<in> A}" using `a \<in> A` by auto
      show "dist x a \<le> d" unfolding d by (rule dist_triangle)
      fix d assume "d \<in> {dist x a |a. a \<in> A}"
      then obtain a where "a \<in> A" "d = dist x a" by auto
      thus "infdist x A \<le> d" by (rule infdist_le)
    qed
  qed
  also have "\<dots> = dist x y + infdist y A"
  proof (rule Inf_eq, safe)
    fix a assume "a \<in> A"
    thus "dist x y + infdist y A \<le> dist x y + dist y a" by (auto intro: infdist_le)
  next
    fix i assume inf: "\<And>d. d \<in> {dist x y + dist y a |a. a \<in> A} \<Longrightarrow> i \<le> d"
    hence "i - dist x y \<le> infdist y A" unfolding infdist_notempty[OF `A \<noteq> {}`] using `a \<in> A`
      by (intro Inf_greatest) (auto simp: field_simps)
    thus "i \<le> dist x y + infdist y A" by simp
  qed
  finally show ?thesis by simp
qed

lemma
  in_closure_iff_infdist_zero:
  assumes "A \<noteq> {}"
  shows "x \<in> closure A \<longleftrightarrow> infdist x A = 0"
proof
  assume "x \<in> closure A"
  show "infdist x A = 0"
  proof (rule ccontr)
    assume "infdist x A \<noteq> 0"
    with infdist_nonneg[of x A] have "infdist x A > 0" by auto
    hence "ball x (infdist x A) \<inter> closure A = {}" apply auto
      by (metis `0 < infdist x A` `x \<in> closure A` closure_approachable dist_commute
        eucl_less_not_refl euclidean_trans(2) infdist_le)
    hence "x \<notin> closure A" by (metis `0 < infdist x A` centre_in_ball disjoint_iff_not_equal)
    thus False using `x \<in> closure A` by simp
  qed
next
  assume x: "infdist x A = 0"
  then obtain a where "a \<in> A" by atomize_elim (metis all_not_in_conv assms)
  show "x \<in> closure A" unfolding closure_approachable
  proof (safe, rule ccontr)
    fix e::real assume "0 < e"
    assume "\<not> (\<exists>y\<in>A. dist y x < e)"
    hence "infdist x A \<ge> e" using `a \<in> A`
      unfolding infdist_def
      by (force simp: dist_commute)
    with x `0 < e` show False by auto
  qed
qed

lemma
  in_closed_iff_infdist_zero:
  assumes "closed A" "A \<noteq> {}"
  shows "x \<in> A \<longleftrightarrow> infdist x A = 0"
proof -
  have "x \<in> closure A \<longleftrightarrow> infdist x A = 0"
    by (rule in_closure_iff_infdist_zero) fact
  with assms show ?thesis by simp
qed

lemma tendsto_infdist [tendsto_intros]:
  assumes f: "(f ---> l) F"
  shows "((\<lambda>x. infdist (f x) A) ---> infdist l A) F"
proof (rule tendstoI)
  fix e ::real assume "0 < e"
  from tendstoD[OF f this]
  show "eventually (\<lambda>x. dist (infdist (f x) A) (infdist l A) < e) F"
  proof (eventually_elim)
    fix x
    from infdist_triangle[of l A "f x"] infdist_triangle[of "f x" A l]
    have "dist (infdist (f x) A) (infdist l A) \<le> dist (f x) l"
      by (simp add: dist_commute dist_real_def)
    also assume "dist (f x) l < e"
    finally show "dist (infdist (f x) A) (infdist l A) < e" .
  qed
qed

text{* Some other lemmas about sequences. *}

lemma sequentially_offset:
  assumes "eventually (\<lambda>i. P i) sequentially"
  shows "eventually (\<lambda>i. P (i + k)) sequentially"
  using assms unfolding eventually_sequentially by (metis trans_le_add1)

lemma seq_offset:
  assumes "(f ---> l) sequentially"
  shows "((\<lambda>i. f (i + k)) ---> l) sequentially"
  using assms by (rule LIMSEQ_ignore_initial_segment) (* FIXME: redundant *)

lemma seq_offset_neg:
  "(f ---> l) sequentially ==> ((\<lambda>i. f(i - k)) ---> l) sequentially"
  apply (rule topological_tendstoI)
  apply (drule (2) topological_tendstoD)
  apply (simp only: eventually_sequentially)
  apply (subgoal_tac "\<And>N k (n::nat). N + k <= n ==> N <= n - k")
  apply metis
  by arith

lemma seq_offset_rev:
  "((\<lambda>i. f(i + k)) ---> l) sequentially ==> (f ---> l) sequentially"
  by (rule LIMSEQ_offset) (* FIXME: redundant *)

lemma seq_harmonic: "((\<lambda>n. inverse (real n)) ---> 0) sequentially"
  using LIMSEQ_inverse_real_of_nat by (rule LIMSEQ_imp_Suc)

subsection {* More properties of closed balls *}

lemma closed_cball: "closed (cball x e)"
unfolding cball_def closed_def
unfolding Collect_neg_eq [symmetric] not_le
apply (clarsimp simp add: open_dist, rename_tac y)
apply (rule_tac x="dist x y - e" in exI, clarsimp)
apply (rename_tac x')
apply (cut_tac x=x and y=x' and z=y in dist_triangle)
apply simp
done

lemma open_contains_cball: "open S \<longleftrightarrow> (\<forall>x\<in>S. \<exists>e>0.  cball x e \<subseteq> S)"
proof-
  { fix x and e::real assume "x\<in>S" "e>0" "ball x e \<subseteq> S"
    hence "\<exists>d>0. cball x d \<subseteq> S" unfolding subset_eq by (rule_tac x="e/2" in exI, auto)
  } moreover
  { fix x and e::real assume "x\<in>S" "e>0" "cball x e \<subseteq> S"
    hence "\<exists>d>0. ball x d \<subseteq> S" unfolding subset_eq apply(rule_tac x="e/2" in exI) by auto
  } ultimately
  show ?thesis unfolding open_contains_ball by auto
qed

lemma open_contains_cball_eq: "open S ==> (\<forall>x. x \<in> S \<longleftrightarrow> (\<exists>e>0. cball x e \<subseteq> S))"
  by (metis open_contains_cball subset_eq order_less_imp_le centre_in_cball)

lemma mem_interior_cball: "x \<in> interior S \<longleftrightarrow> (\<exists>e>0. cball x e \<subseteq> S)"
  apply (simp add: interior_def, safe)
  apply (force simp add: open_contains_cball)
  apply (rule_tac x="ball x e" in exI)
  apply (simp add: subset_trans [OF ball_subset_cball])
  done

lemma islimpt_ball:
  fixes x y :: "'a::{real_normed_vector,perfect_space}"
  shows "y islimpt ball x e \<longleftrightarrow> 0 < e \<and> y \<in> cball x e" (is "?lhs = ?rhs")
proof
  assume "?lhs"
  { assume "e \<le> 0"
    hence *:"ball x e = {}" using ball_eq_empty[of x e] by auto
    have False using `?lhs` unfolding * using islimpt_EMPTY[of y] by auto
  }
  hence "e > 0" by (metis not_less)
  moreover
  have "y \<in> cball x e" using closed_cball[of x e] islimpt_subset[of y "ball x e" "cball x e"] ball_subset_cball[of x e] `?lhs` unfolding closed_limpt by auto
  ultimately show "?rhs" by auto
next
  assume "?rhs" hence "e>0"  by auto
  { fix d::real assume "d>0"
    have "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d"
    proof(cases "d \<le> dist x y")
      case True thus "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d"
      proof(cases "x=y")
        case True hence False using `d \<le> dist x y` `d>0` by auto
        thus "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d" by auto
      next
        case False

        have "dist x (y - (d / (2 * dist y x)) *\<^sub>R (y - x))
              = norm (x - y + (d / (2 * norm (y - x))) *\<^sub>R (y - x))"
          unfolding mem_cball mem_ball dist_norm diff_diff_eq2 diff_add_eq[THEN sym] by auto
        also have "\<dots> = \<bar>- 1 + d / (2 * norm (x - y))\<bar> * norm (x - y)"
          using scaleR_left_distrib[of "- 1" "d / (2 * norm (y - x))", THEN sym, of "y - x"]
          unfolding scaleR_minus_left scaleR_one
          by (auto simp add: norm_minus_commute)
        also have "\<dots> = \<bar>- norm (x - y) + d / 2\<bar>"
          unfolding abs_mult_pos[of "norm (x - y)", OF norm_ge_zero[of "x - y"]]
          unfolding distrib_right using `x\<noteq>y`[unfolded dist_nz, unfolded dist_norm] by auto
        also have "\<dots> \<le> e - d/2" using `d \<le> dist x y` and `d>0` and `?rhs` by(auto simp add: dist_norm)
        finally have "y - (d / (2 * dist y x)) *\<^sub>R (y - x) \<in> ball x e" using `d>0` by auto

        moreover

        have "(d / (2*dist y x)) *\<^sub>R (y - x) \<noteq> 0"
          using `x\<noteq>y`[unfolded dist_nz] `d>0` unfolding scaleR_eq_0_iff by (auto simp add: dist_commute)
        moreover
        have "dist (y - (d / (2 * dist y x)) *\<^sub>R (y - x)) y < d" unfolding dist_norm apply simp unfolding norm_minus_cancel
          using `d>0` `x\<noteq>y`[unfolded dist_nz] dist_commute[of x y]
          unfolding dist_norm by auto
        ultimately show "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d" by (rule_tac  x="y - (d / (2*dist y x)) *\<^sub>R (y - x)" in bexI) auto
      qed
    next
      case False hence "d > dist x y" by auto
      show "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d"
      proof(cases "x=y")
        case True
        obtain z where **: "z \<noteq> y" "dist z y < min e d"
          using perfect_choose_dist[of "min e d" y]
          using `d > 0` `e>0` by auto
        show "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d"
          unfolding `x = y`
          using `z \<noteq> y` **
          by (rule_tac x=z in bexI, auto simp add: dist_commute)
      next
        case False thus "\<exists>x'\<in>ball x e. x' \<noteq> y \<and> dist x' y < d"
          using `d>0` `d > dist x y` `?rhs` by(rule_tac x=x in bexI, auto)
      qed
    qed  }
  thus "?lhs" unfolding mem_cball islimpt_approachable mem_ball by auto
qed

lemma closure_ball_lemma:
  fixes x y :: "'a::real_normed_vector"
  assumes "x \<noteq> y" shows "y islimpt ball x (dist x y)"
proof (rule islimptI)
  fix T assume "y \<in> T" "open T"
  then obtain r where "0 < r" "\<forall>z. dist z y < r \<longrightarrow> z \<in> T"
    unfolding open_dist by fast
  (* choose point between x and y, within distance r of y. *)
  def k \<equiv> "min 1 (r / (2 * dist x y))"
  def z \<equiv> "y + scaleR k (x - y)"
  have z_def2: "z = x + scaleR (1 - k) (y - x)"
    unfolding z_def by (simp add: algebra_simps)
  have "dist z y < r"
    unfolding z_def k_def using `0 < r`
    by (simp add: dist_norm min_def)
  hence "z \<in> T" using `\<forall>z. dist z y < r \<longrightarrow> z \<in> T` by simp
  have "dist x z < dist x y"
    unfolding z_def2 dist_norm
    apply (simp add: norm_minus_commute)
    apply (simp only: dist_norm [symmetric])
    apply (subgoal_tac "\<bar>1 - k\<bar> * dist x y < 1 * dist x y", simp)
    apply (rule mult_strict_right_mono)
    apply (simp add: k_def divide_pos_pos zero_less_dist_iff `0 < r` `x \<noteq> y`)
    apply (simp add: zero_less_dist_iff `x \<noteq> y`)
    done
  hence "z \<in> ball x (dist x y)" by simp
  have "z \<noteq> y"
    unfolding z_def k_def using `x \<noteq> y` `0 < r`
    by (simp add: min_def)
  show "\<exists>z\<in>ball x (dist x y). z \<in> T \<and> z \<noteq> y"
    using `z \<in> ball x (dist x y)` `z \<in> T` `z \<noteq> y`
    by fast
qed

lemma closure_ball:
  fixes x :: "'a::real_normed_vector"
  shows "0 < e \<Longrightarrow> closure (ball x e) = cball x e"
apply (rule equalityI)
apply (rule closure_minimal)
apply (rule ball_subset_cball)
apply (rule closed_cball)
apply (rule subsetI, rename_tac y)
apply (simp add: le_less [where 'a=real])
apply (erule disjE)
apply (rule subsetD [OF closure_subset], simp)
apply (simp add: closure_def)
apply clarify
apply (rule closure_ball_lemma)
apply (simp add: zero_less_dist_iff)
done

(* In a trivial vector space, this fails for e = 0. *)
lemma interior_cball:
  fixes x :: "'a::{real_normed_vector, perfect_space}"
  shows "interior (cball x e) = ball x e"
proof(cases "e\<ge>0")
  case False note cs = this
  from cs have "ball x e = {}" using ball_empty[of e x] by auto moreover
  { fix y assume "y \<in> cball x e"
    hence False unfolding mem_cball using dist_nz[of x y] cs by auto  }
  hence "cball x e = {}" by auto
  hence "interior (cball x e) = {}" using interior_empty by auto
  ultimately show ?thesis by blast
next
  case True note cs = this
  have "ball x e \<subseteq> cball x e" using ball_subset_cball by auto moreover
  { fix S y assume as: "S \<subseteq> cball x e" "open S" "y\<in>S"
    then obtain d where "d>0" and d:"\<forall>x'. dist x' y < d \<longrightarrow> x' \<in> S" unfolding open_dist by blast

    then obtain xa where xa_y: "xa \<noteq> y" and xa: "dist xa y < d"
      using perfect_choose_dist [of d] by auto
    have "xa\<in>S" using d[THEN spec[where x=xa]] using xa by(auto simp add: dist_commute)
    hence xa_cball:"xa \<in> cball x e" using as(1) by auto

    hence "y \<in> ball x e" proof(cases "x = y")
      case True
      hence "e>0" using xa_y[unfolded dist_nz] xa_cball[unfolded mem_cball] by (auto simp add: dist_commute)
      thus "y \<in> ball x e" using `x = y ` by simp
    next
      case False
      have "dist (y + (d / 2 / dist y x) *\<^sub>R (y - x)) y < d" unfolding dist_norm
        using `d>0` norm_ge_zero[of "y - x"] `x \<noteq> y` by auto
      hence *:"y + (d / 2 / dist y x) *\<^sub>R (y - x) \<in> cball x e" using d as(1)[unfolded subset_eq] by blast
      have "y - x \<noteq> 0" using `x \<noteq> y` by auto
      hence **:"d / (2 * norm (y - x)) > 0" unfolding zero_less_norm_iff[THEN sym]
        using `d>0` divide_pos_pos[of d "2*norm (y - x)"] by auto

      have "dist (y + (d / 2 / dist y x) *\<^sub>R (y - x)) x = norm (y + (d / (2 * norm (y - x))) *\<^sub>R y - (d / (2 * norm (y - x))) *\<^sub>R x - x)"
        by (auto simp add: dist_norm algebra_simps)
      also have "\<dots> = norm ((1 + d / (2 * norm (y - x))) *\<^sub>R (y - x))"
        by (auto simp add: algebra_simps)
      also have "\<dots> = \<bar>1 + d / (2 * norm (y - x))\<bar> * norm (y - x)"
        using ** by auto
      also have "\<dots> = (dist y x) + d/2"using ** by (auto simp add: distrib_right dist_norm)
      finally have "e \<ge> dist x y +d/2" using *[unfolded mem_cball] by (auto simp add: dist_commute)
      thus "y \<in> ball x e" unfolding mem_ball using `d>0` by auto
    qed  }
  hence "\<forall>S \<subseteq> cball x e. open S \<longrightarrow> S \<subseteq> ball x e" by auto
  ultimately show ?thesis using interior_unique[of "ball x e" "cball x e"] using open_ball[of x e] by auto
qed

lemma frontier_ball:
  fixes a :: "'a::real_normed_vector"
  shows "0 < e ==> frontier(ball a e) = {x. dist a x = e}"
  apply (simp add: frontier_def closure_ball interior_open order_less_imp_le)
  apply (simp add: set_eq_iff)
  by arith

lemma frontier_cball:
  fixes a :: "'a::{real_normed_vector, perfect_space}"
  shows "frontier(cball a e) = {x. dist a x = e}"
  apply (simp add: frontier_def interior_cball closed_cball order_less_imp_le)
  apply (simp add: set_eq_iff)
  by arith

lemma cball_eq_empty: "(cball x e = {}) \<longleftrightarrow> e < 0"
  apply (simp add: set_eq_iff not_le)
  by (metis zero_le_dist dist_self order_less_le_trans)
lemma cball_empty: "e < 0 ==> cball x e = {}" by (simp add: cball_eq_empty)

lemma cball_eq_sing:
  fixes x :: "'a::{metric_space,perfect_space}"
  shows "(cball x e = {x}) \<longleftrightarrow> e = 0"
proof (rule linorder_cases)
  assume e: "0 < e"
  obtain a where "a \<noteq> x" "dist a x < e"
    using perfect_choose_dist [OF e] by auto
  hence "a \<noteq> x" "dist x a \<le> e" by (auto simp add: dist_commute)
  with e show ?thesis by (auto simp add: set_eq_iff)
qed auto

lemma cball_sing:
  fixes x :: "'a::metric_space"
  shows "e = 0 ==> cball x e = {x}"
  by (auto simp add: set_eq_iff)


subsection {* Boundedness *}

  (* FIXME: This has to be unified with BSEQ!! *)
definition (in metric_space)
  bounded :: "'a set \<Rightarrow> bool" where
  "bounded S \<longleftrightarrow> (\<exists>x e. \<forall>y\<in>S. dist x y \<le> e)"

lemma bounded_any_center: "bounded S \<longleftrightarrow> (\<exists>e. \<forall>y\<in>S. dist a y \<le> e)"
unfolding bounded_def
apply safe
apply (rule_tac x="dist a x + e" in exI, clarify)
apply (drule (1) bspec)
apply (erule order_trans [OF dist_triangle add_left_mono])
apply auto
done

lemma bounded_iff: "bounded S \<longleftrightarrow> (\<exists>a. \<forall>x\<in>S. norm x \<le> a)"
unfolding bounded_any_center [where a=0]
by (simp add: dist_norm)

lemma bounded_realI: assumes "\<forall>x\<in>s. abs (x::real) \<le> B" shows "bounded s"
  unfolding bounded_def dist_real_def apply(rule_tac x=0 in exI)
  using assms by auto

lemma bounded_empty [simp]: "bounded {}"
  by (simp add: bounded_def)

lemma bounded_subset: "bounded T \<Longrightarrow> S \<subseteq> T ==> bounded S"
  by (metis bounded_def subset_eq)

lemma bounded_interior[intro]: "bounded S ==> bounded(interior S)"
  by (metis bounded_subset interior_subset)

lemma bounded_closure[intro]: assumes "bounded S" shows "bounded(closure S)"
proof-
  from assms obtain x and a where a: "\<forall>y\<in>S. dist x y \<le> a" unfolding bounded_def by auto
  { fix y assume "y \<in> closure S"
    then obtain f where f: "\<forall>n. f n \<in> S"  "(f ---> y) sequentially"
      unfolding closure_sequential by auto
    have "\<forall>n. f n \<in> S \<longrightarrow> dist x (f n) \<le> a" using a by simp
    hence "eventually (\<lambda>n. dist x (f n) \<le> a) sequentially"
      by (rule eventually_mono, simp add: f(1))
    have "dist x y \<le> a"
      apply (rule Lim_dist_ubound [of sequentially f])
      apply (rule trivial_limit_sequentially)
      apply (rule f(2))
      apply fact
      done
  }
  thus ?thesis unfolding bounded_def by auto
qed

lemma bounded_cball[simp,intro]: "bounded (cball x e)"
  apply (simp add: bounded_def)
  apply (rule_tac x=x in exI)
  apply (rule_tac x=e in exI)
  apply auto
  done

lemma bounded_ball[simp,intro]: "bounded(ball x e)"
  by (metis ball_subset_cball bounded_cball bounded_subset)

lemma bounded_Un[simp]: "bounded (S \<union> T) \<longleftrightarrow> bounded S \<and> bounded T"
  apply (auto simp add: bounded_def)
  apply (rename_tac x y r s)
  apply (rule_tac x=x in exI)
  apply (rule_tac x="max r (dist x y + s)" in exI)
  apply (rule ballI, rename_tac z, safe)
  apply (drule (1) bspec, simp)
  apply (drule (1) bspec)
  apply (rule min_max.le_supI2)
  apply (erule order_trans [OF dist_triangle add_left_mono])
  done

lemma bounded_Union[intro]: "finite F \<Longrightarrow> (\<forall>S\<in>F. bounded S) \<Longrightarrow> bounded(\<Union>F)"
  by (induct rule: finite_induct[of F], auto)

lemma bounded_UN [intro]: "finite A \<Longrightarrow> \<forall>x\<in>A. bounded (B x) \<Longrightarrow> bounded (\<Union>x\<in>A. B x)"
  by (induct set: finite, auto)

lemma bounded_insert [simp]: "bounded (insert x S) \<longleftrightarrow> bounded S"
proof -
  have "\<forall>y\<in>{x}. dist x y \<le> 0" by simp
  hence "bounded {x}" unfolding bounded_def by fast
  thus ?thesis by (metis insert_is_Un bounded_Un)
qed

lemma finite_imp_bounded [intro]: "finite S \<Longrightarrow> bounded S"
  by (induct set: finite, simp_all)

lemma bounded_pos: "bounded S \<longleftrightarrow> (\<exists>b>0. \<forall>x\<in> S. norm x <= b)"
  apply (simp add: bounded_iff)
  apply (subgoal_tac "\<And>x (y::real). 0 < 1 + abs y \<and> (x <= y \<longrightarrow> x <= 1 + abs y)")
  by metis arith

lemma Bseq_eq_bounded: "Bseq f \<longleftrightarrow> bounded (range f)"
  unfolding Bseq_def bounded_pos by auto

lemma bounded_Int[intro]: "bounded S \<or> bounded T \<Longrightarrow> bounded (S \<inter> T)"
  by (metis Int_lower1 Int_lower2 bounded_subset)

lemma bounded_diff[intro]: "bounded S ==> bounded (S - T)"
apply (metis Diff_subset bounded_subset)
done

lemma not_bounded_UNIV[simp, intro]:
  "\<not> bounded (UNIV :: 'a::{real_normed_vector, perfect_space} set)"
proof(auto simp add: bounded_pos not_le)
  obtain x :: 'a where "x \<noteq> 0"
    using perfect_choose_dist [OF zero_less_one] by fast
  fix b::real  assume b: "b >0"
  have b1: "b +1 \<ge> 0" using b by simp
  with `x \<noteq> 0` have "b < norm (scaleR (b + 1) (sgn x))"
    by (simp add: norm_sgn)
  then show "\<exists>x::'a. b < norm x" ..
qed

lemma bounded_linear_image:
  assumes "bounded S" "bounded_linear f"
  shows "bounded(f ` S)"
proof-
  from assms(1) obtain b where b:"b>0" "\<forall>x\<in>S. norm x \<le> b" unfolding bounded_pos by auto
  from assms(2) obtain B where B:"B>0" "\<forall>x. norm (f x) \<le> B * norm x" using bounded_linear.pos_bounded by (auto simp add: mult_ac)
  { fix x assume "x\<in>S"
    hence "norm x \<le> b" using b by auto
    hence "norm (f x) \<le> B * b" using B(2) apply(erule_tac x=x in allE)
      by (metis B(1) B(2) order_trans mult_le_cancel_left_pos)
  }
  thus ?thesis unfolding bounded_pos apply(rule_tac x="b*B" in exI)
    using b B mult_pos_pos [of b B] by (auto simp add: mult_commute)
qed

lemma bounded_scaling:
  fixes S :: "'a::real_normed_vector set"
  shows "bounded S \<Longrightarrow> bounded ((\<lambda>x. c *\<^sub>R x) ` S)"
  apply (rule bounded_linear_image, assumption)
  apply (rule bounded_linear_scaleR_right)
  done

lemma bounded_translation:
  fixes S :: "'a::real_normed_vector set"
  assumes "bounded S" shows "bounded ((\<lambda>x. a + x) ` S)"
proof-
  from assms obtain b where b:"b>0" "\<forall>x\<in>S. norm x \<le> b" unfolding bounded_pos by auto
  { fix x assume "x\<in>S"
    hence "norm (a + x) \<le> b + norm a" using norm_triangle_ineq[of a x] b by auto
  }
  thus ?thesis unfolding bounded_pos using norm_ge_zero[of a] b(1) using add_strict_increasing[of b 0 "norm a"]
    by (auto intro!: exI[of _ "b + norm a"])
qed


text{* Some theorems on sups and infs using the notion "bounded". *}

lemma bounded_real:
  fixes S :: "real set"
  shows "bounded S \<longleftrightarrow>  (\<exists>a. \<forall>x\<in>S. abs x <= a)"
  by (simp add: bounded_iff)

lemma bounded_has_Sup:
  fixes S :: "real set"
  assumes "bounded S" "S \<noteq> {}"
  shows "\<forall>x\<in>S. x <= Sup S" and "\<forall>b. (\<forall>x\<in>S. x <= b) \<longrightarrow> Sup S <= b"
proof
  fix x assume "x\<in>S"
  thus "x \<le> Sup S"
    by (metis SupInf.Sup_upper abs_le_D1 assms(1) bounded_real)
next
  show "\<forall>b. (\<forall>x\<in>S. x \<le> b) \<longrightarrow> Sup S \<le> b" using assms
    by (metis SupInf.Sup_least)
qed

lemma Sup_insert:
  fixes S :: "real set"
  shows "bounded S ==> Sup(insert x S) = (if S = {} then x else max x (Sup S))" 
by auto (metis Int_absorb Sup_insert_nonempty assms bounded_has_Sup(1) disjoint_iff_not_equal) 

lemma Sup_insert_finite:
  fixes S :: "real set"
  shows "finite S \<Longrightarrow> Sup(insert x S) = (if S = {} then x else max x (Sup S))"
  apply (rule Sup_insert)
  apply (rule finite_imp_bounded)
  by simp

lemma bounded_has_Inf:
  fixes S :: "real set"
  assumes "bounded S"  "S \<noteq> {}"
  shows "\<forall>x\<in>S. x >= Inf S" and "\<forall>b. (\<forall>x\<in>S. x >= b) \<longrightarrow> Inf S >= b"
proof
  fix x assume "x\<in>S"
  from assms(1) obtain a where a:"\<forall>x\<in>S. \<bar>x\<bar> \<le> a" unfolding bounded_real by auto
  thus "x \<ge> Inf S" using `x\<in>S`
    by (metis Inf_lower_EX abs_le_D2 minus_le_iff)
next
  show "\<forall>b. (\<forall>x\<in>S. x >= b) \<longrightarrow> Inf S \<ge> b" using assms
    by (metis SupInf.Inf_greatest)
qed

lemma Inf_insert:
  fixes S :: "real set"
  shows "bounded S ==> Inf(insert x S) = (if S = {} then x else min x (Inf S))" 
by auto (metis Int_absorb Inf_insert_nonempty bounded_has_Inf(1) disjoint_iff_not_equal)

lemma Inf_insert_finite:
  fixes S :: "real set"
  shows "finite S ==> Inf(insert x S) = (if S = {} then x else min x (Inf S))"
  by (rule Inf_insert, rule finite_imp_bounded, simp)

subsection {* Compactness *}

subsubsection{* Open-cover compactness *}

definition compact :: "'a::topological_space set \<Rightarrow> bool" where
  compact_eq_heine_borel: -- "This name is used for backwards compatibility"
    "compact S \<longleftrightarrow> (\<forall>C. (\<forall>c\<in>C. open c) \<and> S \<subseteq> \<Union>C \<longrightarrow> (\<exists>D\<subseteq>C. finite D \<and> S \<subseteq> \<Union>D))"

lemma compactI:
  assumes "\<And>C. \<forall>t\<in>C. open t \<Longrightarrow> s \<subseteq> \<Union> C \<Longrightarrow> \<exists>C'. C' \<subseteq> C \<and> finite C' \<and> s \<subseteq> \<Union> C'"
  shows "compact s"
  unfolding compact_eq_heine_borel using assms by metis

lemma compactE:
  assumes "compact s" and "\<forall>t\<in>C. open t" and "s \<subseteq> \<Union>C"
  obtains C' where "C' \<subseteq> C" and "finite C'" and "s \<subseteq> \<Union>C'"
  using assms unfolding compact_eq_heine_borel by metis

lemma compactE_image:
  assumes "compact s" and "\<forall>t\<in>C. open (f t)" and "s \<subseteq> (\<Union>c\<in>C. f c)"
  obtains C' where "C' \<subseteq> C" and "finite C'" and "s \<subseteq> (\<Union>c\<in>C'. f c)"
  using assms unfolding ball_simps[symmetric] SUP_def
  by (metis (lifting) finite_subset_image compact_eq_heine_borel[of s])

subsubsection {* Bolzano-Weierstrass property *}

lemma heine_borel_imp_bolzano_weierstrass:
  assumes "compact s" "infinite t"  "t \<subseteq> s"
  shows "\<exists>x \<in> s. x islimpt t"
proof(rule ccontr)
  assume "\<not> (\<exists>x \<in> s. x islimpt t)"
  then obtain f where f:"\<forall>x\<in>s. x \<in> f x \<and> open (f x) \<and> (\<forall>y\<in>t. y \<in> f x \<longrightarrow> y = x)" unfolding islimpt_def
    using bchoice[of s "\<lambda> x T. x \<in> T \<and> open T \<and> (\<forall>y\<in>t. y \<in> T \<longrightarrow> y = x)"] by auto
  obtain g where g:"g\<subseteq>{t. \<exists>x. x \<in> s \<and> t = f x}" "finite g" "s \<subseteq> \<Union>g"
    using assms(1)[unfolded compact_eq_heine_borel, THEN spec[where x="{t. \<exists>x. x\<in>s \<and> t = f x}"]] using f by auto
  from g(1,3) have g':"\<forall>x\<in>g. \<exists>xa \<in> s. x = f xa" by auto
  { fix x y assume "x\<in>t" "y\<in>t" "f x = f y"
    hence "x \<in> f x"  "y \<in> f x \<longrightarrow> y = x" using f[THEN bspec[where x=x]] and `t\<subseteq>s` by auto
    hence "x = y" using `f x = f y` and f[THEN bspec[where x=y]] and `y\<in>t` and `t\<subseteq>s` by auto  }
  hence "inj_on f t" unfolding inj_on_def by simp
  hence "infinite (f ` t)" using assms(2) using finite_imageD by auto
  moreover
  { fix x assume "x\<in>t" "f x \<notin> g"
    from g(3) assms(3) `x\<in>t` obtain h where "h\<in>g" and "x\<in>h" by auto
    then obtain y where "y\<in>s" "h = f y" using g'[THEN bspec[where x=h]] by auto
    hence "y = x" using f[THEN bspec[where x=y]] and `x\<in>t` and `x\<in>h`[unfolded `h = f y`] by auto
    hence False using `f x \<notin> g` `h\<in>g` unfolding `h = f y` by auto  }
  hence "f ` t \<subseteq> g" by auto
  ultimately show False using g(2) using finite_subset by auto
qed

lemma acc_point_range_imp_convergent_subsequence:
  fixes l :: "'a :: first_countable_topology"
  assumes l: "\<forall>U. l\<in>U \<longrightarrow> open U \<longrightarrow> infinite (U \<inter> range f)"
  shows "\<exists>r. subseq r \<and> (f \<circ> r) ----> l"
proof -
  from countable_basis_at_decseq[of l] guess A . note A = this

  def s \<equiv> "\<lambda>n i. SOME j. i < j \<and> f j \<in> A (Suc n)"
  { fix n i
    have "infinite (A (Suc n) \<inter> range f - f`{.. i})"
      using l A by auto
    then have "\<exists>x. x \<in> A (Suc n) \<inter> range f - f`{.. i}"
      unfolding ex_in_conv by (intro notI) simp
    then have "\<exists>j. f j \<in> A (Suc n) \<and> j \<notin> {.. i}"
      by auto
    then have "\<exists>a. i < a \<and> f a \<in> A (Suc n)"
      by (auto simp: not_le)
    then have "i < s n i" "f (s n i) \<in> A (Suc n)"
      unfolding s_def by (auto intro: someI2_ex) }
  note s = this
  def r \<equiv> "nat_rec (s 0 0) s"
  have "subseq r"
    by (auto simp: r_def s subseq_Suc_iff)
  moreover
  have "(\<lambda>n. f (r n)) ----> l"
  proof (rule topological_tendstoI)
    fix S assume "open S" "l \<in> S"
    with A(3) have "eventually (\<lambda>i. A i \<subseteq> S) sequentially" by auto
    moreover
    { fix i assume "Suc 0 \<le> i" then have "f (r i) \<in> A i"
        by (cases i) (simp_all add: r_def s) }
    then have "eventually (\<lambda>i. f (r i) \<in> A i) sequentially" by (auto simp: eventually_sequentially)
    ultimately show "eventually (\<lambda>i. f (r i) \<in> S) sequentially"
      by eventually_elim auto
  qed
  ultimately show "\<exists>r. subseq r \<and> (f \<circ> r) ----> l"
    by (auto simp: convergent_def comp_def)
qed

lemma sequence_infinite_lemma:
  fixes f :: "nat \<Rightarrow> 'a::t1_space"
  assumes "\<forall>n. f n \<noteq> l" and "(f ---> l) sequentially"
  shows "infinite (range f)"
proof
  assume "finite (range f)"
  hence "closed (range f)" by (rule finite_imp_closed)
  hence "open (- range f)" by (rule open_Compl)
  from assms(1) have "l \<in> - range f" by auto
  from assms(2) have "eventually (\<lambda>n. f n \<in> - range f) sequentially"
    using `open (- range f)` `l \<in> - range f` by (rule topological_tendstoD)
  thus False unfolding eventually_sequentially by auto
qed

lemma closure_insert:
  fixes x :: "'a::t1_space"
  shows "closure (insert x s) = insert x (closure s)"
apply (rule closure_unique)
apply (rule insert_mono [OF closure_subset])
apply (rule closed_insert [OF closed_closure])
apply (simp add: closure_minimal)
done

lemma islimpt_insert:
  fixes x :: "'a::t1_space"
  shows "x islimpt (insert a s) \<longleftrightarrow> x islimpt s"
proof
  assume *: "x islimpt (insert a s)"
  show "x islimpt s"
  proof (rule islimptI)
    fix t assume t: "x \<in> t" "open t"
    show "\<exists>y\<in>s. y \<in> t \<and> y \<noteq> x"
    proof (cases "x = a")
      case True
      obtain y where "y \<in> insert a s" "y \<in> t" "y \<noteq> x"
        using * t by (rule islimptE)
      with `x = a` show ?thesis by auto
    next
      case False
      with t have t': "x \<in> t - {a}" "open (t - {a})"
        by (simp_all add: open_Diff)
      obtain y where "y \<in> insert a s" "y \<in> t - {a}" "y \<noteq> x"
        using * t' by (rule islimptE)
      thus ?thesis by auto
    qed
  qed
next
  assume "x islimpt s" thus "x islimpt (insert a s)"
    by (rule islimpt_subset) auto
qed

lemma islimpt_finite:
  fixes x :: "'a::t1_space"
  shows "finite s \<Longrightarrow> \<not> x islimpt s"
by (induct set: finite, simp_all add: islimpt_insert)

lemma islimpt_union_finite:
  fixes x :: "'a::t1_space"
  shows "finite s \<Longrightarrow> x islimpt (s \<union> t) \<longleftrightarrow> x islimpt t"
by (simp add: islimpt_Un islimpt_finite)

lemma islimpt_eq_acc_point:
  fixes l :: "'a :: t1_space"
  shows "l islimpt S \<longleftrightarrow> (\<forall>U. l\<in>U \<longrightarrow> open U \<longrightarrow> infinite (U \<inter> S))"
proof (safe intro!: islimptI)
  fix U assume "l islimpt S" "l \<in> U" "open U" "finite (U \<inter> S)"
  then have "l islimpt S" "l \<in> (U - (U \<inter> S - {l}))" "open (U - (U \<inter> S - {l}))"
    by (auto intro: finite_imp_closed)
  then show False
    by (rule islimptE) auto
next
  fix T assume *: "\<forall>U. l\<in>U \<longrightarrow> open U \<longrightarrow> infinite (U \<inter> S)" "l \<in> T" "open T"
  then have "infinite (T \<inter> S - {l})" by auto
  then have "\<exists>x. x \<in> (T \<inter> S - {l})"
    unfolding ex_in_conv by (intro notI) simp
  then show "\<exists>y\<in>S. y \<in> T \<and> y \<noteq> l"
    by auto
qed

lemma islimpt_range_imp_convergent_subsequence:
  fixes l :: "'a :: {t1_space, first_countable_topology}"
  assumes l: "l islimpt (range f)"
  shows "\<exists>r. subseq r \<and> (f \<circ> r) ----> l"
  using l unfolding islimpt_eq_acc_point
  by (rule acc_point_range_imp_convergent_subsequence)

lemma sequence_unique_limpt:
  fixes f :: "nat \<Rightarrow> 'a::t2_space"
  assumes "(f ---> l) sequentially" and "l' islimpt (range f)"
  shows "l' = l"
proof (rule ccontr)
  assume "l' \<noteq> l"
  obtain s t where "open s" "open t" "l' \<in> s" "l \<in> t" "s \<inter> t = {}"
    using hausdorff [OF `l' \<noteq> l`] by auto
  have "eventually (\<lambda>n. f n \<in> t) sequentially"
    using assms(1) `open t` `l \<in> t` by (rule topological_tendstoD)
  then obtain N where "\<forall>n\<ge>N. f n \<in> t"
    unfolding eventually_sequentially by auto

  have "UNIV = {..<N} \<union> {N..}" by auto
  hence "l' islimpt (f ` ({..<N} \<union> {N..}))" using assms(2) by simp
  hence "l' islimpt (f ` {..<N} \<union> f ` {N..})" by (simp add: image_Un)
  hence "l' islimpt (f ` {N..})" by (simp add: islimpt_union_finite)
  then obtain y where "y \<in> f ` {N..}" "y \<in> s" "y \<noteq> l'"
    using `l' \<in> s` `open s` by (rule islimptE)
  then obtain n where "N \<le> n" "f n \<in> s" "f n \<noteq> l'" by auto
  with `\<forall>n\<ge>N. f n \<in> t` have "f n \<in> s \<inter> t" by simp
  with `s \<inter> t = {}` show False by simp
qed

lemma bolzano_weierstrass_imp_closed:
  fixes s :: "'a::{first_countable_topology, t2_space} set"
  assumes "\<forall>t. infinite t \<and> t \<subseteq> s --> (\<exists>x \<in> s. x islimpt t)"
  shows "closed s"
proof-
  { fix x l assume as: "\<forall>n::nat. x n \<in> s" "(x ---> l) sequentially"
    hence "l \<in> s"
    proof(cases "\<forall>n. x n \<noteq> l")
      case False thus "l\<in>s" using as(1) by auto
    next
      case True note cas = this
      with as(2) have "infinite (range x)" using sequence_infinite_lemma[of x l] by auto
      then obtain l' where "l'\<in>s" "l' islimpt (range x)" using assms[THEN spec[where x="range x"]] as(1) by auto
      thus "l\<in>s" using sequence_unique_limpt[of x l l'] using as cas by auto
    qed  }
  thus ?thesis unfolding closed_sequential_limits by fast
qed

lemma compact_imp_closed:
  fixes s :: "'a::t2_space set"
  assumes "compact s" shows "closed s"
unfolding closed_def
proof (rule openI)
  fix y assume "y \<in> - s"
  let ?C = "\<Union>x\<in>s. {u. open u \<and> x \<in> u \<and> eventually (\<lambda>y. y \<notin> u) (nhds y)}"
  note `compact s`
  moreover have "\<forall>u\<in>?C. open u" by simp
  moreover have "s \<subseteq> \<Union>?C"
  proof
    fix x assume "x \<in> s"
    with `y \<in> - s` have "x \<noteq> y" by clarsimp
    hence "\<exists>u v. open u \<and> open v \<and> x \<in> u \<and> y \<in> v \<and> u \<inter> v = {}"
      by (rule hausdorff)
    with `x \<in> s` show "x \<in> \<Union>?C"
      unfolding eventually_nhds by auto
  qed
  ultimately obtain D where "D \<subseteq> ?C" and "finite D" and "s \<subseteq> \<Union>D"
    by (rule compactE)
  from `D \<subseteq> ?C` have "\<forall>x\<in>D. eventually (\<lambda>y. y \<notin> x) (nhds y)" by auto
  with `finite D` have "eventually (\<lambda>y. y \<notin> \<Union>D) (nhds y)"
    by (simp add: eventually_Ball_finite)
  with `s \<subseteq> \<Union>D` have "eventually (\<lambda>y. y \<notin> s) (nhds y)"
    by (auto elim!: eventually_mono [rotated])
  thus "\<exists>t. open t \<and> y \<in> t \<and> t \<subseteq> - s"
    by (simp add: eventually_nhds subset_eq)
qed

lemma compact_imp_bounded:
  assumes "compact U" shows "bounded U"
proof -
  have "compact U" "\<forall>x\<in>U. open (ball x 1)" "U \<subseteq> (\<Union>x\<in>U. ball x 1)" using assms by auto
  then obtain D where D: "D \<subseteq> U" "finite D" "U \<subseteq> (\<Union>x\<in>D. ball x 1)"
    by (elim compactE_image)
  from `finite D` have "bounded (\<Union>x\<in>D. ball x 1)"
    by (simp add: bounded_UN)
  thus "bounded U" using `U \<subseteq> (\<Union>x\<in>D. ball x 1)` 
    by (rule bounded_subset)
qed

text{* In particular, some common special cases. *}

lemma compact_empty[simp]:
 "compact {}"
  unfolding compact_eq_heine_borel
  by auto

lemma compact_union [intro]:
  assumes "compact s" "compact t" shows " compact (s \<union> t)"
proof (rule compactI)
  fix f assume *: "Ball f open" "s \<union> t \<subseteq> \<Union>f"
  from * `compact s` obtain s' where "s' \<subseteq> f \<and> finite s' \<and> s \<subseteq> \<Union>s'"
    unfolding compact_eq_heine_borel by (auto elim!: allE[of _ f]) metis
  moreover from * `compact t` obtain t' where "t' \<subseteq> f \<and> finite t' \<and> t \<subseteq> \<Union>t'"
    unfolding compact_eq_heine_borel by (auto elim!: allE[of _ f]) metis
  ultimately show "\<exists>f'\<subseteq>f. finite f' \<and> s \<union> t \<subseteq> \<Union>f'"
    by (auto intro!: exI[of _ "s' \<union> t'"])
qed

lemma compact_Union [intro]: "finite S \<Longrightarrow> (\<And>T. T \<in> S \<Longrightarrow> compact T) \<Longrightarrow> compact (\<Union>S)"
  by (induct set: finite) auto

lemma compact_UN [intro]:
  "finite A \<Longrightarrow> (\<And>x. x \<in> A \<Longrightarrow> compact (B x)) \<Longrightarrow> compact (\<Union>x\<in>A. B x)"
  unfolding SUP_def by (rule compact_Union) auto

lemma compact_inter_closed [intro]:
  assumes "compact s" and "closed t"
  shows "compact (s \<inter> t)"
proof (rule compactI)
  fix C assume C: "\<forall>c\<in>C. open c" and cover: "s \<inter> t \<subseteq> \<Union>C"
  from C `closed t` have "\<forall>c\<in>C \<union> {-t}. open c" by auto
  moreover from cover have "s \<subseteq> \<Union>(C \<union> {-t})" by auto
  ultimately have "\<exists>D\<subseteq>C \<union> {-t}. finite D \<and> s \<subseteq> \<Union>D"
    using `compact s` unfolding compact_eq_heine_borel by auto
  then guess D ..
  then show "\<exists>D\<subseteq>C. finite D \<and> s \<inter> t \<subseteq> \<Union>D"
    by (intro exI[of _ "D - {-t}"]) auto
qed

lemma closed_inter_compact [intro]:
  assumes "closed s" and "compact t"
  shows "compact (s \<inter> t)"
  using compact_inter_closed [of t s] assms
  by (simp add: Int_commute)

lemma compact_inter [intro]:
  fixes s t :: "'a :: t2_space set"
  assumes "compact s" and "compact t"
  shows "compact (s \<inter> t)"
  using assms by (intro compact_inter_closed compact_imp_closed)

lemma compact_sing [simp]: "compact {a}"
  unfolding compact_eq_heine_borel by auto

lemma compact_insert [simp]:
  assumes "compact s" shows "compact (insert x s)"
proof -
  have "compact ({x} \<union> s)"
    using compact_sing assms by (rule compact_union)
  thus ?thesis by simp
qed

lemma finite_imp_compact:
  shows "finite s \<Longrightarrow> compact s"
  by (induct set: finite) simp_all

lemma open_delete:
  fixes s :: "'a::t1_space set"
  shows "open s \<Longrightarrow> open (s - {x})"
  by (simp add: open_Diff)

text{* Finite intersection property *}

lemma inj_setminus: "inj_on uminus (A::'a set set)"
  by (auto simp: inj_on_def)

lemma compact_fip:
  "compact U \<longleftrightarrow>
    (\<forall>A. (\<forall>a\<in>A. closed a) \<longrightarrow> (\<forall>B \<subseteq> A. finite B \<longrightarrow> U \<inter> \<Inter>B \<noteq> {}) \<longrightarrow> U \<inter> \<Inter>A \<noteq> {})"
  (is "_ \<longleftrightarrow> ?R")
proof (safe intro!: compact_eq_heine_borel[THEN iffD2])
  fix A assume "compact U" and A: "\<forall>a\<in>A. closed a" "U \<inter> \<Inter>A = {}"
    and fi: "\<forall>B \<subseteq> A. finite B \<longrightarrow> U \<inter> \<Inter>B \<noteq> {}"
  from A have "(\<forall>a\<in>uminus`A. open a) \<and> U \<subseteq> \<Union>uminus`A"
    by auto
  with `compact U` obtain B where "B \<subseteq> A" "finite (uminus`B)" "U \<subseteq> \<Union>(uminus`B)"
    unfolding compact_eq_heine_borel by (metis subset_image_iff)
  with fi[THEN spec, of B] show False
    by (auto dest: finite_imageD intro: inj_setminus)
next
  fix A assume ?R and cover: "\<forall>a\<in>A. open a" "U \<subseteq> \<Union>A"
  from cover have "U \<inter> \<Inter>(uminus`A) = {}" "\<forall>a\<in>uminus`A. closed a"
    by auto
  with `?R` obtain B where "B \<subseteq> A" "finite (uminus`B)" "U \<inter> \<Inter>uminus`B = {}"
    by (metis subset_image_iff)
  then show "\<exists>T\<subseteq>A. finite T \<and> U \<subseteq> \<Union>T"
    by  (auto intro!: exI[of _ B] inj_setminus dest: finite_imageD)
qed

lemma compact_imp_fip:
  "compact s \<Longrightarrow> \<forall>t \<in> f. closed t \<Longrightarrow> \<forall>f'. finite f' \<and> f' \<subseteq> f \<longrightarrow> (s \<inter> (\<Inter> f') \<noteq> {}) \<Longrightarrow>
    s \<inter> (\<Inter> f) \<noteq> {}"
  unfolding compact_fip by auto

text{*Compactness expressed with filters*}

definition "filter_from_subbase B = Abs_filter (\<lambda>P. \<exists>X \<subseteq> B. finite X \<and> Inf X \<le> P)"

lemma eventually_filter_from_subbase:
  "eventually P (filter_from_subbase B) \<longleftrightarrow> (\<exists>X \<subseteq> B. finite X \<and> Inf X \<le> P)"
    (is "_ \<longleftrightarrow> ?R P")
  unfolding filter_from_subbase_def
proof (rule eventually_Abs_filter is_filter.intro)+
  show "?R (\<lambda>x. True)"
    by (rule exI[of _ "{}"]) (simp add: le_fun_def)
next
  fix P Q assume "?R P" then guess X ..
  moreover assume "?R Q" then guess Y ..
  ultimately show "?R (\<lambda>x. P x \<and> Q x)"
    by (intro exI[of _ "X \<union> Y"]) auto
next
  fix P Q
  assume "?R P" then guess X ..
  moreover assume "\<forall>x. P x \<longrightarrow> Q x"
  ultimately show "?R Q"
    by (intro exI[of _ X]) auto
qed

lemma eventually_filter_from_subbaseI: "P \<in> B \<Longrightarrow> eventually P (filter_from_subbase B)"
  by (subst eventually_filter_from_subbase) (auto intro!: exI[of _ "{P}"])

lemma filter_from_subbase_not_bot:
  "\<forall>X \<subseteq> B. finite X \<longrightarrow> Inf X \<noteq> bot \<Longrightarrow> filter_from_subbase B \<noteq> bot"
  unfolding trivial_limit_def eventually_filter_from_subbase by auto

lemma closure_iff_nhds_not_empty:
  "x \<in> closure X \<longleftrightarrow> (\<forall>A. \<forall>S\<subseteq>A. open S \<longrightarrow> x \<in> S \<longrightarrow> X \<inter> A \<noteq> {})"
proof safe
  assume x: "x \<in> closure X"
  fix S A assume "open S" "x \<in> S" "X \<inter> A = {}" "S \<subseteq> A"
  then have "x \<notin> closure (-S)" 
    by (auto simp: closure_complement subset_eq[symmetric] intro: interiorI)
  with x have "x \<in> closure X - closure (-S)"
    by auto
  also have "\<dots> \<subseteq> closure (X \<inter> S)"
    using `open S` open_inter_closure_subset[of S X] by (simp add: closed_Compl ac_simps)
  finally have "X \<inter> S \<noteq> {}" by auto
  then show False using `X \<inter> A = {}` `S \<subseteq> A` by auto
next
  assume "\<forall>A S. S \<subseteq> A \<longrightarrow> open S \<longrightarrow> x \<in> S \<longrightarrow> X \<inter> A \<noteq> {}"
  from this[THEN spec, of "- X", THEN spec, of "- closure X"]
  show "x \<in> closure X"
    by (simp add: closure_subset open_Compl)
qed

lemma compact_filter:
  "compact U \<longleftrightarrow> (\<forall>F. F \<noteq> bot \<longrightarrow> eventually (\<lambda>x. x \<in> U) F \<longrightarrow> (\<exists>x\<in>U. inf (nhds x) F \<noteq> bot))"
proof (intro allI iffI impI compact_fip[THEN iffD2] notI)
  fix F assume "compact U" and F: "F \<noteq> bot" "eventually (\<lambda>x. x \<in> U) F"
  from F have "U \<noteq> {}"
    by (auto simp: eventually_False)

  def Z \<equiv> "closure ` {A. eventually (\<lambda>x. x \<in> A) F}"
  then have "\<forall>z\<in>Z. closed z"
    by auto
  moreover 
  have ev_Z: "\<And>z. z \<in> Z \<Longrightarrow> eventually (\<lambda>x. x \<in> z) F"
    unfolding Z_def by (auto elim: eventually_elim1 intro: set_mp[OF closure_subset])
  have "(\<forall>B \<subseteq> Z. finite B \<longrightarrow> U \<inter> \<Inter>B \<noteq> {})"
  proof (intro allI impI)
    fix B assume "finite B" "B \<subseteq> Z"
    with `finite B` ev_Z have "eventually (\<lambda>x. \<forall>b\<in>B. x \<in> b) F"
      by (auto intro!: eventually_Ball_finite)
    with F(2) have "eventually (\<lambda>x. x \<in> U \<inter> (\<Inter>B)) F"
      by eventually_elim auto
    with F show "U \<inter> \<Inter>B \<noteq> {}"
      by (intro notI) (simp add: eventually_False)
  qed
  ultimately have "U \<inter> \<Inter>Z \<noteq> {}"
    using `compact U` unfolding compact_fip by blast
  then obtain x where "x \<in> U" and x: "\<And>z. z \<in> Z \<Longrightarrow> x \<in> z" by auto

  have "\<And>P. eventually P (inf (nhds x) F) \<Longrightarrow> P \<noteq> bot"
    unfolding eventually_inf eventually_nhds
  proof safe
    fix P Q R S
    assume "eventually R F" "open S" "x \<in> S"
    with open_inter_closure_eq_empty[of S "{x. R x}"] x[of "closure {x. R x}"]
    have "S \<inter> {x. R x} \<noteq> {}" by (auto simp: Z_def)
    moreover assume "Ball S Q" "\<forall>x. Q x \<and> R x \<longrightarrow> bot x"
    ultimately show False by (auto simp: set_eq_iff)
  qed
  with `x \<in> U` show "\<exists>x\<in>U. inf (nhds x) F \<noteq> bot"
    by (metis eventually_bot)
next
  fix A assume A: "\<forall>a\<in>A. closed a" "\<forall>B\<subseteq>A. finite B \<longrightarrow> U \<inter> \<Inter>B \<noteq> {}" "U \<inter> \<Inter>A = {}"

  def P' \<equiv> "(\<lambda>a (x::'a). x \<in> a)"
  then have inj_P': "\<And>A. inj_on P' A"
    by (auto intro!: inj_onI simp: fun_eq_iff)
  def F \<equiv> "filter_from_subbase (P' ` insert U A)"
  have "F \<noteq> bot"
    unfolding F_def
  proof (safe intro!: filter_from_subbase_not_bot)
    fix X assume "X \<subseteq> P' ` insert U A" "finite X" "Inf X = bot"
    then obtain B where "B \<subseteq> insert U A" "finite B" and B: "Inf (P' ` B) = bot"
      unfolding subset_image_iff by (auto intro: inj_P' finite_imageD)
    with A(2)[THEN spec, of "B - {U}"] have "U \<inter> \<Inter>(B - {U}) \<noteq> {}" by auto
    with B show False by (auto simp: P'_def fun_eq_iff)
  qed
  moreover have "eventually (\<lambda>x. x \<in> U) F"
    unfolding F_def by (rule eventually_filter_from_subbaseI) (auto simp: P'_def)
  moreover assume "\<forall>F. F \<noteq> bot \<longrightarrow> eventually (\<lambda>x. x \<in> U) F \<longrightarrow> (\<exists>x\<in>U. inf (nhds x) F \<noteq> bot)"
  ultimately obtain x where "x \<in> U" and x: "inf (nhds x) F \<noteq> bot"
    by auto

  { fix V assume "V \<in> A"
    then have V: "eventually (\<lambda>x. x \<in> V) F"
      by (auto simp add: F_def image_iff P'_def intro!: eventually_filter_from_subbaseI)
    have "x \<in> closure V"
      unfolding closure_iff_nhds_not_empty
    proof (intro impI allI)
      fix S A assume "open S" "x \<in> S" "S \<subseteq> A"
      then have "eventually (\<lambda>x. x \<in> A) (nhds x)" by (auto simp: eventually_nhds)
      with V have "eventually (\<lambda>x. x \<in> V \<inter> A) (inf (nhds x) F)"
        by (auto simp: eventually_inf)
      with x show "V \<inter> A \<noteq> {}"
        by (auto simp del: Int_iff simp add: trivial_limit_def)
    qed
    then have "x \<in> V"
      using `V \<in> A` A(1) by simp }
  with `x\<in>U` have "x \<in> U \<inter> \<Inter>A" by auto
  with `U \<inter> \<Inter>A = {}` show False by auto
qed

definition "countably_compact U \<longleftrightarrow>
    (\<forall>A. countable A \<longrightarrow> (\<forall>a\<in>A. open a) \<longrightarrow> U \<subseteq> \<Union>A \<longrightarrow> (\<exists>T\<subseteq>A. finite T \<and> U \<subseteq> \<Union>T))"

lemma countably_compactE:
  assumes "countably_compact s" and "\<forall>t\<in>C. open t" and "s \<subseteq> \<Union>C" "countable C"
  obtains C' where "C' \<subseteq> C" and "finite C'" and "s \<subseteq> \<Union>C'"
  using assms unfolding countably_compact_def by metis

lemma countably_compactI:
  assumes "\<And>C. \<forall>t\<in>C. open t \<Longrightarrow> s \<subseteq> \<Union>C \<Longrightarrow> countable C \<Longrightarrow> (\<exists>C'\<subseteq>C. finite C' \<and> s \<subseteq> \<Union>C')"
  shows "countably_compact s"
  using assms unfolding countably_compact_def by metis

lemma compact_imp_countably_compact: "compact U \<Longrightarrow> countably_compact U"
  by (auto simp: compact_eq_heine_borel countably_compact_def)

lemma countably_compact_imp_compact:
  assumes "countably_compact U"
  assumes ccover: "countable B" "\<forall>b\<in>B. open b"
  assumes basis: "\<And>T x. open T \<Longrightarrow> x \<in> T \<Longrightarrow> x \<in> U \<Longrightarrow> \<exists>b\<in>B. x \<in> b \<and> b \<inter> U \<subseteq> T"
  shows "compact U"
  using `countably_compact U` unfolding compact_eq_heine_borel countably_compact_def
proof safe
  fix A assume A: "\<forall>a\<in>A. open a" "U \<subseteq> \<Union>A"
  assume *: "\<forall>A. countable A \<longrightarrow> (\<forall>a\<in>A. open a) \<longrightarrow> U \<subseteq> \<Union>A \<longrightarrow> (\<exists>T\<subseteq>A. finite T \<and> U \<subseteq> \<Union>T)"

  moreover def C \<equiv> "{b\<in>B. \<exists>a\<in>A. b \<inter> U \<subseteq> a}"
  ultimately have "countable C" "\<forall>a\<in>C. open a"
    unfolding C_def using ccover by auto
  moreover
  have "\<Union>A \<inter> U \<subseteq> \<Union>C"
  proof safe
    fix x a assume "x \<in> U" "x \<in> a" "a \<in> A"
    with basis[of a x] A obtain b where "b \<in> B" "x \<in> b" "b \<inter> U \<subseteq> a" by blast
    with `a \<in> A` show "x \<in> \<Union>C" unfolding C_def
      by auto
  qed
  then have "U \<subseteq> \<Union>C" using `U \<subseteq> \<Union>A` by auto
  ultimately obtain T where "T\<subseteq>C" "finite T" "U \<subseteq> \<Union>T"
    using * by metis
  moreover then have "\<forall>t\<in>T. \<exists>a\<in>A. t \<inter> U \<subseteq> a"
    by (auto simp: C_def)
  then guess f unfolding bchoice_iff Bex_def ..
  ultimately show "\<exists>T\<subseteq>A. finite T \<and> U \<subseteq> \<Union>T"
    unfolding C_def by (intro exI[of _ "f`T"]) fastforce
qed

lemma countably_compact_imp_compact_second_countable:
  "countably_compact U \<Longrightarrow> compact (U :: 'a :: second_countable_topology set)"
proof (rule countably_compact_imp_compact)
  fix T and x :: 'a assume "open T" "x \<in> T"
  from topological_basisE[OF is_basis this] guess b .
  then show "\<exists>b\<in>SOME B. countable B \<and> topological_basis B. x \<in> b \<and> b \<inter> U \<subseteq> T" by auto
qed (insert countable_basis topological_basis_open[OF is_basis], auto)

lemma countably_compact_eq_compact:
  "countably_compact U \<longleftrightarrow> compact (U :: 'a :: second_countable_topology set)"
  using countably_compact_imp_compact_second_countable compact_imp_countably_compact by blast
  
subsubsection{* Sequential compactness *}

definition
  seq_compact :: "'a::topological_space set \<Rightarrow> bool" where
  "seq_compact S \<longleftrightarrow>
   (\<forall>f. (\<forall>n. f n \<in> S) \<longrightarrow>
       (\<exists>l\<in>S. \<exists>r. subseq r \<and> ((f o r) ---> l) sequentially))"

lemma seq_compact_imp_countably_compact:
  fixes U :: "'a :: first_countable_topology set"
  assumes "seq_compact U"
  shows "countably_compact U"
proof (safe intro!: countably_compactI)
  fix A assume A: "\<forall>a\<in>A. open a" "U \<subseteq> \<Union>A" "countable A"
  have subseq: "\<And>X. range X \<subseteq> U \<Longrightarrow> \<exists>r x. x \<in> U \<and> subseq r \<and> (X \<circ> r) ----> x"
    using `seq_compact U` by (fastforce simp: seq_compact_def subset_eq)
  show "\<exists>T\<subseteq>A. finite T \<and> U \<subseteq> \<Union>T"
  proof cases
    assume "finite A" with A show ?thesis by auto
  next
    assume "infinite A"
    then have "A \<noteq> {}" by auto
    show ?thesis
    proof (rule ccontr)
      assume "\<not> (\<exists>T\<subseteq>A. finite T \<and> U \<subseteq> \<Union>T)"
      then have "\<forall>T. \<exists>x. T \<subseteq> A \<and> finite T \<longrightarrow> (x \<in> U - \<Union>T)" by auto
      then obtain X' where T: "\<And>T. T \<subseteq> A \<Longrightarrow> finite T \<Longrightarrow> X' T \<in> U - \<Union>T" by metis
      def X \<equiv> "\<lambda>n. X' (from_nat_into A ` {.. n})"
      have X: "\<And>n. X n \<in> U - (\<Union>i\<le>n. from_nat_into A i)"
        using `A \<noteq> {}` unfolding X_def SUP_def by (intro T) (auto intro: from_nat_into)
      then have "range X \<subseteq> U" by auto
      with subseq[of X] obtain r x where "x \<in> U" and r: "subseq r" "(X \<circ> r) ----> x" by auto
      from `x\<in>U` `U \<subseteq> \<Union>A` from_nat_into_surj[OF `countable A`]
      obtain n where "x \<in> from_nat_into A n" by auto
      with r(2) A(1) from_nat_into[OF `A \<noteq> {}`, of n]
      have "eventually (\<lambda>i. X (r i) \<in> from_nat_into A n) sequentially"
        unfolding tendsto_def by (auto simp: comp_def)
      then obtain N where "\<And>i. N \<le> i \<Longrightarrow> X (r i) \<in> from_nat_into A n"
        by (auto simp: eventually_sequentially)
      moreover from X have "\<And>i. n \<le> r i \<Longrightarrow> X (r i) \<notin> from_nat_into A n"
        by auto
      moreover from `subseq r`[THEN seq_suble, of "max n N"] have "\<exists>i. n \<le> r i \<and> N \<le> i"
        by (auto intro!: exI[of _ "max n N"])
      ultimately show False
        by auto
    qed
  qed
qed

lemma compact_imp_seq_compact:
  fixes U :: "'a :: first_countable_topology set"
  assumes "compact U" shows "seq_compact U"
  unfolding seq_compact_def
proof safe
  fix X :: "nat \<Rightarrow> 'a" assume "\<forall>n. X n \<in> U"
  then have "eventually (\<lambda>x. x \<in> U) (filtermap X sequentially)"
    by (auto simp: eventually_filtermap)
  moreover have "filtermap X sequentially \<noteq> bot"
    by (simp add: trivial_limit_def eventually_filtermap)
  ultimately obtain x where "x \<in> U" and x: "inf (nhds x) (filtermap X sequentially) \<noteq> bot" (is "?F \<noteq> _")
    using `compact U` by (auto simp: compact_filter)

  from countable_basis_at_decseq[of x] guess A . note A = this
  def s \<equiv> "\<lambda>n i. SOME j. i < j \<and> X j \<in> A (Suc n)"
  { fix n i
    have "\<exists>a. i < a \<and> X a \<in> A (Suc n)"
    proof (rule ccontr)
      assume "\<not> (\<exists>a>i. X a \<in> A (Suc n))"
      then have "\<And>a. Suc i \<le> a \<Longrightarrow> X a \<notin> A (Suc n)" by auto
      then have "eventually (\<lambda>x. x \<notin> A (Suc n)) (filtermap X sequentially)"
        by (auto simp: eventually_filtermap eventually_sequentially)
      moreover have "eventually (\<lambda>x. x \<in> A (Suc n)) (nhds x)"
        using A(1,2)[of "Suc n"] by (auto simp: eventually_nhds)
      ultimately have "eventually (\<lambda>x. False) ?F"
        by (auto simp add: eventually_inf)
      with x show False
        by (simp add: eventually_False)
    qed
    then have "i < s n i" "X (s n i) \<in> A (Suc n)"
      unfolding s_def by (auto intro: someI2_ex) }
  note s = this
  def r \<equiv> "nat_rec (s 0 0) s"
  have "subseq r"
    by (auto simp: r_def s subseq_Suc_iff)
  moreover
  have "(\<lambda>n. X (r n)) ----> x"
  proof (rule topological_tendstoI)
    fix S assume "open S" "x \<in> S"
    with A(3) have "eventually (\<lambda>i. A i \<subseteq> S) sequentially" by auto
    moreover
    { fix i assume "Suc 0 \<le> i" then have "X (r i) \<in> A i"
        by (cases i) (simp_all add: r_def s) }
    then have "eventually (\<lambda>i. X (r i) \<in> A i) sequentially" by (auto simp: eventually_sequentially)
    ultimately show "eventually (\<lambda>i. X (r i) \<in> S) sequentially"
      by eventually_elim auto
  qed
  ultimately show "\<exists>x \<in> U. \<exists>r. subseq r \<and> (X \<circ> r) ----> x"
    using `x \<in> U` by (auto simp: convergent_def comp_def)
qed

lemma seq_compactI:
  assumes "\<And>f. \<forall>n. f n \<in> S \<Longrightarrow> \<exists>l\<in>S. \<exists>r. subseq r \<and> ((f o r) ---> l) sequentially"
  shows "seq_compact S"
  unfolding seq_compact_def using assms by fast

lemma seq_compactE:
  assumes "seq_compact S" "\<forall>n. f n \<in> S"
  obtains l r where "l \<in> S" "subseq r" "((f \<circ> r) ---> l) sequentially"
  using assms unfolding seq_compact_def by fast

lemma countably_compact_imp_acc_point:
  assumes "countably_compact s" "countable t" "infinite t"  "t \<subseteq> s"
  shows "\<exists>x\<in>s. \<forall>U. x\<in>U \<and> open U \<longrightarrow> infinite (U \<inter> t)"
proof (rule ccontr)
  def C \<equiv> "(\<lambda>F. interior (F \<union> (- t))) ` {F. finite F \<and> F \<subseteq> t }"  
  note `countably_compact s`
  moreover have "\<forall>t\<in>C. open t" 
    by (auto simp: C_def)
  moreover
  assume "\<not> (\<exists>x\<in>s. \<forall>U. x\<in>U \<and> open U \<longrightarrow> infinite (U \<inter> t))"
  then have s: "\<And>x. x \<in> s \<Longrightarrow> \<exists>U. x\<in>U \<and> open U \<and> finite (U \<inter> t)" by metis
  have "s \<subseteq> \<Union>C"
    using `t \<subseteq> s`
    unfolding C_def Union_image_eq
    apply (safe dest!: s)
    apply (rule_tac a="U \<inter> t" in UN_I)
    apply (auto intro!: interiorI simp add: finite_subset)
    done
  moreover
  from `countable t` have "countable C"
    unfolding C_def by (auto intro: countable_Collect_finite_subset)
  ultimately guess D by (rule countably_compactE)
  then obtain E where E: "E \<subseteq> {F. finite F \<and> F \<subseteq> t }" "finite E" and
    s: "s \<subseteq> (\<Union>F\<in>E. interior (F \<union> (- t)))"
    by (metis (lifting) Union_image_eq finite_subset_image C_def)
  from s `t \<subseteq> s` have "t \<subseteq> \<Union>E"
    using interior_subset by blast
  moreover have "finite (\<Union>E)"
    using E by auto
  ultimately show False using `infinite t` by (auto simp: finite_subset)
qed

lemma countable_acc_point_imp_seq_compact:
  fixes s :: "'a::first_countable_topology set"
  assumes "\<forall>t. infinite t \<and> countable t \<and> t \<subseteq> s --> (\<exists>x\<in>s. \<forall>U. x\<in>U \<and> open U \<longrightarrow> infinite (U \<inter> t))"
  shows "seq_compact s"
proof -
  { fix f :: "nat \<Rightarrow> 'a" assume f: "\<forall>n. f n \<in> s"
    have "\<exists>l\<in>s. \<exists>r. subseq r \<and> ((f \<circ> r) ---> l) sequentially"
    proof (cases "finite (range f)")
      case True
      obtain l where "infinite {n. f n = f l}"
        using pigeonhole_infinite[OF _ True] by auto
      then obtain r where "subseq r" and fr: "\<forall>n. f (r n) = f l"
        using infinite_enumerate by blast
      hence "subseq r \<and> (f \<circ> r) ----> f l"
        by (simp add: fr tendsto_const o_def)
      with f show "\<exists>l\<in>s. \<exists>r. subseq r \<and> (f \<circ> r) ----> l"
        by auto
    next
      case False
      with f assms have "\<exists>x\<in>s. \<forall>U. x\<in>U \<and> open U \<longrightarrow> infinite (U \<inter> range f)" by auto
      then obtain l where "l \<in> s" "\<forall>U. l\<in>U \<and> open U \<longrightarrow> infinite (U \<inter> range f)" ..
      from this(2) have "\<exists>r. subseq r \<and> ((f \<circ> r) ---> l) sequentially"
        using acc_point_range_imp_convergent_subsequence[of l f] by auto
      with `l \<in> s` show "\<exists>l\<in>s. \<exists>r. subseq r \<and> ((f \<circ> r) ---> l) sequentially" ..
    qed
  }
  thus ?thesis unfolding seq_compact_def by auto
qed

lemma seq_compact_eq_countably_compact:
  fixes U :: "'a :: first_countable_topology set"
  shows "seq_compact U \<longleftrightarrow> countably_compact U"
  using
    countable_acc_point_imp_seq_compact
    countably_compact_imp_acc_point
    seq_compact_imp_countably_compact
  by metis

lemma seq_compact_eq_acc_point:
  fixes s :: "'a :: first_countable_topology set"
  shows "seq_compact s \<longleftrightarrow> (\<forall>t. infinite t \<and> countable t \<and> t \<subseteq> s --> (\<exists>x\<in>s. \<forall>U. x\<in>U \<and> open U \<longrightarrow> infinite (U \<inter> t)))"
  using
    countable_acc_point_imp_seq_compact[of s]
    countably_compact_imp_acc_point[of s]
    seq_compact_imp_countably_compact[of s]
  by metis

lemma seq_compact_eq_compact:
  fixes U :: "'a :: second_countable_topology set"
  shows "seq_compact U \<longleftrightarrow> compact U"
  using seq_compact_eq_countably_compact countably_compact_eq_compact by blast

lemma bolzano_weierstrass_imp_seq_compact:
  fixes s :: "'a::{t1_space, first_countable_topology} set"
  shows "\<forall>t. infinite t \<and> t \<subseteq> s --> (\<exists>x \<in> s. x islimpt t) \<Longrightarrow> seq_compact s"
  by (rule countable_acc_point_imp_seq_compact) (metis islimpt_eq_acc_point)

subsubsection{* Total boundedness *}

lemma cauchy_def:
  "Cauchy s \<longleftrightarrow> (\<forall>e>0. \<exists>N. \<forall>m n. m \<ge> N \<and> n \<ge> N --> dist(s m)(s n) < e)"
unfolding Cauchy_def by blast

fun helper_1::"('a::metric_space set) \<Rightarrow> real \<Rightarrow> nat \<Rightarrow> 'a" where
  "helper_1 s e n = (SOME y::'a. y \<in> s \<and> (\<forall>m<n. \<not> (dist (helper_1 s e m) y < e)))"
declare helper_1.simps[simp del]

lemma seq_compact_imp_totally_bounded:
  assumes "seq_compact s"
  shows "\<forall>e>0. \<exists>k. finite k \<and> k \<subseteq> s \<and> s \<subseteq> (\<Union>((\<lambda>x. ball x e) ` k))"
proof(rule, rule, rule ccontr)
  fix e::real assume "e>0" and assm:"\<not> (\<exists>k. finite k \<and> k \<subseteq> s \<and> s \<subseteq> \<Union>(\<lambda>x. ball x e) ` k)"
  def x \<equiv> "helper_1 s e"
  { fix n
    have "x n \<in> s \<and> (\<forall>m<n. \<not> dist (x m) (x n) < e)"
    proof(induct_tac rule:nat_less_induct)
      fix n  def Q \<equiv> "(\<lambda>y. y \<in> s \<and> (\<forall>m<n. \<not> dist (x m) y < e))"
      assume as:"\<forall>m<n. x m \<in> s \<and> (\<forall>ma<m. \<not> dist (x ma) (x m) < e)"
      have "\<not> s \<subseteq> (\<Union>x\<in>x ` {0..<n}. ball x e)" using assm apply simp apply(erule_tac x="x ` {0 ..< n}" in allE) using as by auto
      then obtain z where z:"z\<in>s" "z \<notin> (\<Union>x\<in>x ` {0..<n}. ball x e)" unfolding subset_eq by auto
      have "Q (x n)" unfolding x_def and helper_1.simps[of s e n]
        apply(rule someI2[where a=z]) unfolding x_def[symmetric] and Q_def using z by auto
      thus "x n \<in> s \<and> (\<forall>m<n. \<not> dist (x m) (x n) < e)" unfolding Q_def by auto
    qed }
  hence "\<forall>n::nat. x n \<in> s" and x:"\<forall>n. \<forall>m < n. \<not> (dist (x m) (x n) < e)" by blast+
  then obtain l r where "l\<in>s" and r:"subseq r" and "((x \<circ> r) ---> l) sequentially" using assms(1)[unfolded seq_compact_def, THEN spec[where x=x]] by auto
  from this(3) have "Cauchy (x \<circ> r)" using LIMSEQ_imp_Cauchy by auto
  then obtain N::nat where N:"\<forall>m n. N \<le> m \<and> N \<le> n \<longrightarrow> dist ((x \<circ> r) m) ((x \<circ> r) n) < e" unfolding cauchy_def using `e>0` by auto
  show False
    using N[THEN spec[where x=N], THEN spec[where x="N+1"]]
    using r[unfolded subseq_def, THEN spec[where x=N], THEN spec[where x="N+1"]]
    using x[THEN spec[where x="r (N+1)"], THEN spec[where x="r (N)"]] by auto
qed

subsubsection{* Heine-Borel theorem *}

lemma seq_compact_imp_heine_borel:
  fixes s :: "'a :: metric_space set"
  assumes "seq_compact s" shows "compact s"
proof -
  from seq_compact_imp_totally_bounded[OF `seq_compact s`]
  guess f unfolding choice_iff' .. note f = this
  def K \<equiv> "(\<lambda>(x, r). ball x r) ` ((\<Union>e \<in> \<rat> \<inter> {0 <..}. f e) \<times> \<rat>)"
  have "countably_compact s"
    using `seq_compact s` by (rule seq_compact_imp_countably_compact)
  then show "compact s"
  proof (rule countably_compact_imp_compact)
    show "countable K"
      unfolding K_def using f
      by (auto intro: countable_finite countable_subset countable_rat
               intro!: countable_image countable_SIGMA countable_UN)
    show "\<forall>b\<in>K. open b" by (auto simp: K_def)
  next
    fix T x assume T: "open T" "x \<in> T" and x: "x \<in> s"
    from openE[OF T] obtain e where "0 < e" "ball x e \<subseteq> T" by auto
    then have "0 < e / 2" "ball x (e / 2) \<subseteq> T" by auto
    from Rats_dense_in_real[OF `0 < e / 2`] obtain r where "r \<in> \<rat>" "0 < r" "r < e / 2" by auto
    from f[rule_format, of r] `0 < r` `x \<in> s` obtain k where "k \<in> f r" "x \<in> ball k r"
      unfolding Union_image_eq by auto
    from `r \<in> \<rat>` `0 < r` `k \<in> f r` have "ball k r \<in> K" by (auto simp: K_def)
    then show "\<exists>b\<in>K. x \<in> b \<and> b \<inter> s \<subseteq> T"
    proof (rule bexI[rotated], safe)
      fix y assume "y \<in> ball k r"
      with `r < e / 2` `x \<in> ball k r` have "dist x y < e"
        by (intro dist_double[where x = k and d=e]) (auto simp: dist_commute)
      with `ball x e \<subseteq> T` show "y \<in> T" by auto
    qed (rule `x \<in> ball k r`)
  qed
qed

lemma compact_eq_seq_compact_metric:
  "compact (s :: 'a::metric_space set) \<longleftrightarrow> seq_compact s"
  using compact_imp_seq_compact seq_compact_imp_heine_borel by blast

lemma compact_def:
  "compact (S :: 'a::metric_space set) \<longleftrightarrow>
   (\<forall>f. (\<forall>n. f n \<in> S) \<longrightarrow> (\<exists>l\<in>S. \<exists>r. subseq r \<and> (f o r) ----> l))"
  unfolding compact_eq_seq_compact_metric seq_compact_def by auto

subsubsection {* Complete the chain of compactness variants *}

lemma compact_eq_bolzano_weierstrass:
  fixes s :: "'a::metric_space set"
  shows "compact s \<longleftrightarrow> (\<forall>t. infinite t \<and> t \<subseteq> s --> (\<exists>x \<in> s. x islimpt t))" (is "?lhs = ?rhs")
proof
  assume ?lhs thus ?rhs using heine_borel_imp_bolzano_weierstrass[of s] by auto
next
  assume ?rhs thus ?lhs
    unfolding compact_eq_seq_compact_metric by (rule bolzano_weierstrass_imp_seq_compact)
qed

lemma bolzano_weierstrass_imp_bounded:
  "\<forall>t. infinite t \<and> t \<subseteq> s --> (\<exists>x \<in> s. x islimpt t) \<Longrightarrow> bounded s"
  using compact_imp_bounded unfolding compact_eq_bolzano_weierstrass .

text {*
  A metric space (or topological vector space) is said to have the
  Heine-Borel property if every closed and bounded subset is compact.
*}

class heine_borel = metric_space +
  assumes bounded_imp_convergent_subsequence:
    "bounded s \<Longrightarrow> \<forall>n. f n \<in> s
      \<Longrightarrow> \<exists>l r. subseq r \<and> ((f \<circ> r) ---> l) sequentially"

lemma bounded_closed_imp_seq_compact:
  fixes s::"'a::heine_borel set"
  assumes "bounded s" and "closed s" shows "seq_compact s"
proof (unfold seq_compact_def, clarify)
  fix f :: "nat \<Rightarrow> 'a" assume f: "\<forall>n. f n \<in> s"
  obtain l r where r: "subseq r" and l: "((f \<circ> r) ---> l) sequentially"
    using bounded_imp_convergent_subsequence [OF `bounded s` `\<forall>n. f n \<in> s`] by auto
  from f have fr: "\<forall>n. (f \<circ> r) n \<in> s" by simp
  have "l \<in> s" using `closed s` fr l
    unfolding closed_sequential_limits by blast
  show "\<exists>l\<in>s. \<exists>r. subseq r \<and> ((f \<circ> r) ---> l) sequentially"
    using `l \<in> s` r l by blast
qed

lemma compact_eq_bounded_closed:
  fixes s :: "'a::heine_borel set"
  shows "compact s \<longleftrightarrow> bounded s \<and> closed s"  (is "?lhs = ?rhs")
proof
  assume ?lhs thus ?rhs
    using compact_imp_closed compact_imp_bounded by blast
next
  assume ?rhs thus ?lhs
    using bounded_closed_imp_seq_compact[of s] unfolding compact_eq_seq_compact_metric by auto
qed

(* TODO: is this lemma necessary? *)
lemma bounded_increasing_convergent:
  fixes s :: "nat \<Rightarrow> real"
  shows "bounded {s n| n. True} \<Longrightarrow> \<forall>n. s n \<le> s (Suc n) \<Longrightarrow> \<exists>l. s ----> l"
  using Bseq_mono_convergent[of s] incseq_Suc_iff[of s]
  by (auto simp: image_def Bseq_eq_bounded convergent_def incseq_def)

instance real :: heine_borel
proof
  fix s :: "real set" and f :: "nat \<Rightarrow> real"
  assume s: "bounded s" and f: "\<forall>n. f n \<in> s"
  obtain r where r: "subseq r" "monoseq (f \<circ> r)"
    unfolding comp_def by (metis seq_monosub)
  moreover
  then have "Bseq (f \<circ> r)"
    unfolding Bseq_eq_bounded using s f by (auto intro: bounded_subset)
  ultimately show "\<exists>l r. subseq r \<and> (f \<circ> r) ----> l"
    using Bseq_monoseq_convergent[of "f \<circ> r"] by (auto simp: convergent_def)
qed

lemma compact_lemma:
  fixes f :: "nat \<Rightarrow> 'a::euclidean_space"
  assumes "bounded s" and "\<forall>n. f n \<in> s"
  shows "\<forall>d\<subseteq>Basis. \<exists>l::'a. \<exists> r. subseq r \<and>
        (\<forall>e>0. eventually (\<lambda>n. \<forall>i\<in>d. dist (f (r n) \<bullet> i) (l \<bullet> i) < e) sequentially)"
proof safe
  fix d :: "'a set" assume d: "d \<subseteq> Basis" 
  with finite_Basis have "finite d" by (blast intro: finite_subset)
  from this d show "\<exists>l::'a. \<exists>r. subseq r \<and>
      (\<forall>e>0. eventually (\<lambda>n. \<forall>i\<in>d. dist (f (r n) \<bullet> i) (l \<bullet> i) < e) sequentially)"
  proof(induct d) case empty thus ?case unfolding subseq_def by auto
  next case (insert k d) have k[intro]:"k\<in>Basis" using insert by auto
    have s': "bounded ((\<lambda>x. x \<bullet> k) ` s)" using `bounded s`
      by (auto intro!: bounded_linear_image bounded_linear_inner_left)
    obtain l1::"'a" and r1 where r1:"subseq r1" and
      lr1:"\<forall>e>0. eventually (\<lambda>n. \<forall>i\<in>d. dist (f (r1 n) \<bullet> i) (l1 \<bullet> i) < e) sequentially"
      using insert(3) using insert(4) by auto
    have f': "\<forall>n. f (r1 n) \<bullet> k \<in> (\<lambda>x. x \<bullet> k) ` s" using `\<forall>n. f n \<in> s` by simp
    obtain l2 r2 where r2:"subseq r2" and lr2:"((\<lambda>i. f (r1 (r2 i)) \<bullet> k) ---> l2) sequentially"
      using bounded_imp_convergent_subsequence[OF s' f'] unfolding o_def by auto
    def r \<equiv> "r1 \<circ> r2" have r:"subseq r"
      using r1 and r2 unfolding r_def o_def subseq_def by auto
    moreover
    def l \<equiv> "(\<Sum>i\<in>Basis. (if i = k then l2 else l1\<bullet>i) *\<^sub>R i)::'a"
    { fix e::real assume "e>0"
      from lr1 `e>0` have N1:"eventually (\<lambda>n. \<forall>i\<in>d. dist (f (r1 n) \<bullet> i) (l1 \<bullet> i) < e) sequentially" by blast
      from lr2 `e>0` have N2:"eventually (\<lambda>n. dist (f (r1 (r2 n)) \<bullet> k) l2 < e) sequentially" by (rule tendstoD)
      from r2 N1 have N1': "eventually (\<lambda>n. \<forall>i\<in>d. dist (f (r1 (r2 n)) \<bullet> i) (l1 \<bullet> i) < e) sequentially"
        by (rule eventually_subseq)
      have "eventually (\<lambda>n. \<forall>i\<in>(insert k d). dist (f (r n) \<bullet> i) (l \<bullet> i) < e) sequentially"
        using N1' N2 
        by eventually_elim (insert insert.prems, auto simp: l_def r_def o_def)
    }
    ultimately show ?case by auto
  qed
qed

instance euclidean_space \<subseteq> heine_borel
proof
  fix s :: "'a set" and f :: "nat \<Rightarrow> 'a"
  assume s: "bounded s" and f: "\<forall>n. f n \<in> s"
  then obtain l::'a and r where r: "subseq r"
    and l: "\<forall>e>0. eventually (\<lambda>n. \<forall>i\<in>Basis. dist (f (r n) \<bullet> i) (l \<bullet> i) < e) sequentially"
    using compact_lemma [OF s f] by blast
  { fix e::real assume "e>0"
    hence "0 < e / real_of_nat DIM('a)" by (auto intro!: divide_pos_pos DIM_positive)
    with l have "eventually (\<lambda>n. \<forall>i\<in>Basis. dist (f (r n) \<bullet> i) (l \<bullet> i) < e / (real_of_nat DIM('a))) sequentially"
      by simp
    moreover
    { fix n assume n: "\<forall>i\<in>Basis. dist (f (r n) \<bullet> i) (l \<bullet> i) < e / (real_of_nat DIM('a))"
      have "dist (f (r n)) l \<le> (\<Sum>i\<in>Basis. dist (f (r n) \<bullet> i) (l \<bullet> i))"
        apply(subst euclidean_dist_l2) using zero_le_dist by (rule setL2_le_setsum)
      also have "\<dots> < (\<Sum>i\<in>(Basis::'a set). e / (real_of_nat DIM('a)))"
        apply(rule setsum_strict_mono) using n by auto
      finally have "dist (f (r n)) l < e" 
        by auto
    }
    ultimately have "eventually (\<lambda>n. dist (f (r n)) l < e) sequentially"
      by (rule eventually_elim1)
  }
  hence *:"((f \<circ> r) ---> l) sequentially" unfolding o_def tendsto_iff by simp
  with r show "\<exists>l r. subseq r \<and> ((f \<circ> r) ---> l) sequentially" by auto
qed

lemma bounded_fst: "bounded s \<Longrightarrow> bounded (fst ` s)"
unfolding bounded_def
apply clarify
apply (rule_tac x="a" in exI)
apply (rule_tac x="e" in exI)
apply clarsimp
apply (drule (1) bspec)
apply (simp add: dist_Pair_Pair)
apply (erule order_trans [OF real_sqrt_sum_squares_ge1])
done

lemma bounded_snd: "bounded s \<Longrightarrow> bounded (snd ` s)"
unfolding bounded_def
apply clarify
apply (rule_tac x="b" in exI)
apply (rule_tac x="e" in exI)
apply clarsimp
apply (drule (1) bspec)
apply (simp add: dist_Pair_Pair)
apply (erule order_trans [OF real_sqrt_sum_squares_ge2])
done

instance prod :: (heine_borel, heine_borel) heine_borel
proof
  fix s :: "('a * 'b) set" and f :: "nat \<Rightarrow> 'a * 'b"
  assume s: "bounded s" and f: "\<forall>n. f n \<in> s"
  from s have s1: "bounded (fst ` s)" by (rule bounded_fst)
  from f have f1: "\<forall>n. fst (f n) \<in> fst ` s" by simp
  obtain l1 r1 where r1: "subseq r1"
    and l1: "((\<lambda>n. fst (f (r1 n))) ---> l1) sequentially"
    using bounded_imp_convergent_subsequence [OF s1 f1]
    unfolding o_def by fast
  from s have s2: "bounded (snd ` s)" by (rule bounded_snd)
  from f have f2: "\<forall>n. snd (f (r1 n)) \<in> snd ` s" by simp
  obtain l2 r2 where r2: "subseq r2"
    and l2: "((\<lambda>n. snd (f (r1 (r2 n)))) ---> l2) sequentially"
    using bounded_imp_convergent_subsequence [OF s2 f2]
    unfolding o_def by fast
  have l1': "((\<lambda>n. fst (f (r1 (r2 n)))) ---> l1) sequentially"
    using LIMSEQ_subseq_LIMSEQ [OF l1 r2] unfolding o_def .
  have l: "((f \<circ> (r1 \<circ> r2)) ---> (l1, l2)) sequentially"
    using tendsto_Pair [OF l1' l2] unfolding o_def by simp
  have r: "subseq (r1 \<circ> r2)"
    using r1 r2 unfolding subseq_def by simp
  show "\<exists>l r. subseq r \<and> ((f \<circ> r) ---> l) sequentially"
    using l r by fast
qed

subsubsection{* Completeness *}

definition complete :: "'a::metric_space set \<Rightarrow> bool" where
  "complete s \<longleftrightarrow> (\<forall>f. (\<forall>n. f n \<in> s) \<and> Cauchy f \<longrightarrow> (\<exists>l\<in>s. f ----> l))"

lemma compact_imp_complete: assumes "compact s" shows "complete s"
proof-
  { fix f assume as: "(\<forall>n::nat. f n \<in> s)" "Cauchy f"
    from as(1) obtain l r where lr: "l\<in>s" "subseq r" "(f \<circ> r) ----> l"
      using assms unfolding compact_def by blast

    note lr' = seq_suble [OF lr(2)]

    { fix e::real assume "e>0"
      from as(2) obtain N where N:"\<forall>m n. N \<le> m \<and> N \<le> n \<longrightarrow> dist (f m) (f n) < e/2" unfolding cauchy_def using `e>0` apply (erule_tac x="e/2" in allE) by auto
      from lr(3)[unfolded LIMSEQ_def, THEN spec[where x="e/2"]] obtain M where M:"\<forall>n\<ge>M. dist ((f \<circ> r) n) l < e/2" using `e>0` by auto
      { fix n::nat assume n:"n \<ge> max N M"
        have "dist ((f \<circ> r) n) l < e/2" using n M by auto
        moreover have "r n \<ge> N" using lr'[of n] n by auto
        hence "dist (f n) ((f \<circ> r) n) < e / 2" using N using n by auto
        ultimately have "dist (f n) l < e" using dist_triangle_half_r[of "f (r n)" "f n" e l] by (auto simp add: dist_commute)  }
      hence "\<exists>N. \<forall>n\<ge>N. dist (f n) l < e" by blast  }
    hence "\<exists>l\<in>s. (f ---> l) sequentially" using `l\<in>s` unfolding LIMSEQ_def by auto  }
  thus ?thesis unfolding complete_def by auto
qed

lemma nat_approx_posE:
  fixes e::real
  assumes "0 < e"
  obtains n::nat where "1 / (Suc n) < e"
proof atomize_elim
  have " 1 / real (Suc (nat (ceiling (1/e)))) < 1 / (ceiling (1/e))"
    by (rule divide_strict_left_mono) (auto intro!: mult_pos_pos simp: `0 < e`)
  also have "1 / (ceiling (1/e)) \<le> 1 / (1/e)"
    by (rule divide_left_mono) (auto intro!: divide_pos_pos simp: `0 < e`)
  also have "\<dots> = e" by simp
  finally show  "\<exists>n. 1 / real (Suc n) < e" ..
qed

lemma compact_eq_totally_bounded:
  "compact s \<longleftrightarrow> complete s \<and> (\<forall>e>0. \<exists>k. finite k \<and> s \<subseteq> (\<Union>((\<lambda>x. ball x e) ` k)))"
    (is "_ \<longleftrightarrow> ?rhs")
proof
  assume assms: "?rhs"
  then obtain k where k: "\<And>e. 0 < e \<Longrightarrow> finite (k e)" "\<And>e. 0 < e \<Longrightarrow> s \<subseteq> (\<Union>x\<in>k e. ball x e)"
    by (auto simp: choice_iff')

  show "compact s"
  proof cases
    assume "s = {}" thus "compact s" by (simp add: compact_def)
  next
    assume "s \<noteq> {}"
    show ?thesis
      unfolding compact_def
    proof safe
      fix f :: "nat \<Rightarrow> 'a" assume f: "\<forall>n. f n \<in> s"
      
      def e \<equiv> "\<lambda>n. 1 / (2 * Suc n)"
      then have [simp]: "\<And>n. 0 < e n" by auto
      def B \<equiv> "\<lambda>n U. SOME b. infinite {n. f n \<in> b} \<and> (\<exists>x. b \<subseteq> ball x (e n) \<inter> U)"
      { fix n U assume "infinite {n. f n \<in> U}"
        then have "\<exists>b\<in>k (e n). infinite {i\<in>{n. f n \<in> U}. f i \<in> ball b (e n)}"
          using k f by (intro pigeonhole_infinite_rel) (auto simp: subset_eq)
        then guess a ..
        then have "\<exists>b. infinite {i. f i \<in> b} \<and> (\<exists>x. b \<subseteq> ball x (e n) \<inter> U)"
          by (intro exI[of _ "ball a (e n) \<inter> U"] exI[of _ a]) (auto simp: ac_simps)
        from someI_ex[OF this]
        have "infinite {i. f i \<in> B n U}" "\<exists>x. B n U \<subseteq> ball x (e n) \<inter> U"
          unfolding B_def by auto }
      note B = this

      def F \<equiv> "nat_rec (B 0 UNIV) B"
      { fix n have "infinite {i. f i \<in> F n}"
          by (induct n) (auto simp: F_def B) }
      then have F: "\<And>n. \<exists>x. F (Suc n) \<subseteq> ball x (e n) \<inter> F n"
        using B by (simp add: F_def)
      then have F_dec: "\<And>m n. m \<le> n \<Longrightarrow> F n \<subseteq> F m"
        using decseq_SucI[of F] by (auto simp: decseq_def)

      obtain sel where sel: "\<And>k i. i < sel k i" "\<And>k i. f (sel k i) \<in> F k"
      proof (atomize_elim, unfold all_conj_distrib[symmetric], intro choice allI)
        fix k i
        have "infinite ({n. f n \<in> F k} - {.. i})"
          using `infinite {n. f n \<in> F k}` by auto
        from infinite_imp_nonempty[OF this]
        show "\<exists>x>i. f x \<in> F k"
          by (simp add: set_eq_iff not_le conj_commute)
      qed

      def t \<equiv> "nat_rec (sel 0 0) (\<lambda>n i. sel (Suc n) i)"
      have "subseq t"
        unfolding subseq_Suc_iff by (simp add: t_def sel)
      moreover have "\<forall>i. (f \<circ> t) i \<in> s"
        using f by auto
      moreover
      { fix n have "(f \<circ> t) n \<in> F n"
          by (cases n) (simp_all add: t_def sel) }
      note t = this

      have "Cauchy (f \<circ> t)"
      proof (safe intro!: metric_CauchyI exI elim!: nat_approx_posE)
        fix r :: real and N n m assume "1 / Suc N < r" "Suc N \<le> n" "Suc N \<le> m"
        then have "(f \<circ> t) n \<in> F (Suc N)" "(f \<circ> t) m \<in> F (Suc N)" "2 * e N < r"
          using F_dec t by (auto simp: e_def field_simps real_of_nat_Suc)
        with F[of N] obtain x where "dist x ((f \<circ> t) n) < e N" "dist x ((f \<circ> t) m) < e N"
          by (auto simp: subset_eq)
        with dist_triangle[of "(f \<circ> t) m" "(f \<circ> t) n" x] `2 * e N < r`
        show "dist ((f \<circ> t) m) ((f \<circ> t) n) < r"
          by (simp add: dist_commute)
      qed

      ultimately show "\<exists>l\<in>s. \<exists>r. subseq r \<and> (f \<circ> r) ----> l"
        using assms unfolding complete_def by blast
    qed
  qed
qed (metis compact_imp_complete compact_imp_seq_compact seq_compact_imp_totally_bounded)

lemma cauchy: "Cauchy s \<longleftrightarrow> (\<forall>e>0.\<exists> N::nat. \<forall>n\<ge>N. dist(s n)(s N) < e)" (is "?lhs = ?rhs")
proof-
  { assume ?rhs
    { fix e::real
      assume "e>0"
      with `?rhs` obtain N where N:"\<forall>n\<ge>N. dist (s n) (s N) < e/2"
        by (erule_tac x="e/2" in allE) auto
      { fix n m
        assume nm:"N \<le> m \<and> N \<le> n"
        hence "dist (s m) (s n) < e" using N
          using dist_triangle_half_l[of "s m" "s N" "e" "s n"]
          by blast
      }
      hence "\<exists>N. \<forall>m n. N \<le> m \<and> N \<le> n \<longrightarrow> dist (s m) (s n) < e"
        by blast
    }
    hence ?lhs
      unfolding cauchy_def
      by blast
  }
  thus ?thesis
    unfolding cauchy_def
    using dist_triangle_half_l
    by blast
qed

lemma cauchy_imp_bounded: assumes "Cauchy s" shows "bounded (range s)"
proof-
  from assms obtain N::nat where "\<forall>m n. N \<le> m \<and> N \<le> n \<longrightarrow> dist (s m) (s n) < 1" unfolding cauchy_def apply(erule_tac x= 1 in allE) by auto
  hence N:"\<forall>n. N \<le> n \<longrightarrow> dist (s N) (s n) < 1" by auto
  moreover
  have "bounded (s ` {0..N})" using finite_imp_bounded[of "s ` {1..N}"] by auto
  then obtain a where a:"\<forall>x\<in>s ` {0..N}. dist (s N) x \<le> a"
    unfolding bounded_any_center [where a="s N"] by auto
  ultimately show "?thesis"
    unfolding bounded_any_center [where a="s N"]
    apply(rule_tac x="max a 1" in exI) apply auto
    apply(erule_tac x=y in allE) apply(erule_tac x=y in ballE) by auto
qed

instance heine_borel < complete_space
proof
  fix f :: "nat \<Rightarrow> 'a" assume "Cauchy f"
  hence "bounded (range f)"
    by (rule cauchy_imp_bounded)
  hence "compact (closure (range f))"
    unfolding compact_eq_bounded_closed by auto
  hence "complete (closure (range f))"
    by (rule compact_imp_complete)
  moreover have "\<forall>n. f n \<in> closure (range f)"
    using closure_subset [of "range f"] by auto
  ultimately have "\<exists>l\<in>closure (range f). (f ---> l) sequentially"
    using `Cauchy f` unfolding complete_def by auto
  then show "convergent f"
    unfolding convergent_def by auto
qed

instance euclidean_space \<subseteq> banach ..

lemma complete_univ: "complete (UNIV :: 'a::complete_space set)"
proof(simp add: complete_def, rule, rule)
  fix f :: "nat \<Rightarrow> 'a" assume "Cauchy f"
  hence "convergent f" by (rule Cauchy_convergent)
  thus "\<exists>l. f ----> l" unfolding convergent_def .  
qed

lemma complete_imp_closed: assumes "complete s" shows "closed s"
proof -
  { fix x assume "x islimpt s"
    then obtain f where f: "\<forall>n. f n \<in> s - {x}" "(f ---> x) sequentially"
      unfolding islimpt_sequential by auto
    then obtain l where l: "l\<in>s" "(f ---> l) sequentially"
      using `complete s`[unfolded complete_def] using LIMSEQ_imp_Cauchy[of f x] by auto
    hence "x \<in> s"  using tendsto_unique[of sequentially f l x] trivial_limit_sequentially f(2) by auto
  }
  thus "closed s" unfolding closed_limpt by auto
qed

lemma complete_eq_closed:
  fixes s :: "'a::complete_space set"
  shows "complete s \<longleftrightarrow> closed s" (is "?lhs = ?rhs")
proof
  assume ?lhs thus ?rhs by (rule complete_imp_closed)
next
  assume ?rhs
  { fix f assume as:"\<forall>n::nat. f n \<in> s" "Cauchy f"
    then obtain l where "(f ---> l) sequentially" using complete_univ[unfolded complete_def, THEN spec[where x=f]] by auto
    hence "\<exists>l\<in>s. (f ---> l) sequentially" using `?rhs`[unfolded closed_sequential_limits, THEN spec[where x=f], THEN spec[where x=l]] using as(1) by auto  }
  thus ?lhs unfolding complete_def by auto
qed

lemma convergent_eq_cauchy:
  fixes s :: "nat \<Rightarrow> 'a::complete_space"
  shows "(\<exists>l. (s ---> l) sequentially) \<longleftrightarrow> Cauchy s"
  unfolding Cauchy_convergent_iff convergent_def ..

lemma convergent_imp_bounded:
  fixes s :: "nat \<Rightarrow> 'a::metric_space"
  shows "(s ---> l) sequentially \<Longrightarrow> bounded (range s)"
  by (intro cauchy_imp_bounded LIMSEQ_imp_Cauchy)

lemma compact_cball[simp]:
  fixes x :: "'a::heine_borel"
  shows "compact(cball x e)"
  using compact_eq_bounded_closed bounded_cball closed_cball
  by blast

lemma compact_frontier_bounded[intro]:
  fixes s :: "'a::heine_borel set"
  shows "bounded s ==> compact(frontier s)"
  unfolding frontier_def
  using compact_eq_bounded_closed
  by blast

lemma compact_frontier[intro]:
  fixes s :: "'a::heine_borel set"
  shows "compact s ==> compact (frontier s)"
  using compact_eq_bounded_closed compact_frontier_bounded
  by blast

lemma frontier_subset_compact:
  fixes s :: "'a::heine_borel set"
  shows "compact s ==> frontier s \<subseteq> s"
  using frontier_subset_closed compact_eq_bounded_closed
  by blast

subsection {* Bounded closed nest property (proof does not use Heine-Borel) *}

lemma bounded_closed_nest:
  assumes "\<forall>n. closed(s n)" "\<forall>n. (s n \<noteq> {})"
  "(\<forall>m n. m \<le> n --> s n \<subseteq> s m)"  "bounded(s 0)"
  shows "\<exists>a::'a::heine_borel. \<forall>n::nat. a \<in> s(n)"
proof-
  from assms(2) obtain x where x:"\<forall>n::nat. x n \<in> s n" using choice[of "\<lambda>n x. x\<in> s n"] by auto
  from assms(4,1) have *:"seq_compact (s 0)" using bounded_closed_imp_seq_compact[of "s 0"] by auto

  then obtain l r where lr:"l\<in>s 0" "subseq r" "((x \<circ> r) ---> l) sequentially"
    unfolding seq_compact_def apply(erule_tac x=x in allE)  using x using assms(3) by blast

  { fix n::nat
    { fix e::real assume "e>0"
      with lr(3) obtain N where N:"\<forall>m\<ge>N. dist ((x \<circ> r) m) l < e" unfolding LIMSEQ_def by auto
      hence "dist ((x \<circ> r) (max N n)) l < e" by auto
      moreover
      have "r (max N n) \<ge> n" using lr(2) using seq_suble[of r "max N n"] by auto
      hence "(x \<circ> r) (max N n) \<in> s n"
        using x apply(erule_tac x=n in allE)
        using x apply(erule_tac x="r (max N n)" in allE)
        using assms(3) apply(erule_tac x=n in allE) apply(erule_tac x="r (max N n)" in allE) by auto
      ultimately have "\<exists>y\<in>s n. dist y l < e" by auto
    }
    hence "l \<in> s n" using closed_approachable[of "s n" l] assms(1) by blast
  }
  thus ?thesis by auto
qed

text {* Decreasing case does not even need compactness, just completeness. *}

lemma decreasing_closed_nest:
  assumes "\<forall>n. closed(s n)"
          "\<forall>n. (s n \<noteq> {})"
          "\<forall>m n. m \<le> n --> s n \<subseteq> s m"
          "\<forall>e>0. \<exists>n. \<forall>x \<in> (s n). \<forall> y \<in> (s n). dist x y < e"
  shows "\<exists>a::'a::complete_space. \<forall>n::nat. a \<in> s n"
proof-
  have "\<forall>n. \<exists> x. x\<in>s n" using assms(2) by auto
  hence "\<exists>t. \<forall>n. t n \<in> s n" using choice[of "\<lambda> n x. x \<in> s n"] by auto
  then obtain t where t: "\<forall>n. t n \<in> s n" by auto
  { fix e::real assume "e>0"
    then obtain N where N:"\<forall>x\<in>s N. \<forall>y\<in>s N. dist x y < e" using assms(4) by auto
    { fix m n ::nat assume "N \<le> m \<and> N \<le> n"
      hence "t m \<in> s N" "t n \<in> s N" using assms(3) t unfolding  subset_eq t by blast+
      hence "dist (t m) (t n) < e" using N by auto
    }
    hence "\<exists>N. \<forall>m n. N \<le> m \<and> N \<le> n \<longrightarrow> dist (t m) (t n) < e" by auto
  }
  hence  "Cauchy t" unfolding cauchy_def by auto
  then obtain l where l:"(t ---> l) sequentially" using complete_univ unfolding complete_def by auto
  { fix n::nat
    { fix e::real assume "e>0"
      then obtain N::nat where N:"\<forall>n\<ge>N. dist (t n) l < e" using l[unfolded LIMSEQ_def] by auto
      have "t (max n N) \<in> s n" using assms(3) unfolding subset_eq apply(erule_tac x=n in allE) apply (erule_tac x="max n N" in allE) using t by auto
      hence "\<exists>y\<in>s n. dist y l < e" apply(rule_tac x="t (max n N)" in bexI) using N by auto
    }
    hence "l \<in> s n" using closed_approachable[of "s n" l] assms(1) by auto
  }
  then show ?thesis by auto
qed

text {* Strengthen it to the intersection actually being a singleton. *}

lemma decreasing_closed_nest_sing:
  fixes s :: "nat \<Rightarrow> 'a::complete_space set"
  assumes "\<forall>n. closed(s n)"
          "\<forall>n. s n \<noteq> {}"
          "\<forall>m n. m \<le> n --> s n \<subseteq> s m"
          "\<forall>e>0. \<exists>n. \<forall>x \<in> (s n). \<forall> y\<in>(s n). dist x y < e"
  shows "\<exists>a. \<Inter>(range s) = {a}"
proof-
  obtain a where a:"\<forall>n. a \<in> s n" using decreasing_closed_nest[of s] using assms by auto
  { fix b assume b:"b \<in> \<Inter>(range s)"
    { fix e::real assume "e>0"
      hence "dist a b < e" using assms(4 )using b using a by blast
    }
    hence "dist a b = 0" by (metis dist_eq_0_iff dist_nz less_le)
  }
  with a have "\<Inter>(range s) = {a}" unfolding image_def by auto
  thus ?thesis ..
qed

text{* Cauchy-type criteria for uniform convergence. *}

lemma uniformly_convergent_eq_cauchy: fixes s::"nat \<Rightarrow> 'b \<Rightarrow> 'a::heine_borel" shows
 "(\<exists>l. \<forall>e>0. \<exists>N. \<forall>n x. N \<le> n \<and> P x --> dist(s n x)(l x) < e) \<longleftrightarrow>
  (\<forall>e>0. \<exists>N. \<forall>m n x. N \<le> m \<and> N \<le> n \<and> P x  --> dist (s m x) (s n x) < e)" (is "?lhs = ?rhs")
proof(rule)
  assume ?lhs
  then obtain l where l:"\<forall>e>0. \<exists>N. \<forall>n x. N \<le> n \<and> P x \<longrightarrow> dist (s n x) (l x) < e" by auto
  { fix e::real assume "e>0"
    then obtain N::nat where N:"\<forall>n x. N \<le> n \<and> P x \<longrightarrow> dist (s n x) (l x) < e / 2" using l[THEN spec[where x="e/2"]] by auto
    { fix n m::nat and x::"'b" assume "N \<le> m \<and> N \<le> n \<and> P x"
      hence "dist (s m x) (s n x) < e"
        using N[THEN spec[where x=m], THEN spec[where x=x]]
        using N[THEN spec[where x=n], THEN spec[where x=x]]
        using dist_triangle_half_l[of "s m x" "l x" e "s n x"] by auto  }
    hence "\<exists>N. \<forall>m n x. N \<le> m \<and> N \<le> n \<and> P x  --> dist (s m x) (s n x) < e"  by auto  }
  thus ?rhs by auto
next
  assume ?rhs
  hence "\<forall>x. P x \<longrightarrow> Cauchy (\<lambda>n. s n x)" unfolding cauchy_def apply auto by (erule_tac x=e in allE)auto
  then obtain l where l:"\<forall>x. P x \<longrightarrow> ((\<lambda>n. s n x) ---> l x) sequentially" unfolding convergent_eq_cauchy[THEN sym]
    using choice[of "\<lambda>x l. P x \<longrightarrow> ((\<lambda>n. s n x) ---> l) sequentially"] by auto
  { fix e::real assume "e>0"
    then obtain N where N:"\<forall>m n x. N \<le> m \<and> N \<le> n \<and> P x \<longrightarrow> dist (s m x) (s n x) < e/2"
      using `?rhs`[THEN spec[where x="e/2"]] by auto
    { fix x assume "P x"
      then obtain M where M:"\<forall>n\<ge>M. dist (s n x) (l x) < e/2"
        using l[THEN spec[where x=x], unfolded LIMSEQ_def] using `e>0` by(auto elim!: allE[where x="e/2"])
      fix n::nat assume "n\<ge>N"
      hence "dist(s n x)(l x) < e"  using `P x`and N[THEN spec[where x=n], THEN spec[where x="N+M"], THEN spec[where x=x]]
        using M[THEN spec[where x="N+M"]] and dist_triangle_half_l[of "s n x" "s (N+M) x" e "l x"] by (auto simp add: dist_commute)  }
    hence "\<exists>N. \<forall>n x. N \<le> n \<and> P x \<longrightarrow> dist(s n x)(l x) < e" by auto }
  thus ?lhs by auto
qed

lemma uniformly_cauchy_imp_uniformly_convergent:
  fixes s :: "nat \<Rightarrow> 'a \<Rightarrow> 'b::heine_borel"
  assumes "\<forall>e>0.\<exists>N. \<forall>m (n::nat) x. N \<le> m \<and> N \<le> n \<and> P x --> dist(s m x)(s n x) < e"
          "\<forall>x. P x --> (\<forall>e>0. \<exists>N. \<forall>n. N \<le> n --> dist(s n x)(l x) < e)"
  shows "\<forall>e>0. \<exists>N. \<forall>n x. N \<le> n \<and> P x --> dist(s n x)(l x) < e"
proof-
  obtain l' where l:"\<forall>e>0. \<exists>N. \<forall>n x. N \<le> n \<and> P x \<longrightarrow> dist (s n x) (l' x) < e"
    using assms(1) unfolding uniformly_convergent_eq_cauchy[THEN sym] by auto
  moreover
  { fix x assume "P x"
    hence "l x = l' x" using tendsto_unique[OF trivial_limit_sequentially, of "\<lambda>n. s n x" "l x" "l' x"]
      using l and assms(2) unfolding LIMSEQ_def by blast  }
  ultimately show ?thesis by auto
qed


subsection {* Continuity *}

text {* Define continuity over a net to take in restrictions of the set. *}

definition
  continuous :: "'a::t2_space filter \<Rightarrow> ('a \<Rightarrow> 'b::topological_space) \<Rightarrow> bool"
  where "continuous net f \<longleftrightarrow> (f ---> f(netlimit net)) net"

lemma continuous_trivial_limit:
 "trivial_limit net ==> continuous net f"
  unfolding continuous_def tendsto_def trivial_limit_eq by auto

lemma continuous_within: "continuous (at x within s) f \<longleftrightarrow> (f ---> f(x)) (at x within s)"
  unfolding continuous_def
  unfolding tendsto_def
  using netlimit_within[of x s]
  by (cases "trivial_limit (at x within s)") (auto simp add: trivial_limit_eventually)

lemma continuous_at: "continuous (at x) f \<longleftrightarrow> (f ---> f(x)) (at x)"
  using continuous_within [of x UNIV f] by simp

lemma continuous_isCont: "isCont f x = continuous (at x) f"
  unfolding isCont_def LIM_def
  unfolding continuous_at Lim_at unfolding dist_nz by auto

lemma continuous_at_within:
  assumes "continuous (at x) f"  shows "continuous (at x within s) f"
  using assms unfolding continuous_at continuous_within
  by (rule Lim_at_within)

text{* Derive the epsilon-delta forms, which we often use as "definitions" *}

lemma continuous_within_eps_delta:
  "continuous (at x within s) f \<longleftrightarrow> (\<forall>e>0. \<exists>d>0. \<forall>x'\<in> s.  dist x' x < d --> dist (f x') (f x) < e)"
  unfolding continuous_within and Lim_within
  apply auto unfolding dist_nz[THEN sym] apply(auto del: allE elim!:allE) apply(rule_tac x=d in exI) by auto

lemma continuous_at_eps_delta: "continuous (at x) f \<longleftrightarrow>  (\<forall>e>0. \<exists>d>0.
                           \<forall>x'. dist x' x < d --> dist(f x')(f x) < e)"
  using continuous_within_eps_delta [of x UNIV f] by simp

text{* Versions in terms of open balls. *}

lemma continuous_within_ball:
 "continuous (at x within s) f \<longleftrightarrow> (\<forall>e>0. \<exists>d>0.
                            f ` (ball x d \<inter> s) \<subseteq> ball (f x) e)" (is "?lhs = ?rhs")
proof
  assume ?lhs
  { fix e::real assume "e>0"
    then obtain d where d: "d>0" "\<forall>xa\<in>s. 0 < dist xa x \<and> dist xa x < d \<longrightarrow> dist (f xa) (f x) < e"
      using `?lhs`[unfolded continuous_within Lim_within] by auto
    { fix y assume "y\<in>f ` (ball x d \<inter> s)"
      hence "y \<in> ball (f x) e" using d(2) unfolding dist_nz[THEN sym]
        apply (auto simp add: dist_commute) apply(erule_tac x=xa in ballE) apply auto using `e>0` by auto
    }
    hence "\<exists>d>0. f ` (ball x d \<inter> s) \<subseteq> ball (f x) e" using `d>0` unfolding subset_eq ball_def by (auto simp add: dist_commute)  }
  thus ?rhs by auto
next
  assume ?rhs thus ?lhs unfolding continuous_within Lim_within ball_def subset_eq
    apply (auto simp add: dist_commute) apply(erule_tac x=e in allE) by auto
qed

lemma continuous_at_ball:
  "continuous (at x) f \<longleftrightarrow> (\<forall>e>0. \<exists>d>0. f ` (ball x d) \<subseteq> ball (f x) e)" (is "?lhs = ?rhs")
proof
  assume ?lhs thus ?rhs unfolding continuous_at Lim_at subset_eq Ball_def Bex_def image_iff mem_ball
    apply auto apply(erule_tac x=e in allE) apply auto apply(rule_tac x=d in exI) apply auto apply(erule_tac x=xa in allE) apply (auto simp add: dist_commute dist_nz)
    unfolding dist_nz[THEN sym] by auto
next
  assume ?rhs thus ?lhs unfolding continuous_at Lim_at subset_eq Ball_def Bex_def image_iff mem_ball
    apply auto apply(erule_tac x=e in allE) apply auto apply(rule_tac x=d in exI) apply auto apply(erule_tac x="f xa" in allE) by (auto simp add: dist_commute dist_nz)
qed

text{* Define setwise continuity in terms of limits within the set. *}

definition
  continuous_on ::
    "'a set \<Rightarrow> ('a::topological_space \<Rightarrow> 'b::topological_space) \<Rightarrow> bool"
where
  "continuous_on s f \<longleftrightarrow> (\<forall>x\<in>s. (f ---> f x) (at x within s))"

lemma continuous_on_topological:
  "continuous_on s f \<longleftrightarrow>
    (\<forall>x\<in>s. \<forall>B. open B \<longrightarrow> f x \<in> B \<longrightarrow>
      (\<exists>A. open A \<and> x \<in> A \<and> (\<forall>y\<in>s. y \<in> A \<longrightarrow> f y \<in> B)))"
unfolding continuous_on_def tendsto_def
unfolding Limits.eventually_within eventually_at_topological
by (intro ball_cong [OF refl] all_cong imp_cong ex_cong conj_cong refl) auto

lemma continuous_on_iff:
  "continuous_on s f \<longleftrightarrow>
    (\<forall>x\<in>s. \<forall>e>0. \<exists>d>0. \<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist (f x') (f x) < e)"
unfolding continuous_on_def Lim_within
apply (intro ball_cong [OF refl] all_cong ex_cong)
apply (rename_tac y, case_tac "y = x", simp)
apply (simp add: dist_nz)
done

definition
  uniformly_continuous_on ::
    "'a set \<Rightarrow> ('a::metric_space \<Rightarrow> 'b::metric_space) \<Rightarrow> bool"
where
  "uniformly_continuous_on s f \<longleftrightarrow>
    (\<forall>e>0. \<exists>d>0. \<forall>x\<in>s. \<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist (f x') (f x) < e)"

text{* Some simple consequential lemmas. *}

lemma uniformly_continuous_imp_continuous:
 " uniformly_continuous_on s f ==> continuous_on s f"
  unfolding uniformly_continuous_on_def continuous_on_iff by blast

lemma continuous_at_imp_continuous_within:
 "continuous (at x) f ==> continuous (at x within s) f"
  unfolding continuous_within continuous_at using Lim_at_within by auto

lemma Lim_trivial_limit: "trivial_limit net \<Longrightarrow> (f ---> l) net"
unfolding tendsto_def by (simp add: trivial_limit_eq)

lemma continuous_at_imp_continuous_on:
  assumes "\<forall>x\<in>s. continuous (at x) f"
  shows "continuous_on s f"
unfolding continuous_on_def
proof
  fix x assume "x \<in> s"
  with assms have *: "(f ---> f (netlimit (at x))) (at x)"
    unfolding continuous_def by simp
  have "(f ---> f x) (at x)"
  proof (cases "trivial_limit (at x)")
    case True thus ?thesis
      by (rule Lim_trivial_limit)
  next
    case False
    hence 1: "netlimit (at x) = x"
      using netlimit_within [of x UNIV] by simp
    with * show ?thesis by simp
  qed
  thus "(f ---> f x) (at x within s)"
    by (rule Lim_at_within)
qed

lemma continuous_on_eq_continuous_within:
  "continuous_on s f \<longleftrightarrow> (\<forall>x \<in> s. continuous (at x within s) f)"
unfolding continuous_on_def continuous_def
apply (rule ball_cong [OF refl])
apply (case_tac "trivial_limit (at x within s)")
apply (simp add: Lim_trivial_limit)
apply (simp add: netlimit_within)
done

lemmas continuous_on = continuous_on_def -- "legacy theorem name"

lemma continuous_on_eq_continuous_at:
  shows "open s ==> (continuous_on s f \<longleftrightarrow> (\<forall>x \<in> s. continuous (at x) f))"
  by (auto simp add: continuous_on continuous_at Lim_within_open)

lemma continuous_within_subset:
 "continuous (at x within s) f \<Longrightarrow> t \<subseteq> s
             ==> continuous (at x within t) f"
  unfolding continuous_within by(metis Lim_within_subset)

lemma continuous_on_subset:
  shows "continuous_on s f \<Longrightarrow> t \<subseteq> s ==> continuous_on t f"
  unfolding continuous_on by (metis subset_eq Lim_within_subset)

lemma continuous_on_interior:
  shows "continuous_on s f \<Longrightarrow> x \<in> interior s \<Longrightarrow> continuous (at x) f"
  by (erule interiorE, drule (1) continuous_on_subset,
    simp add: continuous_on_eq_continuous_at)

lemma continuous_on_eq:
  "(\<forall>x \<in> s. f x = g x) \<Longrightarrow> continuous_on s f \<Longrightarrow> continuous_on s g"
  unfolding continuous_on_def tendsto_def Limits.eventually_within
  by simp

text {* Characterization of various kinds of continuity in terms of sequences. *}

lemma continuous_within_sequentially:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::topological_space"
  shows "continuous (at a within s) f \<longleftrightarrow>
                (\<forall>x. (\<forall>n::nat. x n \<in> s) \<and> (x ---> a) sequentially
                     --> ((f o x) ---> f a) sequentially)" (is "?lhs = ?rhs")
proof
  assume ?lhs
  { fix x::"nat \<Rightarrow> 'a" assume x:"\<forall>n. x n \<in> s" "\<forall>e>0. eventually (\<lambda>n. dist (x n) a < e) sequentially"
    fix T::"'b set" assume "open T" and "f a \<in> T"
    with `?lhs` obtain d where "d>0" and d:"\<forall>x\<in>s. 0 < dist x a \<and> dist x a < d \<longrightarrow> f x \<in> T"
      unfolding continuous_within tendsto_def eventually_within by auto
    have "eventually (\<lambda>n. dist (x n) a < d) sequentially"
      using x(2) `d>0` by simp
    hence "eventually (\<lambda>n. (f \<circ> x) n \<in> T) sequentially"
    proof eventually_elim
      case (elim n) thus ?case
        using d x(1) `f a \<in> T` unfolding dist_nz[THEN sym] by auto
    qed
  }
  thus ?rhs unfolding tendsto_iff unfolding tendsto_def by simp
next
  assume ?rhs thus ?lhs
    unfolding continuous_within tendsto_def [where l="f a"]
    by (simp add: sequentially_imp_eventually_within)
qed

lemma continuous_at_sequentially:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::topological_space"
  shows "continuous (at a) f \<longleftrightarrow> (\<forall>x. (x ---> a) sequentially
                  --> ((f o x) ---> f a) sequentially)"
  using continuous_within_sequentially[of a UNIV f] by simp

lemma continuous_on_sequentially:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::topological_space"
  shows "continuous_on s f \<longleftrightarrow>
    (\<forall>x. \<forall>a \<in> s. (\<forall>n. x(n) \<in> s) \<and> (x ---> a) sequentially
                    --> ((f o x) ---> f(a)) sequentially)" (is "?lhs = ?rhs")
proof
  assume ?rhs thus ?lhs using continuous_within_sequentially[of _ s f] unfolding continuous_on_eq_continuous_within by auto
next
  assume ?lhs thus ?rhs unfolding continuous_on_eq_continuous_within using continuous_within_sequentially[of _ s f] by auto
qed

lemma uniformly_continuous_on_sequentially:
  "uniformly_continuous_on s f \<longleftrightarrow> (\<forall>x y. (\<forall>n. x n \<in> s) \<and> (\<forall>n. y n \<in> s) \<and>
                    ((\<lambda>n. dist (x n) (y n)) ---> 0) sequentially
                    \<longrightarrow> ((\<lambda>n. dist (f(x n)) (f(y n))) ---> 0) sequentially)" (is "?lhs = ?rhs")
proof
  assume ?lhs
  { fix x y assume x:"\<forall>n. x n \<in> s" and y:"\<forall>n. y n \<in> s" and xy:"((\<lambda>n. dist (x n) (y n)) ---> 0) sequentially"
    { fix e::real assume "e>0"
      then obtain d where "d>0" and d:"\<forall>x\<in>s. \<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist (f x') (f x) < e"
        using `?lhs`[unfolded uniformly_continuous_on_def, THEN spec[where x=e]] by auto
      obtain N where N:"\<forall>n\<ge>N. dist (x n) (y n) < d" using xy[unfolded LIMSEQ_def dist_norm] and `d>0` by auto
      { fix n assume "n\<ge>N"
        hence "dist (f (x n)) (f (y n)) < e"
          using N[THEN spec[where x=n]] using d[THEN bspec[where x="x n"], THEN bspec[where x="y n"]] using x and y
          unfolding dist_commute by simp  }
      hence "\<exists>N. \<forall>n\<ge>N. dist (f (x n)) (f (y n)) < e"  by auto  }
    hence "((\<lambda>n. dist (f(x n)) (f(y n))) ---> 0) sequentially" unfolding LIMSEQ_def and dist_real_def by auto  }
  thus ?rhs by auto
next
  assume ?rhs
  { assume "\<not> ?lhs"
    then obtain e where "e>0" "\<forall>d>0. \<exists>x\<in>s. \<exists>x'\<in>s. dist x' x < d \<and> \<not> dist (f x') (f x) < e" unfolding uniformly_continuous_on_def by auto
    then obtain fa where fa:"\<forall>x.  0 < x \<longrightarrow> fst (fa x) \<in> s \<and> snd (fa x) \<in> s \<and> dist (fst (fa x)) (snd (fa x)) < x \<and> \<not> dist (f (fst (fa x))) (f (snd (fa x))) < e"
      using choice[of "\<lambda>d x. d>0 \<longrightarrow> fst x \<in> s \<and> snd x \<in> s \<and> dist (snd x) (fst x) < d \<and> \<not> dist (f (snd x)) (f (fst x)) < e"] unfolding Bex_def
      by (auto simp add: dist_commute)
    def x \<equiv> "\<lambda>n::nat. fst (fa (inverse (real n + 1)))"
    def y \<equiv> "\<lambda>n::nat. snd (fa (inverse (real n + 1)))"
    have xyn:"\<forall>n. x n \<in> s \<and> y n \<in> s" and xy0:"\<forall>n. dist (x n) (y n) < inverse (real n + 1)" and fxy:"\<forall>n. \<not> dist (f (x n)) (f (y n)) < e"
      unfolding x_def and y_def using fa by auto
    { fix e::real assume "e>0"
      then obtain N::nat where "N \<noteq> 0" and N:"0 < inverse (real N) \<and> inverse (real N) < e" unfolding real_arch_inv[of e]   by auto
      { fix n::nat assume "n\<ge>N"
        hence "inverse (real n + 1) < inverse (real N)" using real_of_nat_ge_zero and `N\<noteq>0` by auto
        also have "\<dots> < e" using N by auto
        finally have "inverse (real n + 1) < e" by auto
        hence "dist (x n) (y n) < e" using xy0[THEN spec[where x=n]] by auto  }
      hence "\<exists>N. \<forall>n\<ge>N. dist (x n) (y n) < e" by auto  }
    hence "\<forall>e>0. \<exists>N. \<forall>n\<ge>N. dist (f (x n)) (f (y n)) < e" using `?rhs`[THEN spec[where x=x], THEN spec[where x=y]] and xyn unfolding LIMSEQ_def dist_real_def by auto
    hence False using fxy and `e>0` by auto  }
  thus ?lhs unfolding uniformly_continuous_on_def by blast
qed

text{* The usual transformation theorems. *}

lemma continuous_transform_within:
  fixes f g :: "'a::metric_space \<Rightarrow> 'b::topological_space"
  assumes "0 < d" "x \<in> s" "\<forall>x' \<in> s. dist x' x < d --> f x' = g x'"
          "continuous (at x within s) f"
  shows "continuous (at x within s) g"
unfolding continuous_within
proof (rule Lim_transform_within)
  show "0 < d" by fact
  show "\<forall>x'\<in>s. 0 < dist x' x \<and> dist x' x < d \<longrightarrow> f x' = g x'"
    using assms(3) by auto
  have "f x = g x"
    using assms(1,2,3) by auto
  thus "(f ---> g x) (at x within s)"
    using assms(4) unfolding continuous_within by simp
qed

lemma continuous_transform_at:
  fixes f g :: "'a::metric_space \<Rightarrow> 'b::topological_space"
  assumes "0 < d" "\<forall>x'. dist x' x < d --> f x' = g x'"
          "continuous (at x) f"
  shows "continuous (at x) g"
  using continuous_transform_within [of d x UNIV f g] assms by simp

subsubsection {* Structural rules for pointwise continuity *}

lemma continuous_within_id: "continuous (at a within s) (\<lambda>x. x)"
  unfolding continuous_within by (rule tendsto_ident_at_within)

lemma continuous_at_id: "continuous (at a) (\<lambda>x. x)"
  unfolding continuous_at by (rule tendsto_ident_at)

lemma continuous_const: "continuous F (\<lambda>x. c)"
  unfolding continuous_def by (rule tendsto_const)

lemma continuous_dist:
  assumes "continuous F f" and "continuous F g"
  shows "continuous F (\<lambda>x. dist (f x) (g x))"
  using assms unfolding continuous_def by (rule tendsto_dist)

lemma continuous_infdist:
  assumes "continuous F f"
  shows "continuous F (\<lambda>x. infdist (f x) A)"
  using assms unfolding continuous_def by (rule tendsto_infdist)

lemma continuous_norm:
  shows "continuous F f \<Longrightarrow> continuous F (\<lambda>x. norm (f x))"
  unfolding continuous_def by (rule tendsto_norm)

lemma continuous_infnorm:
  shows "continuous F f \<Longrightarrow> continuous F (\<lambda>x. infnorm (f x))"
  unfolding continuous_def by (rule tendsto_infnorm)

lemma continuous_add:
  fixes f g :: "'a::t2_space \<Rightarrow> 'b::real_normed_vector"
  shows "\<lbrakk>continuous F f; continuous F g\<rbrakk> \<Longrightarrow> continuous F (\<lambda>x. f x + g x)"
  unfolding continuous_def by (rule tendsto_add)

lemma continuous_minus:
  fixes f :: "'a::t2_space \<Rightarrow> 'b::real_normed_vector"
  shows "continuous F f \<Longrightarrow> continuous F (\<lambda>x. - f x)"
  unfolding continuous_def by (rule tendsto_minus)

lemma continuous_diff:
  fixes f g :: "'a::t2_space \<Rightarrow> 'b::real_normed_vector"
  shows "\<lbrakk>continuous F f; continuous F g\<rbrakk> \<Longrightarrow> continuous F (\<lambda>x. f x - g x)"
  unfolding continuous_def by (rule tendsto_diff)

lemma continuous_scaleR:
  fixes g :: "'a::t2_space \<Rightarrow> 'b::real_normed_vector"
  shows "\<lbrakk>continuous F f; continuous F g\<rbrakk> \<Longrightarrow> continuous F (\<lambda>x. f x *\<^sub>R g x)"
  unfolding continuous_def by (rule tendsto_scaleR)

lemma continuous_mult:
  fixes f g :: "'a::t2_space \<Rightarrow> 'b::real_normed_algebra"
  shows "\<lbrakk>continuous F f; continuous F g\<rbrakk> \<Longrightarrow> continuous F (\<lambda>x. f x * g x)"
  unfolding continuous_def by (rule tendsto_mult)

lemma continuous_inner:
  assumes "continuous F f" and "continuous F g"
  shows "continuous F (\<lambda>x. inner (f x) (g x))"
  using assms unfolding continuous_def by (rule tendsto_inner)

lemma continuous_inverse:
  fixes f :: "'a::t2_space \<Rightarrow> 'b::real_normed_div_algebra"
  assumes "continuous F f" and "f (netlimit F) \<noteq> 0"
  shows "continuous F (\<lambda>x. inverse (f x))"
  using assms unfolding continuous_def by (rule tendsto_inverse)

lemma continuous_at_within_inverse:
  fixes f :: "'a::t2_space \<Rightarrow> 'b::real_normed_div_algebra"
  assumes "continuous (at a within s) f" and "f a \<noteq> 0"
  shows "continuous (at a within s) (\<lambda>x. inverse (f x))"
  using assms unfolding continuous_within by (rule tendsto_inverse)

lemma continuous_at_inverse:
  fixes f :: "'a::t2_space \<Rightarrow> 'b::real_normed_div_algebra"
  assumes "continuous (at a) f" and "f a \<noteq> 0"
  shows "continuous (at a) (\<lambda>x. inverse (f x))"
  using assms unfolding continuous_at by (rule tendsto_inverse)

lemmas continuous_intros = continuous_at_id continuous_within_id
  continuous_const continuous_dist continuous_norm continuous_infnorm
  continuous_add continuous_minus continuous_diff continuous_scaleR continuous_mult
  continuous_inner continuous_at_inverse continuous_at_within_inverse

subsubsection {* Structural rules for setwise continuity *}

lemma continuous_on_id: "continuous_on s (\<lambda>x. x)"
  unfolding continuous_on_def by (fast intro: tendsto_ident_at_within)

lemma continuous_on_const: "continuous_on s (\<lambda>x. c)"
  unfolding continuous_on_def by (auto intro: tendsto_intros)

lemma continuous_on_norm:
  shows "continuous_on s f \<Longrightarrow> continuous_on s (\<lambda>x. norm (f x))"
  unfolding continuous_on_def by (fast intro: tendsto_norm)

lemma continuous_on_infnorm:
  shows "continuous_on s f \<Longrightarrow> continuous_on s (\<lambda>x. infnorm (f x))"
  unfolding continuous_on by (fast intro: tendsto_infnorm)

lemma continuous_on_minus:
  fixes f :: "'a::topological_space \<Rightarrow> 'b::real_normed_vector"
  shows "continuous_on s f \<Longrightarrow> continuous_on s (\<lambda>x. - f x)"
  unfolding continuous_on_def by (auto intro: tendsto_intros)

lemma continuous_on_add:
  fixes f g :: "'a::topological_space \<Rightarrow> 'b::real_normed_vector"
  shows "continuous_on s f \<Longrightarrow> continuous_on s g
           \<Longrightarrow> continuous_on s (\<lambda>x. f x + g x)"
  unfolding continuous_on_def by (auto intro: tendsto_intros)

lemma continuous_on_diff:
  fixes f g :: "'a::topological_space \<Rightarrow> 'b::real_normed_vector"
  shows "continuous_on s f \<Longrightarrow> continuous_on s g
           \<Longrightarrow> continuous_on s (\<lambda>x. f x - g x)"
  unfolding continuous_on_def by (auto intro: tendsto_intros)

lemma (in bounded_linear) continuous_on:
  "continuous_on s g \<Longrightarrow> continuous_on s (\<lambda>x. f (g x))"
  unfolding continuous_on_def by (fast intro: tendsto)

lemma (in bounded_bilinear) continuous_on:
  "\<lbrakk>continuous_on s f; continuous_on s g\<rbrakk> \<Longrightarrow> continuous_on s (\<lambda>x. f x ** g x)"
  unfolding continuous_on_def by (fast intro: tendsto)

lemma continuous_on_scaleR:
  fixes g :: "'a::topological_space \<Rightarrow> 'b::real_normed_vector"
  assumes "continuous_on s f" and "continuous_on s g"
  shows "continuous_on s (\<lambda>x. f x *\<^sub>R g x)"
  using bounded_bilinear_scaleR assms
  by (rule bounded_bilinear.continuous_on)

lemma continuous_on_mult:
  fixes g :: "'a::topological_space \<Rightarrow> 'b::real_normed_algebra"
  assumes "continuous_on s f" and "continuous_on s g"
  shows "continuous_on s (\<lambda>x. f x * g x)"
  using bounded_bilinear_mult assms
  by (rule bounded_bilinear.continuous_on)

lemma continuous_on_inner:
  fixes g :: "'a::topological_space \<Rightarrow> 'b::real_inner"
  assumes "continuous_on s f" and "continuous_on s g"
  shows "continuous_on s (\<lambda>x. inner (f x) (g x))"
  using bounded_bilinear_inner assms
  by (rule bounded_bilinear.continuous_on)

lemma continuous_on_inverse:
  fixes f :: "'a::topological_space \<Rightarrow> 'b::real_normed_div_algebra"
  assumes "continuous_on s f" and "\<forall>x\<in>s. f x \<noteq> 0"
  shows "continuous_on s (\<lambda>x. inverse (f x))"
  using assms unfolding continuous_on by (fast intro: tendsto_inverse)

subsubsection {* Structural rules for uniform continuity *}

lemma uniformly_continuous_on_id:
  shows "uniformly_continuous_on s (\<lambda>x. x)"
  unfolding uniformly_continuous_on_def by auto

lemma uniformly_continuous_on_const:
  shows "uniformly_continuous_on s (\<lambda>x. c)"
  unfolding uniformly_continuous_on_def by simp

lemma uniformly_continuous_on_dist:
  fixes f g :: "'a::metric_space \<Rightarrow> 'b::metric_space"
  assumes "uniformly_continuous_on s f"
  assumes "uniformly_continuous_on s g"
  shows "uniformly_continuous_on s (\<lambda>x. dist (f x) (g x))"
proof -
  { fix a b c d :: 'b have "\<bar>dist a b - dist c d\<bar> \<le> dist a c + dist b d"
      using dist_triangle2 [of a b c] dist_triangle2 [of b c d]
      using dist_triangle3 [of c d a] dist_triangle [of a d b]
      by arith
  } note le = this
  { fix x y
    assume f: "(\<lambda>n. dist (f (x n)) (f (y n))) ----> 0"
    assume g: "(\<lambda>n. dist (g (x n)) (g (y n))) ----> 0"
    have "(\<lambda>n. \<bar>dist (f (x n)) (g (x n)) - dist (f (y n)) (g (y n))\<bar>) ----> 0"
      by (rule Lim_transform_bound [OF _ tendsto_add_zero [OF f g]],
        simp add: le)
  }
  thus ?thesis using assms unfolding uniformly_continuous_on_sequentially
    unfolding dist_real_def by simp
qed

lemma uniformly_continuous_on_norm:
  assumes "uniformly_continuous_on s f"
  shows "uniformly_continuous_on s (\<lambda>x. norm (f x))"
  unfolding norm_conv_dist using assms
  by (intro uniformly_continuous_on_dist uniformly_continuous_on_const)

lemma (in bounded_linear) uniformly_continuous_on:
  assumes "uniformly_continuous_on s g"
  shows "uniformly_continuous_on s (\<lambda>x. f (g x))"
  using assms unfolding uniformly_continuous_on_sequentially
  unfolding dist_norm tendsto_norm_zero_iff diff[symmetric]
  by (auto intro: tendsto_zero)

lemma uniformly_continuous_on_cmul:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::real_normed_vector"
  assumes "uniformly_continuous_on s f"
  shows "uniformly_continuous_on s (\<lambda>x. c *\<^sub>R f(x))"
  using bounded_linear_scaleR_right assms
  by (rule bounded_linear.uniformly_continuous_on)

lemma dist_minus:
  fixes x y :: "'a::real_normed_vector"
  shows "dist (- x) (- y) = dist x y"
  unfolding dist_norm minus_diff_minus norm_minus_cancel ..

lemma uniformly_continuous_on_minus:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::real_normed_vector"
  shows "uniformly_continuous_on s f \<Longrightarrow> uniformly_continuous_on s (\<lambda>x. - f x)"
  unfolding uniformly_continuous_on_def dist_minus .

lemma uniformly_continuous_on_add:
  fixes f g :: "'a::metric_space \<Rightarrow> 'b::real_normed_vector"
  assumes "uniformly_continuous_on s f"
  assumes "uniformly_continuous_on s g"
  shows "uniformly_continuous_on s (\<lambda>x. f x + g x)"
  using assms unfolding uniformly_continuous_on_sequentially
  unfolding dist_norm tendsto_norm_zero_iff add_diff_add
  by (auto intro: tendsto_add_zero)

lemma uniformly_continuous_on_diff:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::real_normed_vector"
  assumes "uniformly_continuous_on s f" and "uniformly_continuous_on s g"
  shows "uniformly_continuous_on s (\<lambda>x. f x - g x)"
  unfolding ab_diff_minus using assms
  by (intro uniformly_continuous_on_add uniformly_continuous_on_minus)

text{* Continuity of all kinds is preserved under composition. *}

lemma continuous_within_topological:
  "continuous (at x within s) f \<longleftrightarrow>
    (\<forall>B. open B \<longrightarrow> f x \<in> B \<longrightarrow>
      (\<exists>A. open A \<and> x \<in> A \<and> (\<forall>y\<in>s. y \<in> A \<longrightarrow> f y \<in> B)))"
unfolding continuous_within
unfolding tendsto_def Limits.eventually_within eventually_at_topological
by (intro ball_cong [OF refl] all_cong imp_cong ex_cong conj_cong refl) auto

lemma continuous_within_compose:
  assumes "continuous (at x within s) f"
  assumes "continuous (at (f x) within f ` s) g"
  shows "continuous (at x within s) (g o f)"
using assms unfolding continuous_within_topological by simp metis

lemma continuous_at_compose:
  assumes "continuous (at x) f" and "continuous (at (f x)) g"
  shows "continuous (at x) (g o f)"
proof-
  have "continuous (at (f x) within range f) g" using assms(2)
    using continuous_within_subset[of "f x" UNIV g "range f"] by simp
  thus ?thesis using assms(1)
    using continuous_within_compose[of x UNIV f g] by simp
qed

lemma continuous_on_compose:
  "continuous_on s f \<Longrightarrow> continuous_on (f ` s) g \<Longrightarrow> continuous_on s (g o f)"
  unfolding continuous_on_topological by simp metis

lemma uniformly_continuous_on_compose:
  assumes "uniformly_continuous_on s f"  "uniformly_continuous_on (f ` s) g"
  shows "uniformly_continuous_on s (g o f)"
proof-
  { fix e::real assume "e>0"
    then obtain d where "d>0" and d:"\<forall>x\<in>f ` s. \<forall>x'\<in>f ` s. dist x' x < d \<longrightarrow> dist (g x') (g x) < e" using assms(2) unfolding uniformly_continuous_on_def by auto
    obtain d' where "d'>0" "\<forall>x\<in>s. \<forall>x'\<in>s. dist x' x < d' \<longrightarrow> dist (f x') (f x) < d" using `d>0` using assms(1) unfolding uniformly_continuous_on_def by auto
    hence "\<exists>d>0. \<forall>x\<in>s. \<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist ((g \<circ> f) x') ((g \<circ> f) x) < e" using `d>0` using d by auto  }
  thus ?thesis using assms unfolding uniformly_continuous_on_def by auto
qed

lemmas continuous_on_intros = continuous_on_id continuous_on_const
  continuous_on_compose continuous_on_norm continuous_on_infnorm
  continuous_on_add continuous_on_minus continuous_on_diff
  continuous_on_scaleR continuous_on_mult continuous_on_inverse
  continuous_on_inner
  uniformly_continuous_on_id uniformly_continuous_on_const
  uniformly_continuous_on_dist uniformly_continuous_on_norm
  uniformly_continuous_on_compose uniformly_continuous_on_add
  uniformly_continuous_on_minus uniformly_continuous_on_diff
  uniformly_continuous_on_cmul

text{* Continuity in terms of open preimages. *}

lemma continuous_at_open:
  shows "continuous (at x) f \<longleftrightarrow> (\<forall>t. open t \<and> f x \<in> t --> (\<exists>s. open s \<and> x \<in> s \<and> (\<forall>x' \<in> s. (f x') \<in> t)))"
unfolding continuous_within_topological [of x UNIV f, unfolded within_UNIV]
unfolding imp_conjL by (intro all_cong imp_cong ex_cong conj_cong refl) auto

lemma continuous_on_open:
  shows "continuous_on s f \<longleftrightarrow>
        (\<forall>t. openin (subtopology euclidean (f ` s)) t
            --> openin (subtopology euclidean s) {x \<in> s. f x \<in> t})" (is "?lhs = ?rhs")
proof (safe)
  fix t :: "'b set"
  assume 1: "continuous_on s f"
  assume 2: "openin (subtopology euclidean (f ` s)) t"
  from 2 obtain B where B: "open B" and t: "t = f ` s \<inter> B"
    unfolding openin_open by auto
  def U == "\<Union>{A. open A \<and> (\<forall>x\<in>s. x \<in> A \<longrightarrow> f x \<in> B)}"
  have "open U" unfolding U_def by (simp add: open_Union)
  moreover have "\<forall>x\<in>s. x \<in> U \<longleftrightarrow> f x \<in> t"
  proof (intro ballI iffI)
    fix x assume "x \<in> s" and "x \<in> U" thus "f x \<in> t"
      unfolding U_def t by auto
  next
    fix x assume "x \<in> s" and "f x \<in> t"
    hence "x \<in> s" and "f x \<in> B"
      unfolding t by auto
    with 1 B obtain A where "open A" "x \<in> A" "\<forall>y\<in>s. y \<in> A \<longrightarrow> f y \<in> B"
      unfolding t continuous_on_topological by metis
    then show "x \<in> U"
      unfolding U_def by auto
  qed
  ultimately have "open U \<and> {x \<in> s. f x \<in> t} = s \<inter> U" by auto
  then show "openin (subtopology euclidean s) {x \<in> s. f x \<in> t}"
    unfolding openin_open by fast
next
  assume "?rhs" show "continuous_on s f"
  unfolding continuous_on_topological
  proof (clarify)
    fix x and B assume "x \<in> s" and "open B" and "f x \<in> B"
    have "openin (subtopology euclidean (f ` s)) (f ` s \<inter> B)"
      unfolding openin_open using `open B` by auto
    then have "openin (subtopology euclidean s) {x \<in> s. f x \<in> f ` s \<inter> B}"
      using `?rhs` by fast
    then show "\<exists>A. open A \<and> x \<in> A \<and> (\<forall>y\<in>s. y \<in> A \<longrightarrow> f y \<in> B)"
      unfolding openin_open using `x \<in> s` and `f x \<in> B` by auto
  qed
qed

text {* Similarly in terms of closed sets. *}

lemma continuous_on_closed:
  shows "continuous_on s f \<longleftrightarrow>  (\<forall>t. closedin (subtopology euclidean (f ` s)) t  --> closedin (subtopology euclidean s) {x \<in> s. f x \<in> t})" (is "?lhs = ?rhs")
proof
  assume ?lhs
  { fix t
    have *:"s - {x \<in> s. f x \<in> f ` s - t} = {x \<in> s. f x \<in> t}" by auto
    have **:"f ` s - (f ` s - (f ` s - t)) = f ` s - t" by auto
    assume as:"closedin (subtopology euclidean (f ` s)) t"
    hence "closedin (subtopology euclidean (f ` s)) (f ` s - (f ` s - t))" unfolding closedin_def topspace_euclidean_subtopology unfolding ** by auto
    hence "closedin (subtopology euclidean s) {x \<in> s. f x \<in> t}" using `?lhs`[unfolded continuous_on_open, THEN spec[where x="(f ` s) - t"]]
      unfolding openin_closedin_eq topspace_euclidean_subtopology unfolding * by auto  }
  thus ?rhs by auto
next
  assume ?rhs
  { fix t
    have *:"s - {x \<in> s. f x \<in> f ` s - t} = {x \<in> s. f x \<in> t}" by auto
    assume as:"openin (subtopology euclidean (f ` s)) t"
    hence "openin (subtopology euclidean s) {x \<in> s. f x \<in> t}" using `?rhs`[THEN spec[where x="(f ` s) - t"]]
      unfolding openin_closedin_eq topspace_euclidean_subtopology *[THEN sym] closedin_subtopology by auto }
  thus ?lhs unfolding continuous_on_open by auto
qed

text {* Half-global and completely global cases. *}

lemma continuous_open_in_preimage:
  assumes "continuous_on s f"  "open t"
  shows "openin (subtopology euclidean s) {x \<in> s. f x \<in> t}"
proof-
  have *:"\<forall>x. x \<in> s \<and> f x \<in> t \<longleftrightarrow> x \<in> s \<and> f x \<in> (t \<inter> f ` s)" by auto
  have "openin (subtopology euclidean (f ` s)) (t \<inter> f ` s)"
    using openin_open_Int[of t "f ` s", OF assms(2)] unfolding openin_open by auto
  thus ?thesis using assms(1)[unfolded continuous_on_open, THEN spec[where x="t \<inter> f ` s"]] using * by auto
qed

lemma continuous_closed_in_preimage:
  assumes "continuous_on s f"  "closed t"
  shows "closedin (subtopology euclidean s) {x \<in> s. f x \<in> t}"
proof-
  have *:"\<forall>x. x \<in> s \<and> f x \<in> t \<longleftrightarrow> x \<in> s \<and> f x \<in> (t \<inter> f ` s)" by auto
  have "closedin (subtopology euclidean (f ` s)) (t \<inter> f ` s)"
    using closedin_closed_Int[of t "f ` s", OF assms(2)] unfolding Int_commute by auto
  thus ?thesis
    using assms(1)[unfolded continuous_on_closed, THEN spec[where x="t \<inter> f ` s"]] using * by auto
qed

lemma continuous_open_preimage:
  assumes "continuous_on s f" "open s" "open t"
  shows "open {x \<in> s. f x \<in> t}"
proof-
  obtain T where T: "open T" "{x \<in> s. f x \<in> t} = s \<inter> T"
    using continuous_open_in_preimage[OF assms(1,3)] unfolding openin_open by auto
  thus ?thesis using open_Int[of s T, OF assms(2)] by auto
qed

lemma continuous_closed_preimage:
  assumes "continuous_on s f" "closed s" "closed t"
  shows "closed {x \<in> s. f x \<in> t}"
proof-
  obtain T where T: "closed T" "{x \<in> s. f x \<in> t} = s \<inter> T"
    using continuous_closed_in_preimage[OF assms(1,3)] unfolding closedin_closed by auto
  thus ?thesis using closed_Int[of s T, OF assms(2)] by auto
qed

lemma continuous_open_preimage_univ:
  shows "\<forall>x. continuous (at x) f \<Longrightarrow> open s \<Longrightarrow> open {x. f x \<in> s}"
  using continuous_open_preimage[of UNIV f s] open_UNIV continuous_at_imp_continuous_on by auto

lemma continuous_closed_preimage_univ:
  shows "(\<forall>x. continuous (at x) f) \<Longrightarrow> closed s ==> closed {x. f x \<in> s}"
  using continuous_closed_preimage[of UNIV f s] closed_UNIV continuous_at_imp_continuous_on by auto

lemma continuous_open_vimage:
  shows "\<forall>x. continuous (at x) f \<Longrightarrow> open s \<Longrightarrow> open (f -` s)"
  unfolding vimage_def by (rule continuous_open_preimage_univ)

lemma continuous_closed_vimage:
  shows "\<forall>x. continuous (at x) f \<Longrightarrow> closed s \<Longrightarrow> closed (f -` s)"
  unfolding vimage_def by (rule continuous_closed_preimage_univ)

lemma interior_image_subset:
  assumes "\<forall>x. continuous (at x) f" "inj f"
  shows "interior (f ` s) \<subseteq> f ` (interior s)"
proof
  fix x assume "x \<in> interior (f ` s)"
  then obtain T where as: "open T" "x \<in> T" "T \<subseteq> f ` s" ..
  hence "x \<in> f ` s" by auto
  then obtain y where y: "y \<in> s" "x = f y" by auto
  have "open (vimage f T)"
    using assms(1) `open T` by (rule continuous_open_vimage)
  moreover have "y \<in> vimage f T"
    using `x = f y` `x \<in> T` by simp
  moreover have "vimage f T \<subseteq> s"
    using `T \<subseteq> image f s` `inj f` unfolding inj_on_def subset_eq by auto
  ultimately have "y \<in> interior s" ..
  with `x = f y` show "x \<in> f ` interior s" ..
qed

text {* Equality of continuous functions on closure and related results. *}

lemma continuous_closed_in_preimage_constant:
  fixes f :: "_ \<Rightarrow> 'b::t1_space"
  shows "continuous_on s f ==> closedin (subtopology euclidean s) {x \<in> s. f x = a}"
  using continuous_closed_in_preimage[of s f "{a}"] by auto

lemma continuous_closed_preimage_constant:
  fixes f :: "_ \<Rightarrow> 'b::t1_space"
  shows "continuous_on s f \<Longrightarrow> closed s ==> closed {x \<in> s. f x = a}"
  using continuous_closed_preimage[of s f "{a}"] by auto

lemma continuous_constant_on_closure:
  fixes f :: "_ \<Rightarrow> 'b::t1_space"
  assumes "continuous_on (closure s) f"
          "\<forall>x \<in> s. f x = a"
  shows "\<forall>x \<in> (closure s). f x = a"
    using continuous_closed_preimage_constant[of "closure s" f a]
    assms closure_minimal[of s "{x \<in> closure s. f x = a}"] closure_subset unfolding subset_eq by auto

lemma image_closure_subset:
  assumes "continuous_on (closure s) f"  "closed t"  "(f ` s) \<subseteq> t"
  shows "f ` (closure s) \<subseteq> t"
proof-
  have "s \<subseteq> {x \<in> closure s. f x \<in> t}" using assms(3) closure_subset by auto
  moreover have "closed {x \<in> closure s. f x \<in> t}"
    using continuous_closed_preimage[OF assms(1)] and assms(2) by auto
  ultimately have "closure s = {x \<in> closure s . f x \<in> t}"
    using closure_minimal[of s "{x \<in> closure s. f x \<in> t}"] by auto
  thus ?thesis by auto
qed

lemma continuous_on_closure_norm_le:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::real_normed_vector"
  assumes "continuous_on (closure s) f"  "\<forall>y \<in> s. norm(f y) \<le> b"  "x \<in> (closure s)"
  shows "norm(f x) \<le> b"
proof-
  have *:"f ` s \<subseteq> cball 0 b" using assms(2)[unfolded mem_cball_0[THEN sym]] by auto
  show ?thesis
    using image_closure_subset[OF assms(1) closed_cball[of 0 b] *] assms(3)
    unfolding subset_eq apply(erule_tac x="f x" in ballE) by (auto simp add: dist_norm)
qed

text {* Making a continuous function avoid some value in a neighbourhood. *}

lemma continuous_within_avoid:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::t1_space"
  assumes "continuous (at x within s) f" and "f x \<noteq> a"
  shows "\<exists>e>0. \<forall>y \<in> s. dist x y < e --> f y \<noteq> a"
proof-
  obtain U where "open U" and "f x \<in> U" and "a \<notin> U"
    using t1_space [OF `f x \<noteq> a`] by fast
  have "(f ---> f x) (at x within s)"
    using assms(1) by (simp add: continuous_within)
  hence "eventually (\<lambda>y. f y \<in> U) (at x within s)"
    using `open U` and `f x \<in> U`
    unfolding tendsto_def by fast
  hence "eventually (\<lambda>y. f y \<noteq> a) (at x within s)"
    using `a \<notin> U` by (fast elim: eventually_mono [rotated])
  thus ?thesis
    unfolding Limits.eventually_within Limits.eventually_at
    by (rule ex_forward, cut_tac `f x \<noteq> a`, auto simp: dist_commute)
qed

lemma continuous_at_avoid:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::t1_space"
  assumes "continuous (at x) f" and "f x \<noteq> a"
  shows "\<exists>e>0. \<forall>y. dist x y < e \<longrightarrow> f y \<noteq> a"
  using assms continuous_within_avoid[of x UNIV f a] by simp

lemma continuous_on_avoid:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::t1_space"
  assumes "continuous_on s f"  "x \<in> s"  "f x \<noteq> a"
  shows "\<exists>e>0. \<forall>y \<in> s. dist x y < e \<longrightarrow> f y \<noteq> a"
using assms(1)[unfolded continuous_on_eq_continuous_within, THEN bspec[where x=x], OF assms(2)]  continuous_within_avoid[of x s f a]  assms(3) by auto

lemma continuous_on_open_avoid:
  fixes f :: "'a::metric_space \<Rightarrow> 'b::t1_space"
  assumes "continuous_on s f"  "open s"  "x \<in> s"  "f x \<noteq> a"
  shows "\<exists>e>0. \<forall>y. dist x y < e \<longrightarrow> f y \<noteq> a"
using assms(1)[unfolded continuous_on_eq_continuous_at[OF assms(2)], THEN bspec[where x=x], OF assms(3)]  continuous_at_avoid[of x f a]  assms(4) by auto

text {* Proving a function is constant by proving open-ness of level set. *}

lemma continuous_levelset_open_in_cases:
  fixes f :: "_ \<Rightarrow> 'b::t1_space"
  shows "connected s \<Longrightarrow> continuous_on s f \<Longrightarrow>
        openin (subtopology euclidean s) {x \<in> s. f x = a}
        ==> (\<forall>x \<in> s. f x \<noteq> a) \<or> (\<forall>x \<in> s. f x = a)"
unfolding connected_clopen using continuous_closed_in_preimage_constant by auto

lemma continuous_levelset_open_in:
  fixes f :: "_ \<Rightarrow> 'b::t1_space"
  shows "connected s \<Longrightarrow> continuous_on s f \<Longrightarrow>
        openin (subtopology euclidean s) {x \<in> s. f x = a} \<Longrightarrow>
        (\<exists>x \<in> s. f x = a)  ==> (\<forall>x \<in> s. f x = a)"
using continuous_levelset_open_in_cases[of s f ]
by meson

lemma continuous_levelset_open:
  fixes f :: "_ \<Rightarrow> 'b::t1_space"
  assumes "connected s"  "continuous_on s f"  "open {x \<in> s. f x = a}"  "\<exists>x \<in> s.  f x = a"
  shows "\<forall>x \<in> s. f x = a"
using continuous_levelset_open_in[OF assms(1,2), of a, unfolded openin_open] using assms (3,4) by fast

text {* Some arithmetical combinations (more to prove). *}

lemma open_scaling[intro]:
  fixes s :: "'a::real_normed_vector set"
  assumes "c \<noteq> 0"  "open s"
  shows "open((\<lambda>x. c *\<^sub>R x) ` s)"
proof-
  { fix x assume "x \<in> s"
    then obtain e where "e>0" and e:"\<forall>x'. dist x' x < e \<longrightarrow> x' \<in> s" using assms(2)[unfolded open_dist, THEN bspec[where x=x]] by auto
    have "e * abs c > 0" using assms(1)[unfolded zero_less_abs_iff[THEN sym]] using mult_pos_pos[OF `e>0`] by auto
    moreover
    { fix y assume "dist y (c *\<^sub>R x) < e * \<bar>c\<bar>"
      hence "norm ((1 / c) *\<^sub>R y - x) < e" unfolding dist_norm
        using norm_scaleR[of c "(1 / c) *\<^sub>R y - x", unfolded scaleR_right_diff_distrib, unfolded scaleR_scaleR] assms(1)
          assms(1)[unfolded zero_less_abs_iff[THEN sym]] by (simp del:zero_less_abs_iff)
      hence "y \<in> op *\<^sub>R c ` s" using rev_image_eqI[of "(1 / c) *\<^sub>R y" s y "op *\<^sub>R c"]  e[THEN spec[where x="(1 / c) *\<^sub>R y"]]  assms(1) unfolding dist_norm scaleR_scaleR by auto  }
    ultimately have "\<exists>e>0. \<forall>x'. dist x' (c *\<^sub>R x) < e \<longrightarrow> x' \<in> op *\<^sub>R c ` s" apply(rule_tac x="e * abs c" in exI) by auto  }
  thus ?thesis unfolding open_dist by auto
qed

lemma minus_image_eq_vimage:
  fixes A :: "'a::ab_group_add set"
  shows "(\<lambda>x. - x) ` A = (\<lambda>x. - x) -` A"
  by (auto intro!: image_eqI [where f="\<lambda>x. - x"])

lemma open_negations:
  fixes s :: "'a::real_normed_vector set"
  shows "open s ==> open ((\<lambda> x. -x) ` s)"
  unfolding scaleR_minus1_left [symmetric]
  by (rule open_scaling, auto)

lemma open_translation:
  fixes s :: "'a::real_normed_vector set"
  assumes "open s"  shows "open((\<lambda>x. a + x) ` s)"
proof-
  { fix x have "continuous (at x) (\<lambda>x. x - a)"
      by (intro continuous_diff continuous_at_id continuous_const) }
  moreover have "{x. x - a \<in> s} = op + a ` s" by force
  ultimately show ?thesis using continuous_open_preimage_univ[of "\<lambda>x. x - a" s] using assms by auto
qed

lemma open_affinity:
  fixes s :: "'a::real_normed_vector set"
  assumes "open s"  "c \<noteq> 0"
  shows "open ((\<lambda>x. a + c *\<^sub>R x) ` s)"
proof-
  have *:"(\<lambda>x. a + c *\<^sub>R x) = (\<lambda>x. a + x) \<circ> (\<lambda>x. c *\<^sub>R x)" unfolding o_def ..
  have "op + a ` op *\<^sub>R c ` s = (op + a \<circ> op *\<^sub>R c) ` s" by auto
  thus ?thesis using assms open_translation[of "op *\<^sub>R c ` s" a] unfolding * by auto
qed

lemma interior_translation:
  fixes s :: "'a::real_normed_vector set"
  shows "interior ((\<lambda>x. a + x) ` s) = (\<lambda>x. a + x) ` (interior s)"
proof (rule set_eqI, rule)
  fix x assume "x \<in> interior (op + a ` s)"
  then obtain e where "e>0" and e:"ball x e \<subseteq> op + a ` s" unfolding mem_interior by auto
  hence "ball (x - a) e \<subseteq> s" unfolding subset_eq Ball_def mem_ball dist_norm apply auto apply(erule_tac x="a + xa" in allE) unfolding ab_group_add_class.diff_diff_eq[THEN sym] by auto
  thus "x \<in> op + a ` interior s" unfolding image_iff apply(rule_tac x="x - a" in bexI) unfolding mem_interior using `e > 0` by auto
next
  fix x assume "x \<in> op + a ` interior s"
  then obtain y e where "e>0" and e:"ball y e \<subseteq> s" and y:"x = a + y" unfolding image_iff Bex_def mem_interior by auto
  { fix z have *:"a + y - z = y + a - z" by auto
    assume "z\<in>ball x e"
    hence "z - a \<in> s" using e[unfolded subset_eq, THEN bspec[where x="z - a"]] unfolding mem_ball dist_norm y group_add_class.diff_diff_eq2 * by auto
    hence "z \<in> op + a ` s" unfolding image_iff by(auto intro!: bexI[where x="z - a"])  }
  hence "ball x e \<subseteq> op + a ` s" unfolding subset_eq by auto
  thus "x \<in> interior (op + a ` s)" unfolding mem_interior using `e>0` by auto
qed

text {* Topological properties of linear functions. *}

lemma linear_lim_0:
  assumes "bounded_linear f" shows "(f ---> 0) (at (0))"
proof-
  interpret f: bounded_linear f by fact
  have "(f ---> f 0) (at 0)"
    using tendsto_ident_at by (rule f.tendsto)
  thus ?thesis unfolding f.zero .
qed

lemma linear_continuous_at:
  assumes "bounded_linear f"  shows "continuous (at a) f"
  unfolding continuous_at using assms
  apply (rule bounded_linear.tendsto)
  apply (rule tendsto_ident_at)
  done

lemma linear_continuous_within:
  shows "bounded_linear f ==> continuous (at x within s) f"
  using continuous_at_imp_continuous_within[of x f s] using linear_continuous_at[of f] by auto

lemma linear_continuous_on:
  shows "bounded_linear f ==> continuous_on s f"
  using continuous_at_imp_continuous_on[of s f] using linear_continuous_at[of f] by auto

text {* Also bilinear functions, in composition form. *}

lemma bilinear_continuous_at_compose:
  shows "continuous (at x) f \<Longrightarrow> continuous (at x) g \<Longrightarrow> bounded_bilinear h
        ==> continuous (at x) (\<lambda>x. h (f x) (g x))"
  unfolding continuous_at using Lim_bilinear[of f "f x" "(at x)" g "g x" h] by auto

lemma bilinear_continuous_within_compose:
  shows "continuous (at x within s) f \<Longrightarrow> continuous (at x within s) g \<Longrightarrow> bounded_bilinear h
        ==> continuous (at x within s) (\<lambda>x. h (f x) (g x))"
  unfolding continuous_within using Lim_bilinear[of f "f x"] by auto

lemma bilinear_continuous_on_compose:
  shows "continuous_on s f \<Longrightarrow> continuous_on s g \<Longrightarrow> bounded_bilinear h
             ==> continuous_on s (\<lambda>x. h (f x) (g x))"
  unfolding continuous_on_def
  by (fast elim: bounded_bilinear.tendsto)

text {* Preservation of compactness and connectedness under continuous function. *}

lemma compact_eq_openin_cover:
  "compact S \<longleftrightarrow>
    (\<forall>C. (\<forall>c\<in>C. openin (subtopology euclidean S) c) \<and> S \<subseteq> \<Union>C \<longrightarrow>
      (\<exists>D\<subseteq>C. finite D \<and> S \<subseteq> \<Union>D))"
proof safe
  fix C
  assume "compact S" and "\<forall>c\<in>C. openin (subtopology euclidean S) c" and "S \<subseteq> \<Union>C"
  hence "\<forall>c\<in>{T. open T \<and> S \<inter> T \<in> C}. open c" and "S \<subseteq> \<Union>{T. open T \<and> S \<inter> T \<in> C}"
    unfolding openin_open by force+
  with `compact S` obtain D where "D \<subseteq> {T. open T \<and> S \<inter> T \<in> C}" and "finite D" and "S \<subseteq> \<Union>D"
    by (rule compactE)
  hence "image (\<lambda>T. S \<inter> T) D \<subseteq> C \<and> finite (image (\<lambda>T. S \<inter> T) D) \<and> S \<subseteq> \<Union>(image (\<lambda>T. S \<inter> T) D)"
    by auto
  thus "\<exists>D\<subseteq>C. finite D \<and> S \<subseteq> \<Union>D" ..
next
  assume 1: "\<forall>C. (\<forall>c\<in>C. openin (subtopology euclidean S) c) \<and> S \<subseteq> \<Union>C \<longrightarrow>
        (\<exists>D\<subseteq>C. finite D \<and> S \<subseteq> \<Union>D)"
  show "compact S"
  proof (rule compactI)
    fix C
    let ?C = "image (\<lambda>T. S \<inter> T) C"
    assume "\<forall>t\<in>C. open t" and "S \<subseteq> \<Union>C"
    hence "(\<forall>c\<in>?C. openin (subtopology euclidean S) c) \<and> S \<subseteq> \<Union>?C"
      unfolding openin_open by auto
    with 1 obtain D where "D \<subseteq> ?C" and "finite D" and "S \<subseteq> \<Union>D"
      by metis
    let ?D = "inv_into C (\<lambda>T. S \<inter> T) ` D"
    have "?D \<subseteq> C \<and> finite ?D \<and> S \<subseteq> \<Union>?D"
    proof (intro conjI)
      from `D \<subseteq> ?C` show "?D \<subseteq> C"
        by (fast intro: inv_into_into)
      from `finite D` show "finite ?D"
        by (rule finite_imageI)
      from `S \<subseteq> \<Union>D` show "S \<subseteq> \<Union>?D"
        apply (rule subset_trans)
        apply clarsimp
        apply (frule subsetD [OF `D \<subseteq> ?C`, THEN f_inv_into_f])
        apply (erule rev_bexI, fast)
        done
    qed
    thus "\<exists>D\<subseteq>C. finite D \<and> S \<subseteq> \<Union>D" ..
  qed
qed

lemma compact_continuous_image:
  assumes "continuous_on s f" and "compact s"
  shows "compact (f ` s)"
using assms (* FIXME: long unstructured proof *)
unfolding continuous_on_open
unfolding compact_eq_openin_cover
apply clarify
apply (drule_tac x="image (\<lambda>t. {x \<in> s. f x \<in> t}) C" in spec)
apply (drule mp)
apply (rule conjI)
apply simp
apply clarsimp
apply (drule subsetD)
apply (erule imageI)
apply fast
apply (erule thin_rl)
apply clarify
apply (rule_tac x="image (inv_into C (\<lambda>t. {x \<in> s. f x \<in> t})) D" in exI)
apply (intro conjI)
apply clarify
apply (rule inv_into_into)
apply (erule (1) subsetD)
apply (erule finite_imageI)
apply (clarsimp, rename_tac x)
apply (drule (1) subsetD, clarify)
apply (drule (1) subsetD, clarify)
apply (rule rev_bexI)
apply assumption
apply (subgoal_tac "{x \<in> s. f x \<in> t} \<in> (\<lambda>t. {x \<in> s. f x \<in> t}) ` C")
apply (drule f_inv_into_f)
apply fast
apply (erule imageI)
done

lemma connected_continuous_image:
  assumes "continuous_on s f"  "connected s"
  shows "connected(f ` s)"
proof-
  { fix T assume as: "T \<noteq> {}"  "T \<noteq> f ` s"  "openin (subtopology euclidean (f ` s)) T"  "closedin (subtopology euclidean (f ` s)) T"
    have "{x \<in> s. f x \<in> T} = {} \<or> {x \<in> s. f x \<in> T} = s"
      using assms(1)[unfolded continuous_on_open, THEN spec[where x=T]]
      using assms(1)[unfolded continuous_on_closed, THEN spec[where x=T]]
      using assms(2)[unfolded connected_clopen, THEN spec[where x="{x \<in> s. f x \<in> T}"]] as(3,4) by auto
    hence False using as(1,2)
      using as(4)[unfolded closedin_def topspace_euclidean_subtopology] by auto }
  thus ?thesis unfolding connected_clopen by auto
qed

text {* Continuity implies uniform continuity on a compact domain. *}
  
lemma compact_uniformly_continuous:
  assumes f: "continuous_on s f" and s: "compact s"
  shows "uniformly_continuous_on s f"
  unfolding uniformly_continuous_on_def
proof (cases, safe)
  fix e :: real assume "0 < e" "s \<noteq> {}"
  def [simp]: R \<equiv> "{(y, d). y \<in> s \<and> 0 < d \<and> ball y d \<inter> s \<subseteq> {x \<in> s. f x \<in> ball (f y) (e/2) } }"
  let ?b = "(\<lambda>(y, d). ball y (d/2))"
  have "(\<forall>r\<in>R. open (?b r))" "s \<subseteq> (\<Union>r\<in>R. ?b r)"
  proof safe
    fix y assume "y \<in> s"
    from continuous_open_in_preimage[OF f open_ball]
    obtain T where "open T" and T: "{x \<in> s. f x \<in> ball (f y) (e/2)} = T \<inter> s"
      unfolding openin_subtopology open_openin by metis
    then obtain d where "ball y d \<subseteq> T" "0 < d"
      using `0 < e` `y \<in> s` by (auto elim!: openE)
    with T `y \<in> s` show "y \<in> (\<Union>r\<in>R. ?b r)"
      by (intro UN_I[of "(y, d)"]) auto
  qed auto
  with s obtain D where D: "finite D" "D \<subseteq> R" "s \<subseteq> (\<Union>(y, d)\<in>D. ball y (d/2))"
    by (rule compactE_image)
  with `s \<noteq> {}` have [simp]: "\<And>x. x < Min (snd ` D) \<longleftrightarrow> (\<forall>(y, d)\<in>D. x < d)"
    by (subst Min_gr_iff) auto
  show "\<exists>d>0. \<forall>x\<in>s. \<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist (f x') (f x) < e"
  proof (rule, safe)
    fix x x' assume in_s: "x' \<in> s" "x \<in> s"
    with D obtain y d where x: "x \<in> ball y (d/2)" "(y, d) \<in> D"
      by blast
    moreover assume "dist x x' < Min (snd`D) / 2"
    ultimately have "dist y x' < d"
      by (intro dist_double[where x=x and d=d]) (auto simp: dist_commute)
    with D x in_s show  "dist (f x) (f x') < e"
      by (intro dist_double[where x="f y" and d=e]) (auto simp: dist_commute subset_eq)
  qed (insert D, auto)
qed auto

text{* Continuity of inverse function on compact domain. *}

lemma continuous_on_inv:
  fixes f :: "'a::topological_space \<Rightarrow> 'b::t2_space"
  assumes "continuous_on s f"  "compact s"  "\<forall>x \<in> s. g (f x) = x"
  shows "continuous_on (f ` s) g"
unfolding continuous_on_topological
proof (clarsimp simp add: assms(3))
  fix x :: 'a and B :: "'a set"
  assume "x \<in> s" and "open B" and "x \<in> B"
  have 1: "\<forall>x\<in>s. f x \<in> f ` (s - B) \<longleftrightarrow> x \<in> s - B"
    using assms(3) by (auto, metis)
  have "continuous_on (s - B) f"
    using `continuous_on s f` Diff_subset
    by (rule continuous_on_subset)
  moreover have "compact (s - B)"
    using `open B` and `compact s`
    unfolding Diff_eq by (intro compact_inter_closed closed_Compl)
  ultimately have "compact (f ` (s - B))"
    by (rule compact_continuous_image)
  hence "closed (f ` (s - B))"
    by (rule compact_imp_closed)
  hence "open (- f ` (s - B))"
    by (rule open_Compl)
  moreover have "f x \<in> - f ` (s - B)"
    using `x \<in> s` and `x \<in> B` by (simp add: 1)
  moreover have "\<forall>y\<in>s. f y \<in> - f ` (s - B) \<longrightarrow> y \<in> B"
    by (simp add: 1)
  ultimately show "\<exists>A. open A \<and> f x \<in> A \<and> (\<forall>y\<in>s. f y \<in> A \<longrightarrow> y \<in> B)"
    by fast
qed

text {* A uniformly convergent limit of continuous functions is continuous. *}

lemma continuous_uniform_limit:
  fixes f :: "'a \<Rightarrow> 'b::metric_space \<Rightarrow> 'c::metric_space"
  assumes "\<not> trivial_limit F"
  assumes "eventually (\<lambda>n. continuous_on s (f n)) F"
  assumes "\<forall>e>0. eventually (\<lambda>n. \<forall>x\<in>s. dist (f n x) (g x) < e) F"
  shows "continuous_on s g"
proof-
  { fix x and e::real assume "x\<in>s" "e>0"
    have "eventually (\<lambda>n. \<forall>x\<in>s. dist (f n x) (g x) < e / 3) F"
      using `e>0` assms(3)[THEN spec[where x="e/3"]] by auto
    from eventually_happens [OF eventually_conj [OF this assms(2)]]
    obtain n where n:"\<forall>x\<in>s. dist (f n x) (g x) < e / 3"  "continuous_on s (f n)"
      using assms(1) by blast
    have "e / 3 > 0" using `e>0` by auto
    then obtain d where "d>0" and d:"\<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist (f n x') (f n x) < e / 3"
      using n(2)[unfolded continuous_on_iff, THEN bspec[where x=x], OF `x\<in>s`, THEN spec[where x="e/3"]] by blast
    { fix y assume "y \<in> s" and "dist y x < d"
      hence "dist (f n y) (f n x) < e / 3"
        by (rule d [rule_format])
      hence "dist (f n y) (g x) < 2 * e / 3"
        using dist_triangle [of "f n y" "g x" "f n x"]
        using n(1)[THEN bspec[where x=x], OF `x\<in>s`]
        by auto
      hence "dist (g y) (g x) < e"
        using n(1)[THEN bspec[where x=y], OF `y\<in>s`]
        using dist_triangle3 [of "g y" "g x" "f n y"]
        by auto }
    hence "\<exists>d>0. \<forall>x'\<in>s. dist x' x < d \<longrightarrow> dist (g x') (g x) < e"
      using `d>0` by auto }
  thus ?thesis unfolding continuous_on_iff by auto
qed


subsection {* Topological stuff lifted from and dropped to R *}

lemma open_real:
  fixes s :: "real set" shows
 "open s \<longleftrightarrow>
        (\<forall>x \<in> s. \<exists>e>0. \<forall>x'. abs(x' - x) < e --> x' \<in> s)" (is "?lhs = ?rhs")
  unfolding open_dist dist_norm by simp

lemma islimpt_approachable_real:
  fixes s :: "real set"
  shows "x islimpt s \<longleftrightarrow> (\<forall>e>0.  \<exists>x'\<in> s. x' \<noteq> x \<and> abs(x' - x) < e)"
  unfolding islimpt_approachable dist_norm by simp

lemma closed_real:
  fixes s :: "real set"
  shows "closed s \<longleftrightarrow>
        (\<forall>x. (\<forall>e>0.  \<exists>x' \<in> s. x' \<noteq> x \<and> abs(x' - x) < e)
            --> x \<in> s)"
  unfolding closed_limpt islimpt_approachable dist_norm by simp

lemma continuous_at_real_range:
  fixes f :: "'a::real_normed_vector \<Rightarrow> real"
  shows "continuous (at x) f \<longleftrightarrow> (\<forall>e>0. \<exists>d>0.
        \<forall>x'. norm(x' - x) < d --> abs(f x' - f x) < e)"
  unfolding continuous_at unfolding Lim_at
  unfolding dist_nz[THEN sym] unfolding dist_norm apply auto
  apply(erule_tac x=e in allE) apply auto apply (rule_tac x=d in exI) apply auto apply (erule_tac x=x' in allE) apply auto
  apply(erule_tac x=e in allE) by auto

lemma continuous_on_real_range:
  fixes f :: "'a::real_normed_vector \<Rightarrow> real"
  shows "continuous_on s f \<longleftrightarrow> (\<forall>x \<in> s. \<forall>e>0. \<exists>d>0. (\<forall>x' \<in> s. norm(x' - x) < d --> abs(f x' - f x) < e))"
  unfolding continuous_on_iff dist_norm by simp

text {* Hence some handy theorems on distance, diameter etc. of/from a set. *}

lemma compact_attains_sup:
  fixes s :: "real set"
  assumes "compact s"  "s \<noteq> {}"
  shows "\<exists>x \<in> s. \<forall>y \<in> s. y \<le> x"
proof-
  from assms(1) have a:"bounded s" "closed s" unfolding compact_eq_bounded_closed by auto
  { fix e::real assume as: "\<forall>x\<in>s. x \<le> Sup s" "Sup s \<notin> s"  "0 < e" "\<forall>x'\<in>s. x' = Sup s \<or> \<not> Sup s - x' < e"
    have "isLub UNIV s (Sup s)" using Sup[OF assms(2)] unfolding setle_def using as(1) by auto
    moreover have "isUb UNIV s (Sup s - e)" unfolding isUb_def unfolding setle_def using as(4,2) by auto
    ultimately have False using isLub_le_isUb[of UNIV s "Sup s" "Sup s - e"] using `e>0` by auto  }
  thus ?thesis using bounded_has_Sup(1)[OF a(1) assms(2)] using a(2)[unfolded closed_real, THEN spec[where x="Sup s"]]
    apply(rule_tac x="Sup s" in bexI) by auto
qed

lemma Inf:
  fixes S :: "real set"
  shows "S \<noteq> {} ==> (\<exists>b. b <=* S) ==> isGlb UNIV S (Inf S)"
by (auto simp add: isLb_def setle_def setge_def isGlb_def greatestP_def) 

lemma compact_attains_inf:
  fixes s :: "real set"
  assumes "compact s" "s \<noteq> {}"  shows "\<exists>x \<in> s. \<forall>y \<in> s. x \<le> y"
proof-
  from assms(1) have a:"bounded s" "closed s" unfolding compact_eq_bounded_closed by auto
  { fix e::real assume as: "\<forall>x\<in>s. x \<ge> Inf s"  "Inf s \<notin> s"  "0 < e"
      "\<forall>x'\<in>s. x' = Inf s \<or> \<not> abs (x' - Inf s) < e"
    have "isGlb UNIV s (Inf s)" using Inf[OF assms(2)] unfolding setge_def using as(1) by auto
    moreover
    { fix x assume "x \<in> s"
      hence *:"abs (x - Inf s) = x - Inf s" using as(1)[THEN bspec[where x=x]] by auto
      have "Inf s + e \<le> x" using as(4)[THEN bspec[where x=x]] using as(2) `x\<in>s` unfolding * by auto }
    hence "isLb UNIV s (Inf s + e)" unfolding isLb_def and setge_def by auto
    ultimately have False using isGlb_le_isLb[of UNIV s "Inf s" "Inf s + e"] using `e>0` by auto  }
  thus ?thesis using bounded_has_Inf(1)[OF a(1) assms(2)] using a(2)[unfolded closed_real, THEN spec[where x="Inf s"]]
    apply(rule_tac x="Inf s" in bexI) by auto
qed

lemma continuous_attains_sup:
  fixes f :: "'a::topological_space \<Rightarrow> real"
  shows "compact s \<Longrightarrow> s \<noteq> {} \<Longrightarrow> continuous_on s f
        ==> (\<exists>x \<in> s. \<forall>y \<in> s.  f y \<le> f x)"
  using compact_attains_sup[of "f ` s"]
  using compact_continuous_image[of s f] by auto

lemma continuous_attains_inf:
  fixes f :: "'a::topological_space \<Rightarrow> real"
  shows "compact s \<Longrightarrow> s \<noteq> {} \<Longrightarrow> continuous_on s f
        \<Longrightarrow> (\<exists>x \<in> s. \<forall>y \<in> s. f x \<le> f y)"
  using compact_attains_inf[of "f ` s"]
  using compact_continuous_image[of s f] by auto

lemma distance_attains_sup:
  assumes "compact s" "s \<noteq> {}"
  shows "\<exists>x \<in> s. \<forall>y \<in> s. dist a y \<le> dist a x"
proof (rule continuous_attains_sup [OF assms])
  { fix x assume "x\<in>s"
    have "(dist a ---> dist a x) (at x within s)"
      by (intro tendsto_dist tendsto_const Lim_at_within tendsto_ident_at)
  }
  thus "continuous_on s (dist a)"
    unfolding continuous_on ..
qed

text {* For \emph{minimal} distance, we only need closure, not compactness. *}

lemma distance_attains_inf:
  fixes a :: "'a::heine_borel"
  assumes "closed s"  "s \<noteq> {}"
  shows "\<exists>x \<in> s. \<forall>y \<in> s. dist a x \<le> dist a y"
proof-
  from assms(2) obtain b where "b\<in>s" by auto
  let ?B = "cball a (dist b a) \<inter> s"
  have "b \<in> ?B" using `b\<in>s` by (simp add: dist_commute)
  hence "?B \<noteq> {}" by auto
  moreover
  { fix x assume "x\<in>?B"
    fix e::real assume "e>0"
    { fix x' assume "x'\<in>?B" and as:"dist x' x < e"
      from as have "\<bar>dist a x' - dist a x\<bar> < e"
        unfolding abs_less_iff minus_diff_eq
        using dist_triangle2 [of a x' x]
        using dist_triangle [of a x x']
        by arith
    }
    hence "\<exists>d>0. \<forall>x'\<in>?B. dist x' x < d \<longrightarrow> \<bar>dist a x' - dist a x\<bar> < e"
      using `e>0` by auto
  }
  hence "continuous_on (cball a (dist b a) \<inter> s) (dist a)"
    unfolding continuous_on Lim_within dist_norm real_norm_def
    by fast
  moreover have "compact ?B"
    using compact_cball[of a "dist b a"]
    unfolding compact_eq_bounded_closed
    using bounded_Int and closed_Int and assms(1) by auto
  ultimately obtain x where "x\<in>cball a (dist b a) \<inter> s" "\<forall>y\<in>cball a (dist b a) \<inter> s. dist a x \<le> dist a y"
    using continuous_attains_inf[of ?B "dist a"] by fastforce
  thus ?thesis by fastforce
qed


subsection {* Pasted sets *}

lemma bounded_Times:
  assumes "bounded s" "bounded t" shows "bounded (s \<times> t)"
proof-
  obtain x y a b where "\<forall>z\<in>s. dist x z \<le> a" "\<forall>z\<in>t. dist y z \<le> b"
    using assms [unfolded bounded_def] by auto
  then have "\<forall>z\<in>s \<times> t. dist (x, y) z \<le> sqrt (a\<twosuperior> + b\<twosuperior>)"
    by (auto simp add: dist_Pair_Pair real_sqrt_le_mono add_mono power_mono)
  thus ?thesis unfolding bounded_any_center [where a="(x, y)"] by auto
qed

lemma mem_Times_iff: "x \<in> A \<times> B \<longleftrightarrow> fst x \<in> A \<and> snd x \<in> B"
by (induct x) simp

lemma seq_compact_Times: "seq_compact s \<Longrightarrow> seq_compact t \<Longrightarrow> seq_compact (s \<times> t)"
unfolding seq_compact_def
apply clarify
apply (drule_tac x="fst \<circ> f" in spec)
apply (drule mp, simp add: mem_Times_iff)
apply (clarify, rename_tac l1 r1)
apply (drule_tac x="snd \<circ> f \<circ> r1" in spec)
apply (drule mp, simp add: mem_Times_iff)
apply (clarify, rename_tac l2 r2)
apply (rule_tac x="(l1, l2)" in rev_bexI, simp)
apply (rule_tac x="r1 \<circ> r2" in exI)
apply (rule conjI, simp add: subseq_def)
apply (drule_tac f=r2 in LIMSEQ_subseq_LIMSEQ, assumption)
apply (drule (1) tendsto_Pair) back
apply (simp add: o_def)
done

text {* Generalize to @{class topological_space} *}
lemma compact_Times: 
  fixes s :: "'a::metric_space set" and t :: "'b::metric_space set"
  shows "compact s \<Longrightarrow> compact t \<Longrightarrow> compact (s \<times> t)"
  unfolding compact_eq_seq_compact_metric by (rule seq_compact_Times)

text{* Hence some useful properties follow quite easily. *}

lemma compact_scaling:
  fixes s :: "'a::real_normed_vector set"
  assumes "compact s"  shows "compact ((\<lambda>x. c *\<^sub>R x) ` s)"
proof-
  let ?f = "\<lambda>x. scaleR c x"
  have *:"bounded_linear ?f" by (rule bounded_linear_scaleR_right)
  show ?thesis using compact_continuous_image[of s ?f] continuous_at_imp_continuous_on[of s ?f]
    using linear_continuous_at[OF *] assms by auto
qed

lemma compact_negations:
  fixes s :: "'a::real_normed_vector set"
  assumes "compact s"  shows "compact ((\<lambda>x. -x) ` s)"
  using compact_scaling [OF assms, of "- 1"] by auto

lemma compact_sums:
  fixes s t :: "'a::real_normed_vector set"
  assumes "compact s"  "compact t"  shows "compact {x + y | x y. x \<in> s \<and> y \<in> t}"
proof-
  have *:"{x + y | x y. x \<in> s \<and> y \<in> t} = (\<lambda>z. fst z + snd z) ` (s \<times> t)"
    apply auto unfolding image_iff apply(rule_tac x="(xa, y)" in bexI) by auto
  have "continuous_on (s \<times> t) (\<lambda>z. fst z + snd z)"
    unfolding continuous_on by (rule ballI) (intro tendsto_intros)
  thus ?thesis unfolding * using compact_continuous_image compact_Times [OF assms] by auto
qed

lemma compact_differences:
  fixes s t :: "'a::real_normed_vector set"
  assumes "compact s" "compact t"  shows "compact {x - y | x y. x \<in> s \<and> y \<in> t}"
proof-
  have "{x - y | x y. x\<in>s \<and> y \<in> t} =  {x + y | x y. x \<in> s \<and> y \<in> (uminus ` t)}"
    apply auto apply(rule_tac x= xa in exI) apply auto apply(rule_tac x=xa in exI) by auto
  thus ?thesis using compact_sums[OF assms(1) compact_negations[OF assms(2)]] by auto
qed

lemma compact_translation:
  fixes s :: "'a::real_normed_vector set"
  assumes "compact s"  shows "compact ((\<lambda>x. a + x) ` s)"
proof-
  have "{x + y |x y. x \<in> s \<and> y \<in> {a}} = (\<lambda>x. a + x) ` s" by auto
  thus ?thesis using compact_sums[OF assms compact_sing[of a]] by auto
qed

lemma compact_affinity:
  fixes s :: "'a::real_normed_vector set"
  assumes "compact s"  shows "compact ((\<lambda>x. a + c *\<^sub>R x) ` s)"
proof-
  have "op + a ` op *\<^sub>R c ` s = (\<lambda>x. a + c *\<^sub>R x) ` s" by auto
  thus ?thesis using compact_translation[OF compact_scaling[OF assms], of a c] by auto
qed

text {* Hence we get the following. *}

lemma compact_sup_maxdistance:
  fixes s :: "'a::metric_space set"
  assumes "compact s"  "s \<noteq> {}"
  shows "\<exists>x\<in>s. \<exists>y\<in>s. \<forall>u\<in>s. \<forall>v\<in>s. dist u v \<le> dist x y"
proof-
  have "compact (s \<times> s)" using `compact s` by (intro compact_Times)
  moreover have "s \<times> s \<noteq> {}" using `s \<noteq> {}` by auto
  moreover have "continuous_on (s \<times> s) (\<lambda>x. dist (fst x) (snd x))"
    by (intro continuous_at_imp_continuous_on ballI continuous_dist
      continuous_isCont[THEN iffD1] isCont_fst isCont_snd isCont_ident)
  ultimately show ?thesis
    using continuous_attains_sup[of "s \<times> s" "\<lambda>x. dist (fst x) (snd x)"] by auto
qed

text {* We can state this in terms of diameter of a set. *}

definition "diameter s = (if s = {} then 0::real else Sup {dist x y | x y. x \<in> s \<and> y \<in> s})"

lemma diameter_bounded_bound:
  fixes s :: "'a :: metric_space set"
  assumes s: "bounded s" "x \<in> s" "y \<in> s"
  shows "dist x y \<le> diameter s"
proof -
  let ?D = "{dist x y |x y. x \<in> s \<and> y \<in> s}"
  from s obtain z d where z: "\<And>x. x \<in> s \<Longrightarrow> dist z x \<le> d"
    unfolding bounded_def by auto
  have "dist x y \<le> Sup ?D"
  proof (rule Sup_upper, safe)
    fix a b assume "a \<in> s" "b \<in> s"
    with z[of a] z[of b] dist_triangle[of a b z]
    show "dist a b \<le> 2 * d"
      by (simp add: dist_commute)
  qed (insert s, auto)
  with `x \<in> s` show ?thesis
    by (auto simp add: diameter_def)
qed

lemma diameter_lower_bounded:
  fixes s :: "'a :: metric_space set"
  assumes s: "bounded s" and d: "0 < d" "d < diameter s"
  shows "\<exists>x\<in>s. \<exists>y\<in>s. d < dist x y"
proof (rule ccontr)
  let ?D = "{dist x y |x y. x \<in> s \<and> y \<in> s}"
  assume contr: "\<not> ?thesis"
  moreover
  from d have "s \<noteq> {}"
    by (auto simp: diameter_def)
  then have "?D \<noteq> {}" by auto
  ultimately have "Sup ?D \<le> d"
    by (intro Sup_least) (auto simp: not_less)
  with `d < diameter s` `s \<noteq> {}` show False
    by (auto simp: diameter_def)
qed

lemma diameter_bounded:
  assumes "bounded s"
  shows "\<forall>x\<in>s. \<forall>y\<in>s. dist x y \<le> diameter s"
        "\<forall>d>0. d < diameter s \<longrightarrow> (\<exists>x\<in>s. \<exists>y\<in>s. dist x y > d)"
  using diameter_bounded_bound[of s] diameter_lower_bounded[of s] assms
  by auto

lemma diameter_compact_attained:
  assumes "compact s"  "s \<noteq> {}"
  shows "\<exists>x\<in>s. \<exists>y\<in>s. dist x y = diameter s"
proof -
  have b:"bounded s" using assms(1) by (rule compact_imp_bounded)
  then obtain x y where xys:"x\<in>s" "y\<in>s" and xy:"\<forall>u\<in>s. \<forall>v\<in>s. dist u v \<le> dist x y"
    using compact_sup_maxdistance[OF assms] by auto
  hence "diameter s \<le> dist x y"
    unfolding diameter_def by clarsimp (rule Sup_least, fast+)
  thus ?thesis
    by (metis b diameter_bounded_bound order_antisym xys)
qed

text {* Related results with closure as the conclusion. *}

lemma closed_scaling:
  fixes s :: "'a::real_normed_vector set"
  assumes "closed s" shows "closed ((\<lambda>x. c *\<^sub>R x) ` s)"
proof(cases "s={}")
  case True thus ?thesis by auto
next
  case False
  show ?thesis
  proof(cases "c=0")
    have *:"(\<lambda>x. 0) ` s = {0}" using `s\<noteq>{}` by auto
    case True thus ?thesis apply auto unfolding * by auto
  next
    case False
    { fix x l assume as:"\<forall>n::nat. x n \<in> scaleR c ` s"  "(x ---> l) sequentially"
      { fix n::nat have "scaleR (1 / c) (x n) \<in> s"
          using as(1)[THEN spec[where x=n]]
          using `c\<noteq>0` by auto
      }
      moreover
      { fix e::real assume "e>0"
        hence "0 < e *\<bar>c\<bar>"  using `c\<noteq>0` mult_pos_pos[of e "abs c"] by auto
        then obtain N where "\<forall>n\<ge>N. dist (x n) l < e * \<bar>c\<bar>"
          using as(2)[unfolded LIMSEQ_def, THEN spec[where x="e * abs c"]] by auto
        hence "\<exists>N. \<forall>n\<ge>N. dist (scaleR (1 / c) (x n)) (scaleR (1 / c) l) < e"
          unfolding dist_norm unfolding scaleR_right_diff_distrib[THEN sym]
          using mult_imp_div_pos_less[of "abs c" _ e] `c\<noteq>0` by auto  }
      hence "((\<lambda>n. scaleR (1 / c) (x n)) ---> scaleR (1 / c) l) sequentially" unfolding LIMSEQ_def by auto
      ultimately have "l \<in> scaleR c ` s"
        using assms[unfolded closed_sequential_limits, THEN spec[where x="\<lambda>n. scaleR (1/c) (x n)"], THEN spec[where x="scaleR (1/c) l"]]
        unfolding image_iff using `c\<noteq>0` apply(rule_tac x="scaleR (1 / c) l" in bexI) by auto  }
    thus ?thesis unfolding closed_sequential_limits by fast
  qed
qed

lemma closed_negations:
  fixes s :: "'a::real_normed_vector set"
  assumes "closed s"  shows "closed ((\<lambda>x. -x) ` s)"
  using closed_scaling[OF assms, of "- 1"] by simp

lemma compact_closed_sums:
  fixes s :: "'a::real_normed_vector set"
  assumes "compact s"  "closed t"  shows "closed {x + y | x y. x \<in> s \<and> y \<in> t}"
proof-
  let ?S = "{x + y |x y. x \<in> s \<and> y \<in> t}"
  { fix x l assume as:"\<forall>n. x n \<in> ?S"  "(x ---> l) sequentially"
    from as(1) obtain f where f:"\<forall>n. x n = fst (f n) + snd (f n)"  "\<forall>n. fst (f n) \<in> s"  "\<forall>n. snd (f n) \<in> t"
      using choice[of "\<lambda>n y. x n = (fst y) + (snd y) \<and> fst y \<in> s \<and> snd y \<in> t"] by auto
    obtain l' r where "l'\<in>s" and r:"subseq r" and lr:"(((\<lambda>n. fst (f n)) \<circ> r) ---> l') sequentially"
      using assms(1)[unfolded compact_def, THEN spec[where x="\<lambda> n. fst (f n)"]] using f(2) by auto
    have "((\<lambda>n. snd (f (r n))) ---> l - l') sequentially"
      using tendsto_diff[OF LIMSEQ_subseq_LIMSEQ[OF as(2) r] lr] and f(1) unfolding o_def by auto
    hence "l - l' \<in> t"
      using assms(2)[unfolded closed_sequential_limits, THEN spec[where x="\<lambda> n. snd (f (r n))"], THEN spec[where x="l - l'"]]
      using f(3) by auto
    hence "l \<in> ?S" using `l' \<in> s` apply auto apply(rule_tac x=l' in exI) apply(rule_tac x="l - l'" in exI) by auto
  }
  thus ?thesis unfolding closed_sequential_limits by fast
qed

lemma closed_compact_sums:
  fixes s t :: "'a::real_normed_vector set"
  assumes "closed s"  "compact t"
  shows "closed {x + y | x y. x \<in> s \<and> y \<in> t}"
proof-
  have "{x + y |x y. x \<in> t \<and> y \<in> s} = {x + y |x y. x \<in> s \<and> y \<in> t}" apply auto
    apply(rule_tac x=y in exI) apply auto apply(rule_tac x=y in exI) by auto
  thus ?thesis using compact_closed_sums[OF assms(2,1)] by simp
qed

lemma compact_closed_differences:
  fixes s t :: "'a::real_normed_vector set"
  assumes "compact s"  "closed t"
  shows "closed {x - y | x y. x \<in> s \<and> y \<in> t}"
proof-
  have "{x + y |x y. x \<in> s \<and> y \<in> uminus ` t} =  {x - y |x y. x \<in> s \<and> y \<in> t}"
    apply auto apply(rule_tac x=xa in exI) apply auto apply(rule_tac x=xa in exI) by auto
  thus ?thesis using compact_closed_sums[OF assms(1) closed_negations[OF assms(2)]] by auto
qed

lemma closed_compact_differences:
  fixes s t :: "'a::real_normed_vector set"
  assumes "closed s" "compact t"
  shows "closed {x - y | x y. x \<in> s \<and> y \<in> t}"
proof-
  have "{x + y |x y. x \<in> s \<and> y \<in> uminus ` t} = {x - y |x y. x \<in> s \<and> y \<in> t}"
    apply auto apply(rule_tac x=xa in exI) apply auto apply(rule_tac x=xa in exI) by auto
 thus ?thesis using closed_compact_sums[OF assms(1) compact_negations[OF assms(2)]] by simp
qed

lemma closed_translation:
  fixes a :: "'a::real_normed_vector"
  assumes "closed s"  shows "closed ((\<lambda>x. a + x) ` s)"
proof-
  have "{a + y |y. y \<in> s} = (op + a ` s)" by auto
  thus ?thesis using compact_closed_sums[OF compact_sing[of a] assms] by auto
qed

lemma translation_Compl:
  fixes a :: "'a::ab_group_add"
  shows "(\<lambda>x. a + x) ` (- t) = - ((\<lambda>x. a + x) ` t)"
  apply (auto simp add: image_iff) apply(rule_tac x="x - a" in bexI) by auto

lemma translation_UNIV:
  fixes a :: "'a::ab_group_add" shows "range (\<lambda>x. a + x) = UNIV"
  apply (auto simp add: image_iff) apply(rule_tac x="x - a" in exI) by auto

lemma translation_diff:
  fixes a :: "'a::ab_group_add"
  shows "(\<lambda>x. a + x) ` (s - t) = ((\<lambda>x. a + x) ` s) - ((\<lambda>x. a + x) ` t)"
  by auto

lemma closure_translation:
  fixes a :: "'a::real_normed_vector"
  shows "closure ((\<lambda>x. a + x) ` s) = (\<lambda>x. a + x) ` (closure s)"
proof-
  have *:"op + a ` (- s) = - op + a ` s"
    apply auto unfolding image_iff apply(rule_tac x="x - a" in bexI) by auto
  show ?thesis unfolding closure_interior translation_Compl
    using interior_translation[of a "- s"] unfolding * by auto
qed

lemma frontier_translation:
  fixes a :: "'a::real_normed_vector"
  shows "frontier((\<lambda>x. a + x) ` s) = (\<lambda>x. a + x) ` (frontier s)"
  unfolding frontier_def translation_diff interior_translation closure_translation by auto


subsection {* Separation between points and sets *}

lemma separate_point_closed:
  fixes s :: "'a::heine_borel set"
  shows "closed s \<Longrightarrow> a \<notin> s  ==> (\<exists>d>0. \<forall>x\<in>s. d \<le> dist a x)"
proof(cases "s = {}")
  case True
  thus ?thesis by(auto intro!: exI[where x=1])
next
  case False
  assume "closed s" "a \<notin> s"
  then obtain x where "x\<in>s" "\<forall>y\<in>s. dist a x \<le> dist a y" using `s \<noteq> {}` distance_attains_inf [of s a] by blast
  with `x\<in>s` show ?thesis using dist_pos_lt[of a x] and`a \<notin> s` by blast
qed

lemma separate_compact_closed:
  fixes s t :: "'a::heine_borel set"
  assumes "compact s" and "closed t" and "s \<inter> t = {}"
  shows "\<exists>d>0. \<forall>x\<in>s. \<forall>y\<in>t. d \<le> dist x y"
proof - (* FIXME: long proof *)
  let ?T = "\<Union>x\<in>s. { ball x (d / 2) | d. 0 < d \<and> (\<forall>y\<in>t. d \<le> dist x y) }"
  note `compact s`
  moreover have "\<forall>t\<in>?T. open t" by auto
  moreover have "s \<subseteq> \<Union>?T"
    apply auto
    apply (rule rev_bexI, assumption)
    apply (subgoal_tac "x \<notin> t")
    apply (drule separate_point_closed [OF `closed t`])
    apply clarify
    apply (rule_tac x="ball x (d / 2)" in exI)
    apply simp
    apply fast
    apply (cut_tac assms(3))
    apply auto
    done
  ultimately obtain U where "U \<subseteq> ?T" and "finite U" and "s \<subseteq> \<Union>U"
    by (rule compactE)
  from `finite U` and `U \<subseteq> ?T` have "\<exists>d>0. \<forall>x\<in>\<Union>U. \<forall>y\<in>t. d \<le> dist x y"
    apply (induct set: finite)
    apply simp
    apply (rule exI)
    apply (rule zero_less_one)
    apply clarsimp
    apply (rename_tac y e)
    apply (rule_tac x="min d (e / 2)" in exI)
    apply simp
    apply (subst ball_Un)
    apply (rule conjI)
    apply (intro ballI, rename_tac z)
    apply (rule min_max.le_infI2)
    apply (simp only: mem_ball)
    apply (drule (1) bspec)
    apply (cut_tac x=y and y=x and z=z in dist_triangle, arith)
    apply simp
    apply (intro ballI)
    apply (rule min_max.le_infI1)
    apply simp
    done
  with `s \<subseteq> \<Union>U` show ?thesis
    by fast
qed

lemma separate_closed_compact:
  fixes s t :: "'a::heine_borel set"
  assumes "closed s" and "compact t" and "s \<inter> t = {}"
  shows "\<exists>d>0. \<forall>x\<in>s. \<forall>y\<in>t. d \<le> dist x y"
proof-
  have *:"t \<inter> s = {}" using assms(3) by auto
  show ?thesis using separate_compact_closed[OF assms(2,1) *]
    apply auto apply(rule_tac x=d in exI) apply auto apply (erule_tac x=y in ballE)
    by (auto simp add: dist_commute)
qed


subsection {* Intervals *}
  
lemma interval: fixes a :: "'a::ordered_euclidean_space" shows
  "{a <..< b} = {x::'a. \<forall>i\<in>Basis. a\<bullet>i < x\<bullet>i \<and> x\<bullet>i < b\<bullet>i}" and
  "{a .. b} = {x::'a. \<forall>i\<in>Basis. a\<bullet>i \<le> x\<bullet>i \<and> x\<bullet>i \<le> b\<bullet>i}"
  by(auto simp add:set_eq_iff eucl_le[where 'a='a] eucl_less[where 'a='a])

lemma mem_interval: fixes a :: "'a::ordered_euclidean_space" shows
  "x \<in> {a<..<b} \<longleftrightarrow> (\<forall>i\<in>Basis. a\<bullet>i < x\<bullet>i \<and> x\<bullet>i < b\<bullet>i)"
  "x \<in> {a .. b} \<longleftrightarrow> (\<forall>i\<in>Basis. a\<bullet>i \<le> x\<bullet>i \<and> x\<bullet>i \<le> b\<bullet>i)"
  using interval[of a b] by(auto simp add: set_eq_iff eucl_le[where 'a='a] eucl_less[where 'a='a])

lemma interval_eq_empty: fixes a :: "'a::ordered_euclidean_space" shows
 "({a <..< b} = {} \<longleftrightarrow> (\<exists>i\<in>Basis. b\<bullet>i \<le> a\<bullet>i))" (is ?th1) and
 "({a  ..  b} = {} \<longleftrightarrow> (\<exists>i\<in>Basis. b\<bullet>i < a\<bullet>i))" (is ?th2)
proof-
  { fix i x assume i:"i\<in>Basis" and as:"b\<bullet>i \<le> a\<bullet>i" and x:"x\<in>{a <..< b}"
    hence "a \<bullet> i < x \<bullet> i \<and> x \<bullet> i < b \<bullet> i" unfolding mem_interval by auto
    hence "a\<bullet>i < b\<bullet>i" by auto
    hence False using as by auto  }
  moreover
  { assume as:"\<forall>i\<in>Basis. \<not> (b\<bullet>i \<le> a\<bullet>i)"
    let ?x = "(1/2) *\<^sub>R (a + b)"
    { fix i :: 'a assume i:"i\<in>Basis" 
      have "a\<bullet>i < b\<bullet>i" using as[THEN bspec[where x=i]] i by auto
      hence "a\<bullet>i < ((1/2) *\<^sub>R (a+b)) \<bullet> i" "((1/2) *\<^sub>R (a+b)) \<bullet> i < b\<bullet>i"
        by (auto simp: inner_add_left) }
    hence "{a <..< b} \<noteq> {}" using mem_interval(1)[of "?x" a b] by auto  }
  ultimately show ?th1 by blast

  { fix i x assume i:"i\<in>Basis" and as:"b\<bullet>i < a\<bullet>i" and x:"x\<in>{a .. b}"
    hence "a \<bullet> i \<le> x \<bullet> i \<and> x \<bullet> i \<le> b \<bullet> i" unfolding mem_interval by auto
    hence "a\<bullet>i \<le> b\<bullet>i" by auto
    hence False using as by auto  }
  moreover
  { assume as:"\<forall>i\<in>Basis. \<not> (b\<bullet>i < a\<bullet>i)"
    let ?x = "(1/2) *\<^sub>R (a + b)"
    { fix i :: 'a assume i:"i\<in>Basis"
      have "a\<bullet>i \<le> b\<bullet>i" using as[THEN bspec[where x=i]] i by auto
      hence "a\<bullet>i \<le> ((1/2) *\<^sub>R (a+b)) \<bullet> i" "((1/2) *\<^sub>R (a+b)) \<bullet> i \<le> b\<bullet>i"
        by (auto simp: inner_add_left) }
    hence "{a .. b} \<noteq> {}" using mem_interval(2)[of "?x" a b] by auto  }
  ultimately show ?th2 by blast
qed

lemma interval_ne_empty: fixes a :: "'a::ordered_euclidean_space" shows
  "{a  ..  b} \<noteq> {} \<longleftrightarrow> (\<forall>i\<in>Basis. a\<bullet>i \<le> b\<bullet>i)" and
  "{a <..< b} \<noteq> {} \<longleftrightarrow> (\<forall>i\<in>Basis. a\<bullet>i < b\<bullet>i)"
  unfolding interval_eq_empty[of a b] by fastforce+

lemma interval_sing:
  fixes a :: "'a::ordered_euclidean_space"
  shows "{a .. a} = {a}" and "{a<..<a} = {}"
  unfolding set_eq_iff mem_interval eq_iff [symmetric]
  by (auto intro: euclidean_eqI simp: ex_in_conv)

lemma subset_interval_imp: fixes a :: "'a::ordered_euclidean_space" shows
 "(\<forall>i\<in>Basis. a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i) \<Longrightarrow> {c .. d} \<subseteq> {a .. b}" and
 "(\<forall>i\<in>Basis. a\<bullet>i < c\<bullet>i \<and> d\<bullet>i < b\<bullet>i) \<Longrightarrow> {c .. d} \<subseteq> {a<..<b}" and
 "(\<forall>i\<in>Basis. a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i) \<Longrightarrow> {c<..<d} \<subseteq> {a .. b}" and
 "(\<forall>i\<in>Basis. a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i) \<Longrightarrow> {c<..<d} \<subseteq> {a<..<b}"
  unfolding subset_eq[unfolded Ball_def] unfolding mem_interval
  by (best intro: order_trans less_le_trans le_less_trans less_imp_le)+

lemma interval_open_subset_closed:
  fixes a :: "'a::ordered_euclidean_space"
  shows "{a<..<b} \<subseteq> {a .. b}"
  unfolding subset_eq [unfolded Ball_def] mem_interval
  by (fast intro: less_imp_le)

lemma subset_interval: fixes a :: "'a::ordered_euclidean_space" shows
 "{c .. d} \<subseteq> {a .. b} \<longleftrightarrow> (\<forall>i\<in>Basis. c\<bullet>i \<le> d\<bullet>i) --> (\<forall>i\<in>Basis. a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i)" (is ?th1) and
 "{c .. d} \<subseteq> {a<..<b} \<longleftrightarrow> (\<forall>i\<in>Basis. c\<bullet>i \<le> d\<bullet>i) --> (\<forall>i\<in>Basis. a\<bullet>i < c\<bullet>i \<and> d\<bullet>i < b\<bullet>i)" (is ?th2) and
 "{c<..<d} \<subseteq> {a .. b} \<longleftrightarrow> (\<forall>i\<in>Basis. c\<bullet>i < d\<bullet>i) --> (\<forall>i\<in>Basis. a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i)" (is ?th3) and
 "{c<..<d} \<subseteq> {a<..<b} \<longleftrightarrow> (\<forall>i\<in>Basis. c\<bullet>i < d\<bullet>i) --> (\<forall>i\<in>Basis. a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i)" (is ?th4)
proof-
  show ?th1 unfolding subset_eq and Ball_def and mem_interval by (auto intro: order_trans)
  show ?th2 unfolding subset_eq and Ball_def and mem_interval by (auto intro: le_less_trans less_le_trans order_trans less_imp_le)
  { assume as: "{c<..<d} \<subseteq> {a .. b}" "\<forall>i\<in>Basis. c\<bullet>i < d\<bullet>i"
    hence "{c<..<d} \<noteq> {}" unfolding interval_eq_empty by auto
    fix i :: 'a assume i:"i\<in>Basis"
    (** TODO combine the following two parts as done in the HOL_light version. **)
    { let ?x = "(\<Sum>j\<in>Basis. (if j=i then ((min (a\<bullet>j) (d\<bullet>j))+c\<bullet>j)/2 else (c\<bullet>j+d\<bullet>j)/2) *\<^sub>R j)::'a"
      assume as2: "a\<bullet>i > c\<bullet>i"
      { fix j :: 'a assume j:"j\<in>Basis"
        hence "c \<bullet> j < ?x \<bullet> j \<and> ?x \<bullet> j < d \<bullet> j"
          apply(cases "j=i") using as(2)[THEN bspec[where x=j]] i
          by (auto simp add: as2)  }
      hence "?x\<in>{c<..<d}" using i unfolding mem_interval by auto
      moreover
      have "?x\<notin>{a .. b}"
        unfolding mem_interval apply auto apply(rule_tac x=i in bexI)
        using as(2)[THEN bspec[where x=i]] and as2 i
        by auto
      ultimately have False using as by auto  }
    hence "a\<bullet>i \<le> c\<bullet>i" by(rule ccontr)auto
    moreover
    { let ?x = "(\<Sum>j\<in>Basis. (if j=i then ((max (b\<bullet>j) (c\<bullet>j))+d\<bullet>j)/2 else (c\<bullet>j+d\<bullet>j)/2) *\<^sub>R j)::'a"
      assume as2: "b\<bullet>i < d\<bullet>i"
      { fix j :: 'a assume "j\<in>Basis"
        hence "d \<bullet> j > ?x \<bullet> j \<and> ?x \<bullet> j > c \<bullet> j" 
          apply(cases "j=i") using as(2)[THEN bspec[where x=j]]
          by (auto simp add: as2) }
      hence "?x\<in>{c<..<d}" unfolding mem_interval by auto
      moreover
      have "?x\<notin>{a .. b}"
        unfolding mem_interval apply auto apply(rule_tac x=i in bexI)
        using as(2)[THEN bspec[where x=i]] and as2 using i
        by auto
      ultimately have False using as by auto  }
    hence "b\<bullet>i \<ge> d\<bullet>i" by(rule ccontr)auto
    ultimately
    have "a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i" by auto
  } note part1 = this
  show ?th3
    unfolding subset_eq and Ball_def and mem_interval 
    apply(rule,rule,rule,rule) 
    apply(rule part1)
    unfolding subset_eq and Ball_def and mem_interval
    prefer 4
    apply auto 
    by(erule_tac x=xa in allE,erule_tac x=xa in allE,fastforce)+ 
  { assume as:"{c<..<d} \<subseteq> {a<..<b}" "\<forall>i\<in>Basis. c\<bullet>i < d\<bullet>i"
    fix i :: 'a assume i:"i\<in>Basis"
    from as(1) have "{c<..<d} \<subseteq> {a..b}" using interval_open_subset_closed[of a b] by auto
    hence "a\<bullet>i \<le> c\<bullet>i \<and> d\<bullet>i \<le> b\<bullet>i" using part1 and as(2) using i by auto  } note * = this
  show ?th4 unfolding subset_eq and Ball_def and mem_interval 
    apply(rule,rule,rule,rule) apply(rule *) unfolding subset_eq and Ball_def and mem_interval prefer 4
    apply auto by(erule_tac x=xa in allE, simp)+ 
qed

lemma inter_interval: fixes a :: "'a::ordered_euclidean_space" shows
 "{a .. b} \<inter> {c .. d} =  {(\<Sum>i\<in>Basis. max (a\<bullet>i) (c\<bullet>i) *\<^sub>R i) .. (\<Sum>i\<in>Basis. min (b\<bullet>i) (d\<bullet>i) *\<^sub>R i)}"
  unfolding set_eq_iff and Int_iff and mem_interval by auto

lemma disjoint_interval: fixes a::"'a::ordered_euclidean_space" shows
  "{a .. b} \<inter> {c .. d} = {} \<longleftrightarrow> (\<exists>i\<in>Basis. (b\<bullet>i < a\<bullet>i \<or> d\<bullet>i < c\<bullet>i \<or> b\<bullet>i < c\<bullet>i \<or> d\<bullet>i < a\<bullet>i))" (is ?th1) and
  "{a .. b} \<inter> {c<..<d} = {} \<longleftrightarrow> (\<exists>i\<in>Basis. (b\<bullet>i < a\<bullet>i \<or> d\<bullet>i \<le> c\<bullet>i \<or> b\<bullet>i \<le> c\<bullet>i \<or> d\<bullet>i \<le> a\<bullet>i))" (is ?th2) and
  "{a<..<b} \<inter> {c .. d} = {} \<longleftrightarrow> (\<exists>i\<in>Basis. (b\<bullet>i \<le> a\<bullet>i \<or> d\<bullet>i < c\<bullet>i \<or> b\<bullet>i \<le> c\<bullet>i \<or> d\<bullet>i \<le> a\<bullet>i))" (is ?th3) and
  "{a<..<b} \<inter> {c<..<d} = {} \<longleftrightarrow> (\<exists>i\<in>Basis. (b\<bullet>i \<le> a\<bullet>i \<or> d\<bullet>i \<le> c\<bullet>i \<or> b\<bullet>i \<le> c\<bullet>i \<or> d\<bullet>i \<le> a\<bullet>i))" (is ?th4)
proof-
  let ?z = "(\<Sum>i\<in>Basis. (((max (a\<bullet>i) (c\<bullet>i)) + (min (b\<bullet>i) (d\<bullet>i))) / 2) *\<^sub>R i)::'a"
  have **: "\<And>P Q. (\<And>i :: 'a. i \<in> Basis \<Longrightarrow> Q ?z i \<Longrightarrow> P i) \<Longrightarrow>
      (\<And>i x :: 'a. i \<in> Basis \<Longrightarrow> P i \<Longrightarrow> Q x i) \<Longrightarrow> (\<forall>x. \<exists>i\<in>Basis. Q x i) \<longleftrightarrow> (\<exists>i\<in>Basis. P i)" 
    by blast
  note * = set_eq_iff Int_iff empty_iff mem_interval ball_conj_distrib[symmetric] eq_False ball_simps(10)
  show ?th1 unfolding * by (intro **) auto
  show ?th2 unfolding * by (intro **) auto
  show ?th3 unfolding * by (intro **) auto
  show ?th4 unfolding * by (intro **) auto
qed

(* Moved interval_open_subset_closed a bit upwards *)

lemma open_interval[intro]:
  fixes a b :: "'a::ordered_euclidean_space" shows "open {a<..<b}"
proof-
  have "open (\<Inter>i\<in>Basis. (\<lambda>x. x\<bullet>i) -` {a\<bullet>i<..<b\<bullet>i})"
    by (intro open_INT finite_lessThan ballI continuous_open_vimage allI
      linear_continuous_at open_real_greaterThanLessThan finite_Basis bounded_linear_inner_left)
  also have "(\<Inter>i\<in>Basis. (\<lambda>x. x\<bullet>i) -` {a\<bullet>i<..<b\<bullet>i}) = {a<..<b}"
    by (auto simp add: eucl_less [where 'a='a])
  finally show "open {a<..<b}" .
qed

lemma closed_interval[intro]:
  fixes a b :: "'a::ordered_euclidean_space" shows "closed {a .. b}"
proof-
  have "closed (\<Inter>i\<in>Basis. (\<lambda>x. x\<bullet>i) -` {a\<bullet>i .. b\<bullet>i})"
    by (intro closed_INT ballI continuous_closed_vimage allI
      linear_continuous_at closed_real_atLeastAtMost finite_Basis bounded_linear_inner_left)
  also have "(\<Inter>i\<in>Basis. (\<lambda>x. x\<bullet>i) -` {a\<bullet>i .. b\<bullet>i}) = {a .. b}"
    by (auto simp add: eucl_le [where 'a='a])
  finally show "closed {a .. b}" .
qed

lemma interior_closed_interval [intro]:
  fixes a b :: "'a::ordered_euclidean_space"
  shows "interior {a..b} = {a<..<b}" (is "?L = ?R")
proof(rule subset_antisym)
  show "?R \<subseteq> ?L" using interval_open_subset_closed open_interval
    by (rule interior_maximal)
next
  { fix x assume "x \<in> interior {a..b}"
    then obtain s where s:"open s" "x \<in> s" "s \<subseteq> {a..b}" ..
    then obtain e where "e>0" and e:"\<forall>x'. dist x' x < e \<longrightarrow> x' \<in> {a..b}" unfolding open_dist and subset_eq by auto
    { fix i :: 'a assume i:"i\<in>Basis"
      have "dist (x - (e / 2) *\<^sub>R i) x < e"
           "dist (x + (e / 2) *\<^sub>R i) x < e"
        unfolding dist_norm apply auto
        unfolding norm_minus_cancel using norm_Basis[OF i] `e>0` by auto
      hence "a \<bullet> i \<le> (x - (e / 2) *\<^sub>R i) \<bullet> i"
                     "(x + (e / 2) *\<^sub>R i) \<bullet> i \<le> b \<bullet> i"
        using e[THEN spec[where x="x - (e/2) *\<^sub>R i"]]
        and   e[THEN spec[where x="x + (e/2) *\<^sub>R i"]]
        unfolding mem_interval using i by blast+
      hence "a \<bullet> i < x \<bullet> i" and "x \<bullet> i < b \<bullet> i"
        using `e>0` i by (auto simp: inner_diff_left inner_Basis inner_add_left) }
    hence "x \<in> {a<..<b}" unfolding mem_interval by auto  }
  thus "?L \<subseteq> ?R" ..
qed

lemma bounded_closed_interval: fixes a :: "'a::ordered_euclidean_space" shows "bounded {a .. b}"
proof-
  let ?b = "\<Sum>i\<in>Basis. \<bar>a\<bullet>i\<bar> + \<bar>b\<bullet>i\<bar>"
  { fix x::"'a" assume x:"\<forall>i\<in>Basis. a \<bullet> i \<le> x \<bullet> i \<and> x \<bullet> i \<le> b \<bullet> i"
    { fix i :: 'a assume "i\<in>Basis"
      hence "\<bar>x\<bullet>i\<bar> \<le> \<bar>a\<bullet>i\<bar> + \<bar>b\<bullet>i\<bar>" using x[THEN bspec[where x=i]] by auto  }
    hence "(\<Sum>i\<in>Basis. \<bar>x \<bullet> i\<bar>) \<le> ?b" apply-apply(rule setsum_mono) by auto
    hence "norm x \<le> ?b" using norm_le_l1[of x] by auto  }
  thus ?thesis unfolding interval and bounded_iff by auto
qed

lemma bounded_interval: fixes a :: "'a::ordered_euclidean_space" shows
 "bounded {a .. b} \<and> bounded {a<..<b}"
  using bounded_closed_interval[of a b]
  using interval_open_subset_closed[of a b]
  using bounded_subset[of "{a..b}" "{a<..<b}"]
  by simp

lemma not_interval_univ: fixes a :: "'a::ordered_euclidean_space" shows
 "({a .. b} \<noteq> UNIV) \<and> ({a<..<b} \<noteq> UNIV)"
  using bounded_interval[of a b] by auto

lemma compact_interval: fixes a :: "'a::ordered_euclidean_space" shows "compact {a .. b}"
  using bounded_closed_imp_seq_compact[of "{a..b}"] using bounded_interval[of a b]
  by (auto simp: compact_eq_seq_compact_metric)

lemma open_interval_midpoint: fixes a :: "'a::ordered_euclidean_space"
  assumes "{a<..<b} \<noteq> {}" shows "((1/2) *\<^sub>R (a + b)) \<in> {a<..<b}"
proof-
  { fix i :: 'a assume "i\<in>Basis"
    hence "a \<bullet> i < ((1 / 2) *\<^sub>R (a + b)) \<bullet> i \<and> ((1 / 2) *\<^sub>R (a + b)) \<bullet> i < b \<bullet> i"
      using assms[unfolded interval_ne_empty, THEN bspec[where x=i]] by (auto simp: inner_add_left)  }
  thus ?thesis unfolding mem_interval by auto
qed

lemma open_closed_interval_convex: fixes x :: "'a::ordered_euclidean_space"
  assumes x:"x \<in> {a<..<b}" and y:"y \<in> {a .. b}" and e:"0 < e" "e \<le> 1"
  shows "(e *\<^sub>R x + (1 - e) *\<^sub>R y) \<in> {a<..<b}"
proof-
  { fix i :: 'a assume i:"i\<in>Basis"
    have "a \<bullet> i = e * (a \<bullet> i) + (1 - e) * (a \<bullet> i)" unfolding left_diff_distrib by simp
    also have "\<dots> < e * (x \<bullet> i) + (1 - e) * (y \<bullet> i)" apply(rule add_less_le_mono)
      using e unfolding mult_less_cancel_left and mult_le_cancel_left apply simp_all
      using x unfolding mem_interval using i apply simp
      using y unfolding mem_interval using i apply simp
      done
    finally have "a \<bullet> i < (e *\<^sub>R x + (1 - e) *\<^sub>R y) \<bullet> i" unfolding inner_simps by auto
    moreover {
    have "b \<bullet> i = e * (b\<bullet>i) + (1 - e) * (b\<bullet>i)" unfolding left_diff_distrib by simp
    also have "\<dots> > e * (x \<bullet> i) + (1 - e) * (y \<bullet> i)" apply(rule add_less_le_mono)
      using e unfolding mult_less_cancel_left and mult_le_cancel_left apply simp_all
      using x unfolding mem_interval using i apply simp
      using y unfolding mem_interval using i apply simp
      done
    finally have "(e *\<^sub>R x + (1 - e) *\<^sub>R y) \<bullet> i < b \<bullet> i" unfolding inner_simps by auto
    } ultimately have "a \<bullet> i < (e *\<^sub>R x + (1 - e) *\<^sub>R y) \<bullet> i \<and> (e *\<^sub>R x + (1 - e) *\<^sub>R y) \<bullet> i < b \<bullet> i" by auto }
  thus ?thesis unfolding mem_interval by auto
qed

lemma closure_open_interval: fixes a :: "'a::ordered_euclidean_space"
  assumes "{a<..<b} \<noteq> {}"
  shows "closure {a<..<b} = {a .. b}"
proof-
  have ab:"a < b" using assms[unfolded interval_ne_empty] apply(subst eucl_less) by auto
  let ?c = "(1 / 2) *\<^sub>R (a + b)"
  { fix x assume as:"x \<in> {a .. b}"
    def f == "\<lambda>n::nat. x + (inverse (real n + 1)) *\<^sub>R (?c - x)"
    { fix n assume fn:"f n < b \<longrightarrow> a < f n \<longrightarrow> f n = x" and xc:"x \<noteq> ?c"
      have *:"0 < inverse (real n + 1)" "inverse (real n + 1) \<le> 1" unfolding inverse_le_1_iff by auto
      have "(inverse (real n + 1)) *\<^sub>R ((1 / 2) *\<^sub>R (a + b)) + (1 - inverse (real n + 1)) *\<^sub>R x =
        x + (inverse (real n + 1)) *\<^sub>R (((1 / 2) *\<^sub>R (a + b)) - x)"
        by (auto simp add: algebra_simps)
      hence "f n < b" and "a < f n" using open_closed_interval_convex[OF open_interval_midpoint[OF assms] as *] unfolding f_def by auto
      hence False using fn unfolding f_def using xc by auto  }
    moreover
    { assume "\<not> (f ---> x) sequentially"
      { fix e::real assume "e>0"
        hence "\<exists>N::nat. inverse (real (N + 1)) < e" using real_arch_inv[of e] apply (auto simp add: Suc_pred') apply(rule_tac x="n - 1" in exI) by auto
        then obtain N::nat where "inverse (real (N + 1)) < e" by auto
        hence "\<forall>n\<ge>N. inverse (real n + 1) < e" by (auto, metis Suc_le_mono le_SucE less_imp_inverse_less nat_le_real_less order_less_trans real_of_nat_Suc real_of_nat_Suc_gt_zero)
        hence "\<exists>N::nat. \<forall>n\<ge>N. inverse (real n + 1) < e" by auto  }
      hence "((\<lambda>n. inverse (real n + 1)) ---> 0) sequentially"
        unfolding LIMSEQ_def by(auto simp add: dist_norm)
      hence "(f ---> x) sequentially" unfolding f_def
        using tendsto_add[OF tendsto_const, of "\<lambda>n::nat. (inverse (real n + 1)) *\<^sub>R ((1 / 2) *\<^sub>R (a + b) - x)" 0 sequentially x]
        using tendsto_scaleR [OF _ tendsto_const, of "\<lambda>n::nat. inverse (real n + 1)" 0 sequentially "((1 / 2) *\<^sub>R (a + b) - x)"] by auto  }
    ultimately have "x \<in> closure {a<..<b}"
      using as and open_interval_midpoint[OF assms] unfolding closure_def unfolding islimpt_sequential by(cases "x=?c")auto  }
  thus ?thesis using closure_minimal[OF interval_open_subset_closed closed_interval, of a b] by blast
qed

lemma bounded_subset_open_interval_symmetric: fixes s::"('a::ordered_euclidean_space) set"
  assumes "bounded s"  shows "\<exists>a. s \<subseteq> {-a<..<a}"
proof-
  obtain b where "b>0" and b:"\<forall>x\<in>s. norm x \<le> b" using assms[unfolded bounded_pos] by auto
  def a \<equiv> "(\<Sum>i\<in>Basis. (b + 1) *\<^sub>R i)::'a"
  { fix x assume "x\<in>s"
    fix i :: 'a assume i:"i\<in>Basis"
    hence "(-a)\<bullet>i < x\<bullet>i" and "x\<bullet>i < a\<bullet>i" using b[THEN bspec[where x=x], OF `x\<in>s`]
      and Basis_le_norm[OF i, of x] unfolding inner_simps and a_def by auto }
  thus ?thesis by(auto intro: exI[where x=a] simp add: eucl_less[where 'a='a])
qed

lemma bounded_subset_open_interval:
  fixes s :: "('a::ordered_euclidean_space) set"
  shows "bounded s ==> (\<exists>a b. s \<subseteq> {a<..<b})"
  by (auto dest!: bounded_subset_open_interval_symmetric)

lemma bounded_subset_closed_interval_symmetric:
  fixes s :: "('a::ordered_euclidean_space) set"
  assumes "bounded s" shows "\<exists>a. s \<subseteq> {-a .. a}"
proof-
  obtain a where "s \<subseteq> {- a<..<a}" using bounded_subset_open_interval_symmetric[OF assms] by auto
  thus ?thesis using interval_open_subset_closed[of "-a" a] by auto
qed

lemma bounded_subset_closed_interval:
  fixes s :: "('a::ordered_euclidean_space) set"
  shows "bounded s ==> (\<exists>a b. s \<subseteq> {a .. b})"
  using bounded_subset_closed_interval_symmetric[of s] by auto

lemma frontier_closed_interval:
  fixes a b :: "'a::ordered_euclidean_space"
  shows "frontier {a .. b} = {a .. b} - {a<..<b}"
  unfolding frontier_def unfolding interior_closed_interval and closure_closed[OF closed_interval] ..

lemma frontier_open_interval:
  fixes a b :: "'a::ordered_euclidean_space"
  shows "frontier {a<..<b} = (if {a<..<b} = {} then {} else {a .. b} - {a<..<b})"
proof(cases "{a<..<b} = {}")
  case True thus ?thesis using frontier_empty by auto
next
  case False thus ?thesis unfolding frontier_def and closure_open_interval[OF False] and interior_open[OF open_interval] by auto
qed

lemma inter_interval_mixed_eq_empty: fixes a :: "'a::ordered_euclidean_space"
  assumes "{c<..<d} \<noteq> {}"  shows "{a<..<b} \<inter> {c .. d} = {} \<longleftrightarrow> {a<..<b} \<inter> {c<..<d} = {}"
  unfolding closure_open_interval[OF assms, THEN sym] unfolding open_inter_closure_eq_empty[OF open_interval] ..


(* Some stuff for half-infinite intervals too; FIXME: notation?  *)

lemma closed_interval_left: fixes b::"'a::euclidean_space"
  shows "closed {x::'a. \<forall>i\<in>Basis. x\<bullet>i \<le> b\<bullet>i}"
proof-
  { fix i :: 'a assume i:"i\<in>Basis"
    fix x::"'a" assume x:"\<forall>e>0. \<exists>x'\<in>{x. \<forall>i\<in>Basis. x \<bullet> i \<le> b \<bullet> i}. x' \<noteq> x \<and> dist x' x < e"
    { assume "x\<bullet>i > b\<bullet>i"
      then obtain y where "y \<bullet> i \<le> b \<bullet> i"  "y \<noteq> x"  "dist y x < x\<bullet>i - b\<bullet>i"
        using x[THEN spec[where x="x\<bullet>i - b\<bullet>i"]] using i by auto
      hence False using Basis_le_norm[OF i, of "y - x"] unfolding dist_norm inner_simps using i 
        by auto }
    hence "x\<bullet>i \<le> b\<bullet>i" by(rule ccontr)auto  }
  thus ?thesis unfolding closed_limpt unfolding islimpt_approachable by blast
qed

lemma closed_interval_right: fixes a::"'a::euclidean_space"
  shows "closed {x::'a. \<forall>i\<in>Basis. a\<bullet>i \<le> x\<bullet>i}"
proof-
  { fix i :: 'a assume i:"i\<in>Basis"
    fix x::"'a" assume x:"\<forall>e>0. \<exists>x'\<in>{x. \<forall>i\<in>Basis. a \<bullet> i \<le> x \<bullet> i}. x' \<noteq> x \<and> dist x' x < e"
    { assume "a\<bullet>i > x\<bullet>i"
      then obtain y where "a \<bullet> i \<le> y \<bullet> i"  "y \<noteq> x"  "dist y x < a\<bullet>i - x\<bullet>i"
        using x[THEN spec[where x="a\<bullet>i - x\<bullet>i"]] i by auto
      hence False using Basis_le_norm[OF i, of "y - x"] unfolding dist_norm inner_simps by auto }
    hence "a\<bullet>i \<le> x\<bullet>i" by(rule ccontr)auto  }
  thus ?thesis unfolding closed_limpt unfolding islimpt_approachable by blast
qed

lemma open_box: "open (box a b)"
proof -
  have "open (\<Inter>i\<in>Basis. (op \<bullet> i) -` {a \<bullet> i <..< b \<bullet> i})"
    by (auto intro!: continuous_open_vimage continuous_inner continuous_at_id continuous_const)
  also have "(\<Inter>i\<in>Basis. (op \<bullet> i) -` {a \<bullet> i <..< b \<bullet> i}) = box a b"
    by (auto simp add: box_def inner_commute)
  finally show ?thesis .
qed

instance euclidean_space \<subseteq> second_countable_topology
proof
  def a \<equiv> "\<lambda>f :: 'a \<Rightarrow> (real \<times> real). \<Sum>i\<in>Basis. fst (f i) *\<^sub>R i"
  then have a: "\<And>f. (\<Sum>i\<in>Basis. fst (f i) *\<^sub>R i) = a f" by simp
  def b \<equiv> "\<lambda>f :: 'a \<Rightarrow> (real \<times> real). \<Sum>i\<in>Basis. snd (f i) *\<^sub>R i"
  then have b: "\<And>f. (\<Sum>i\<in>Basis. snd (f i) *\<^sub>R i) = b f" by simp
  def B \<equiv> "(\<lambda>f. box (a f) (b f)) ` (Basis \<rightarrow>\<^isub>E (\<rat> \<times> \<rat>))"

  have "countable B" unfolding B_def 
    by (intro countable_image countable_PiE finite_Basis countable_SIGMA countable_rat)
  moreover
  have "Ball B open" by (simp add: B_def open_box)
  moreover have "(\<forall>A. open A \<longrightarrow> (\<exists>B'\<subseteq>B. \<Union>B' = A))"
  proof safe
    fix A::"'a set" assume "open A"
    show "\<exists>B'\<subseteq>B. \<Union>B' = A"
      apply (rule exI[of _ "{b\<in>B. b \<subseteq> A}"])
      apply (subst (3) open_UNION_box[OF `open A`])
      apply (auto simp add: a b B_def)
      done
  qed
  ultimately
  show "\<exists>B::'a set set. countable B \<and> topological_basis B" unfolding topological_basis_def by blast
qed

instance ordered_euclidean_space \<subseteq> polish_space ..

text {* Intervals in general, including infinite and mixtures of open and closed. *}

definition "is_interval (s::('a::euclidean_space) set) \<longleftrightarrow>
  (\<forall>a\<in>s. \<forall>b\<in>s. \<forall>x. (\<forall>i\<in>Basis. ((a\<bullet>i \<le> x\<bullet>i \<and> x\<bullet>i \<le> b\<bullet>i) \<or> (b\<bullet>i \<le> x\<bullet>i \<and> x\<bullet>i \<le> a\<bullet>i))) \<longrightarrow> x \<in> s)"

lemma is_interval_interval: "is_interval {a .. b::'a::ordered_euclidean_space}" (is ?th1)
  "is_interval {a<..<b}" (is ?th2) proof -
  show ?th1 ?th2  unfolding is_interval_def mem_interval Ball_def atLeastAtMost_iff
    by(meson order_trans le_less_trans less_le_trans less_trans)+ qed

lemma is_interval_empty:
 "is_interval {}"
  unfolding is_interval_def
  by simp

lemma is_interval_univ:
 "is_interval UNIV"
  unfolding is_interval_def
  by simp


subsection {* Closure of halfspaces and hyperplanes *}

lemma isCont_open_vimage:
  assumes "\<And>x. isCont f x" and "open s" shows "open (f -` s)"
proof -
  from assms(1) have "continuous_on UNIV f"
    unfolding isCont_def continuous_on_def within_UNIV by simp
  hence "open {x \<in> UNIV. f x \<in> s}"
    using open_UNIV `open s` by (rule continuous_open_preimage)
  thus "open (f -` s)"
    by (simp add: vimage_def)
qed

lemma isCont_closed_vimage:
  assumes "\<And>x. isCont f x" and "closed s" shows "closed (f -` s)"
  using assms unfolding closed_def vimage_Compl [symmetric]
  by (rule isCont_open_vimage)

lemma open_Collect_less:
  fixes f g :: "'a::topological_space \<Rightarrow> real"
  assumes f: "\<And>x. isCont f x"
  assumes g: "\<And>x. isCont g x"
  shows "open {x. f x < g x}"
proof -
  have "open ((\<lambda>x. g x - f x) -` {0<..})"
    using isCont_diff [OF g f] open_real_greaterThan
    by (rule isCont_open_vimage)
  also have "((\<lambda>x. g x - f x) -` {0<..}) = {x. f x < g x}"
    by auto
  finally show ?thesis .
qed

lemma closed_Collect_le:
  fixes f g :: "'a::topological_space \<Rightarrow> real"
  assumes f: "\<And>x. isCont f x"
  assumes g: "\<And>x. isCont g x"
  shows "closed {x. f x \<le> g x}"
proof -
  have "closed ((\<lambda>x. g x - f x) -` {0..})"
    using isCont_diff [OF g f] closed_real_atLeast
    by (rule isCont_closed_vimage)
  also have "((\<lambda>x. g x - f x) -` {0..}) = {x. f x \<le> g x}"
    by auto
  finally show ?thesis .
qed

lemma closed_Collect_eq:
  fixes f g :: "'a::topological_space \<Rightarrow> 'b::t2_space"
  assumes f: "\<And>x. isCont f x"
  assumes g: "\<And>x. isCont g x"
  shows "closed {x. f x = g x}"
proof -
  have "open {(x::'b, y::'b). x \<noteq> y}"
    unfolding open_prod_def by (auto dest!: hausdorff)
  hence "closed {(x::'b, y::'b). x = y}"
    unfolding closed_def split_def Collect_neg_eq .
  with isCont_Pair [OF f g]
  have "closed ((\<lambda>x. (f x, g x)) -` {(x, y). x = y})"
    by (rule isCont_closed_vimage)
  also have "\<dots> = {x. f x = g x}" by auto
  finally show ?thesis .
qed

lemma continuous_at_inner: "continuous (at x) (inner a)"
  unfolding continuous_at by (intro tendsto_intros)

lemma closed_halfspace_le: "closed {x. inner a x \<le> b}"
  by (simp add: closed_Collect_le)

lemma closed_halfspace_ge: "closed {x. inner a x \<ge> b}"
  by (simp add: closed_Collect_le)

lemma closed_hyperplane: "closed {x. inner a x = b}"
  by (simp add: closed_Collect_eq)

lemma closed_halfspace_component_le:
  shows "closed {x::'a::euclidean_space. x\<bullet>i \<le> a}"
  by (simp add: closed_Collect_le)

lemma closed_halfspace_component_ge:
  shows "closed {x::'a::euclidean_space. x\<bullet>i \<ge> a}"
  by (simp add: closed_Collect_le)

text {* Openness of halfspaces. *}

lemma open_halfspace_lt: "open {x. inner a x < b}"
  by (simp add: open_Collect_less)

lemma open_halfspace_gt: "open {x. inner a x > b}"
  by (simp add: open_Collect_less)

lemma open_halfspace_component_lt:
  shows "open {x::'a::euclidean_space. x\<bullet>i < a}"
  by (simp add: open_Collect_less)

lemma open_halfspace_component_gt:
  shows "open {x::'a::euclidean_space. x\<bullet>i > a}"
  by (simp add: open_Collect_less)

text{* Instantiation for intervals on @{text ordered_euclidean_space} *}

lemma eucl_lessThan_eq_halfspaces:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "{..<a} = (\<Inter>i\<in>Basis. {x. x \<bullet> i < a \<bullet> i})"
 by (auto simp: eucl_less[where 'a='a])

lemma eucl_greaterThan_eq_halfspaces:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "{a<..} = (\<Inter>i\<in>Basis. {x. a \<bullet> i < x \<bullet> i})"
 by (auto simp: eucl_less[where 'a='a])

lemma eucl_atMost_eq_halfspaces:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "{.. a} = (\<Inter>i\<in>Basis. {x. x \<bullet> i \<le> a \<bullet> i})"
 by (auto simp: eucl_le[where 'a='a])

lemma eucl_atLeast_eq_halfspaces:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "{a ..} = (\<Inter>i\<in>Basis. {x. a \<bullet> i \<le> x \<bullet> i})"
 by (auto simp: eucl_le[where 'a='a])

lemma open_eucl_lessThan[simp, intro]:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "open {..< a}"
  by (auto simp: eucl_lessThan_eq_halfspaces open_halfspace_component_lt)

lemma open_eucl_greaterThan[simp, intro]:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "open {a <..}"
  by (auto simp: eucl_greaterThan_eq_halfspaces open_halfspace_component_gt)

lemma closed_eucl_atMost[simp, intro]:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "closed {.. a}"
  unfolding eucl_atMost_eq_halfspaces
  by (simp add: closed_INT closed_Collect_le)

lemma closed_eucl_atLeast[simp, intro]:
  fixes a :: "'a\<Colon>ordered_euclidean_space"
  shows "closed {a ..}"
  unfolding eucl_atLeast_eq_halfspaces
  by (simp add: closed_INT closed_Collect_le)

text {* This gives a simple derivation of limit component bounds. *}

lemma Lim_component_le: fixes f :: "'a \<Rightarrow> 'b::euclidean_space"
  assumes "(f ---> l) net" "\<not> (trivial_limit net)"  "eventually (\<lambda>x. f(x)\<bullet>i \<le> b) net"
  shows "l\<bullet>i \<le> b"
  by (rule tendsto_le[OF assms(2) tendsto_const tendsto_inner[OF assms(1) tendsto_const] assms(3)])

lemma Lim_component_ge: fixes f :: "'a \<Rightarrow> 'b::euclidean_space"
  assumes "(f ---> l) net"  "\<not> (trivial_limit net)"  "eventually (\<lambda>x. b \<le> (f x)\<bullet>i) net"
  shows "b \<le> l\<bullet>i"
  by (rule tendsto_le[OF assms(2) tendsto_inner[OF assms(1) tendsto_const] tendsto_const assms(3)])

lemma Lim_component_eq: fixes f :: "'a \<Rightarrow> 'b::euclidean_space"
  assumes net:"(f ---> l) net" "~(trivial_limit net)" and ev:"eventually (\<lambda>x. f(x)\<bullet>i = b) net"
  shows "l\<bullet>i = b"
  using ev[unfolded order_eq_iff eventually_conj_iff]
  using Lim_component_ge[OF net, of b i] and Lim_component_le[OF net, of i b] by auto

text{* Limits relative to a union.                                               *}

lemma eventually_within_Un:
  "eventually P (net within (s \<union> t)) \<longleftrightarrow>
    eventually P (net within s) \<and> eventually P (net within t)"
  unfolding Limits.eventually_within
  by (auto elim!: eventually_rev_mp)

lemma Lim_within_union:
 "(f ---> l) (net within (s \<union> t)) \<longleftrightarrow>
  (f ---> l) (net within s) \<and> (f ---> l) (net within t)"
  unfolding tendsto_def
  by (auto simp add: eventually_within_Un)

lemma Lim_topological:
 "(f ---> l) net \<longleftrightarrow>
        trivial_limit net \<or>
        (\<forall>S. open S \<longrightarrow> l \<in> S \<longrightarrow> eventually (\<lambda>x. f x \<in> S) net)"
  unfolding tendsto_def trivial_limit_eq by auto

lemma continuous_on_union:
  assumes "closed s" "closed t" "continuous_on s f" "continuous_on t f"
  shows "continuous_on (s \<union> t) f"
  using assms unfolding continuous_on Lim_within_union
  unfolding Lim_topological trivial_limit_within closed_limpt by auto

lemma continuous_on_cases:
  assumes "closed s" "closed t" "continuous_on s f" "continuous_on t g"
          "\<forall>x. (x\<in>s \<and> \<not> P x) \<or> (x \<in> t \<and> P x) \<longrightarrow> f x = g x"
  shows "continuous_on (s \<union> t) (\<lambda>x. if P x then f x else g x)"
proof-
  let ?h = "(\<lambda>x. if P x then f x else g x)"
  have "\<forall>x\<in>s. f x = (if P x then f x else g x)" using assms(5) by auto
  hence "continuous_on s ?h" using continuous_on_eq[of s f ?h] using assms(3) by auto
  moreover
  have "\<forall>x\<in>t. g x = (if P x then f x else g x)" using assms(5) by auto
  hence "continuous_on t ?h" using continuous_on_eq[of t g ?h] using assms(4) by auto
  ultimately show ?thesis using continuous_on_union[OF assms(1,2), of ?h] by auto
qed


text{* Some more convenient intermediate-value theorem formulations.             *}

lemma connected_ivt_hyperplane:
  assumes "connected s" "x \<in> s" "y \<in> s" "inner a x \<le> b" "b \<le> inner a y"
  shows "\<exists>z \<in> s. inner a z = b"
proof(rule ccontr)
  assume as:"\<not> (\<exists>z\<in>s. inner a z = b)"
  let ?A = "{x. inner a x < b}"
  let ?B = "{x. inner a x > b}"
  have "open ?A" "open ?B" using open_halfspace_lt and open_halfspace_gt by auto
  moreover have "?A \<inter> ?B = {}" by auto
  moreover have "s \<subseteq> ?A \<union> ?B" using as by auto
  ultimately show False using assms(1)[unfolded connected_def not_ex, THEN spec[where x="?A"], THEN spec[where x="?B"]] and assms(2-5) by auto
qed

lemma connected_ivt_component: fixes x::"'a::euclidean_space" shows
 "connected s \<Longrightarrow> x \<in> s \<Longrightarrow> y \<in> s \<Longrightarrow> x\<bullet>k \<le> a \<Longrightarrow> a \<le> y\<bullet>k \<Longrightarrow> (\<exists>z\<in>s.  z\<bullet>k = a)"
  using connected_ivt_hyperplane[of s x y "k::'a" a] by (auto simp: inner_commute)


subsection {* Homeomorphisms *}

definition "homeomorphism s t f g \<equiv>
     (\<forall>x\<in>s. (g(f x) = x)) \<and> (f ` s = t) \<and> continuous_on s f \<and>
     (\<forall>y\<in>t. (f(g y) = y)) \<and> (g ` t = s) \<and> continuous_on t g"

definition
  homeomorphic :: "'a::topological_space set \<Rightarrow> 'b::topological_space set \<Rightarrow> bool"
    (infixr "homeomorphic" 60) where
  homeomorphic_def: "s homeomorphic t \<equiv> (\<exists>f g. homeomorphism s t f g)"

lemma homeomorphic_refl: "s homeomorphic s"
  unfolding homeomorphic_def
  unfolding homeomorphism_def
  using continuous_on_id
  apply(rule_tac x = "(\<lambda>x. x)" in exI)
  apply(rule_tac x = "(\<lambda>x. x)" in exI)
  by blast

lemma homeomorphic_sym:
 "s homeomorphic t \<longleftrightarrow> t homeomorphic s"
unfolding homeomorphic_def
unfolding homeomorphism_def
by blast 

lemma homeomorphic_trans:
  assumes "s homeomorphic t" "t homeomorphic u" shows "s homeomorphic u"
proof-
  obtain f1 g1 where fg1:"\<forall>x\<in>s. g1 (f1 x) = x"  "f1 ` s = t" "continuous_on s f1" "\<forall>y\<in>t. f1 (g1 y) = y" "g1 ` t = s" "continuous_on t g1"
    using assms(1) unfolding homeomorphic_def homeomorphism_def by auto
  obtain f2 g2 where fg2:"\<forall>x\<in>t. g2 (f2 x) = x"  "f2 ` t = u" "continuous_on t f2" "\<forall>y\<in>u. f2 (g2 y) = y" "g2 ` u = t" "continuous_on u g2"
    using assms(2) unfolding homeomorphic_def homeomorphism_def by auto

  { fix x assume "x\<in>s" hence "(g1 \<circ> g2) ((f2 \<circ> f1) x) = x" using fg1(1)[THEN bspec[where x=x]] and fg2(1)[THEN bspec[where x="f1 x"]] and fg1(2) by auto }
  moreover have "(f2 \<circ> f1) ` s = u" using fg1(2) fg2(2) by auto
  moreover have "continuous_on s (f2 \<circ> f1)" using continuous_on_compose[OF fg1(3)] and fg2(3) unfolding fg1(2) by auto
  moreover { fix y assume "y\<in>u" hence "(f2 \<circ> f1) ((g1 \<circ> g2) y) = y" using fg2(4)[THEN bspec[where x=y]] and fg1(4)[THEN bspec[where x="g2 y"]] and fg2(5) by auto }
  moreover have "(g1 \<circ> g2) ` u = s" using fg1(5) fg2(5) by auto
  moreover have "continuous_on u (g1 \<circ> g2)" using continuous_on_compose[OF fg2(6)] and fg1(6)  unfolding fg2(5) by auto
  ultimately show ?thesis unfolding homeomorphic_def homeomorphism_def apply(rule_tac x="f2 \<circ> f1" in exI) apply(rule_tac x="g1 \<circ> g2" in exI) by auto
qed

lemma homeomorphic_minimal:
 "s homeomorphic t \<longleftrightarrow>
    (\<exists>f g. (\<forall>x\<in>s. f(x) \<in> t \<and> (g(f(x)) = x)) \<and>
           (\<forall>y\<in>t. g(y) \<in> s \<and> (f(g(y)) = y)) \<and>
           continuous_on s f \<and> continuous_on t g)"
unfolding homeomorphic_def homeomorphism_def
apply auto apply (rule_tac x=f in exI) apply (rule_tac x=g in exI)
apply auto apply (rule_tac x=f in exI) apply (rule_tac x=g in exI) apply auto
unfolding image_iff
apply(erule_tac x="g x" in ballE) apply(erule_tac x="x" in ballE)
apply auto apply(rule_tac x="g x" in bexI) apply auto
apply(erule_tac x="f x" in ballE) apply(erule_tac x="x" in ballE)
apply auto apply(rule_tac x="f x" in bexI) by auto

text {* Relatively weak hypotheses if a set is compact. *}

lemma homeomorphism_compact:
  fixes f :: "'a::topological_space \<Rightarrow> 'b::t2_space"
  assumes "compact s" "continuous_on s f"  "f ` s = t"  "inj_on f s"
  shows "\<exists>g. homeomorphism s t f g"
proof-
  def g \<equiv> "\<lambda>x. SOME y. y\<in>s \<and> f y = x"
  have g:"\<forall>x\<in>s. g (f x) = x" using assms(3) assms(4)[unfolded inj_on_def] unfolding g_def by auto
  { fix y assume "y\<in>t"
    then obtain x where x:"f x = y" "x\<in>s" using assms(3) by auto
    hence "g (f x) = x" using g by auto
    hence "f (g y) = y" unfolding x(1)[THEN sym] by auto  }
  hence g':"\<forall>x\<in>t. f (g x) = x" by auto
  moreover
  { fix x
    have "x\<in>s \<Longrightarrow> x \<in> g ` t" using g[THEN bspec[where x=x]] unfolding image_iff using assms(3) by(auto intro!: bexI[where x="f x"])
    moreover
    { assume "x\<in>g ` t"
      then obtain y where y:"y\<in>t" "g y = x" by auto
      then obtain x' where x':"x'\<in>s" "f x' = y" using assms(3) by auto
      hence "x \<in> s" unfolding g_def using someI2[of "\<lambda>b. b\<in>s \<and> f b = y" x' "\<lambda>x. x\<in>s"] unfolding y(2)[THEN sym] and g_def by auto }
    ultimately have "x\<in>s \<longleftrightarrow> x \<in> g ` t" ..  }
  hence "g ` t = s" by auto
  ultimately
  show ?thesis unfolding homeomorphism_def homeomorphic_def
    apply(rule_tac x=g in exI) using g and assms(3) and continuous_on_inv[OF assms(2,1), of g, unfolded assms(3)] and assms(2) by auto
qed

lemma homeomorphic_compact:
  fixes f :: "'a::topological_space \<Rightarrow> 'b::t2_space"
  shows "compact s \<Longrightarrow> continuous_on s f \<Longrightarrow> (f ` s = t) \<Longrightarrow> inj_on f s
          \<Longrightarrow> s homeomorphic t"
  unfolding homeomorphic_def by (metis homeomorphism_compact)

text{* Preservation of topological properties.                                   *}

lemma homeomorphic_compactness:
 "s homeomorphic t ==> (compact s \<longleftrightarrow> compact t)"
unfolding homeomorphic_def homeomorphism_def
by (metis compact_continuous_image)

text{* Results on translation, scaling etc.                                      *}

lemma homeomorphic_scaling:
  fixes s :: "'a::real_normed_vector set"
  assumes "c \<noteq> 0"  shows "s homeomorphic ((\<lambda>x. c *\<^sub>R x) ` s)"
  unfolding homeomorphic_minimal
  apply(rule_tac x="\<lambda>x. c *\<^sub>R x" in exI)
  apply(rule_tac x="\<lambda>x. (1 / c) *\<^sub>R x" in exI)
  using assms by (auto simp add: continuous_on_intros)

lemma homeomorphic_translation:
  fixes s :: "'a::real_normed_vector set"
  shows "s homeomorphic ((\<lambda>x. a + x) ` s)"
  unfolding homeomorphic_minimal
  apply(rule_tac x="\<lambda>x. a + x" in exI)
  apply(rule_tac x="\<lambda>x. -a + x" in exI)
  using continuous_on_add[OF continuous_on_const continuous_on_id] by auto

lemma homeomorphic_affinity:
  fixes s :: "'a::real_normed_vector set"
  assumes "c \<noteq> 0"  shows "s homeomorphic ((\<lambda>x. a + c *\<^sub>R x) ` s)"
proof-
  have *:"op + a ` op *\<^sub>R c ` s = (\<lambda>x. a + c *\<^sub>R x) ` s" by auto
  show ?thesis
    using homeomorphic_trans
    using homeomorphic_scaling[OF assms, of s]
    using homeomorphic_translation[of "(\<lambda>x. c *\<^sub>R x) ` s" a] unfolding * by auto
qed

lemma homeomorphic_balls:
  fixes a b ::"'a::real_normed_vector"
  assumes "0 < d"  "0 < e"
  shows "(ball a d) homeomorphic  (ball b e)" (is ?th)
        "(cball a d) homeomorphic (cball b e)" (is ?cth)
proof-
  show ?th unfolding homeomorphic_minimal
    apply(rule_tac x="\<lambda>x. b + (e/d) *\<^sub>R (x - a)" in exI)
    apply(rule_tac x="\<lambda>x. a + (d/e) *\<^sub>R (x - b)" in exI)
    using assms apply (auto simp add: dist_commute)
    unfolding dist_norm
    apply (auto simp add: pos_divide_less_eq mult_strict_left_mono)
    unfolding continuous_on
    by (intro ballI tendsto_intros, simp)+
next
  show ?cth unfolding homeomorphic_minimal
    apply(rule_tac x="\<lambda>x. b + (e/d) *\<^sub>R (x - a)" in exI)
    apply(rule_tac x="\<lambda>x. a + (d/e) *\<^sub>R (x - b)" in exI)
    using assms apply (auto simp add: dist_commute)
    unfolding dist_norm
    apply (auto simp add: pos_divide_le_eq)
    unfolding continuous_on
    by (intro ballI tendsto_intros, simp)+
qed

text{* "Isometry" (up to constant bounds) of injective linear map etc.           *}

lemma cauchy_isometric:
  fixes x :: "nat \<Rightarrow> 'a::euclidean_space"
  assumes e:"0 < e" and s:"subspace s" and f:"bounded_linear f" and normf:"\<forall>x\<in>s. norm(f x) \<ge> e * norm(x)" and xs:"\<forall>n::nat. x n \<in> s" and cf:"Cauchy(f o x)"
  shows "Cauchy x"
proof-
  interpret f: bounded_linear f by fact
  { fix d::real assume "d>0"
    then obtain N where N:"\<forall>n\<ge>N. norm (f (x n) - f (x N)) < e * d"
      using cf[unfolded cauchy o_def dist_norm, THEN spec[where x="e*d"]] and e and mult_pos_pos[of e d] by auto
    { fix n assume "n\<ge>N"
      have "e * norm (x n - x N) \<le> norm (f (x n - x N))"
        using subspace_sub[OF s, of "x n" "x N"] using xs[THEN spec[where x=N]] and xs[THEN spec[where x=n]]
        using normf[THEN bspec[where x="x n - x N"]] by auto
      also have "norm (f (x n - x N)) < e * d"
        using `N \<le> n` N unfolding f.diff[THEN sym] by auto
      finally have "norm (x n - x N) < d" using `e>0` by simp }
    hence "\<exists>N. \<forall>n\<ge>N. norm (x n - x N) < d" by auto }
  thus ?thesis unfolding cauchy and dist_norm by auto
qed

lemma complete_isometric_image:
  fixes f :: "'a::euclidean_space => 'b::euclidean_space"
  assumes "0 < e" and s:"subspace s" and f:"bounded_linear f" and normf:"\<forall>x\<in>s. norm(f x) \<ge> e * norm(x)" and cs:"complete s"
  shows "complete(f ` s)"
proof-
  { fix g assume as:"\<forall>n::nat. g n \<in> f ` s" and cfg:"Cauchy g"
    then obtain x where "\<forall>n. x n \<in> s \<and> g n = f (x n)" 
      using choice[of "\<lambda> n xa. xa \<in> s \<and> g n = f xa"] by auto
    hence x:"\<forall>n. x n \<in> s"  "\<forall>n. g n = f (x n)" by auto
    hence "f \<circ> x = g" unfolding fun_eq_iff by auto
    then obtain l where "l\<in>s" and l:"(x ---> l) sequentially"
      using cs[unfolded complete_def, THEN spec[where x="x"]]
      using cauchy_isometric[OF `0<e` s f normf] and cfg and x(1) by auto
    hence "\<exists>l\<in>f ` s. (g ---> l) sequentially"
      using linear_continuous_at[OF f, unfolded continuous_at_sequentially, THEN spec[where x=x], of l]
      unfolding `f \<circ> x = g` by auto  }
  thus ?thesis unfolding complete_def by auto
qed

lemma injective_imp_isometric: fixes f::"'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes s:"closed s"  "subspace s"  and f:"bounded_linear f" "\<forall>x\<in>s. (f x = 0) \<longrightarrow> (x = 0)"
  shows "\<exists>e>0. \<forall>x\<in>s. norm (f x) \<ge> e * norm(x)"
proof(cases "s \<subseteq> {0::'a}")
  case True
  { fix x assume "x \<in> s"
    hence "x = 0" using True by auto
    hence "norm x \<le> norm (f x)" by auto  }
  thus ?thesis by(auto intro!: exI[where x=1])
next
  interpret f: bounded_linear f by fact
  case False
  then obtain a where a:"a\<noteq>0" "a\<in>s" by auto
  from False have "s \<noteq> {}" by auto
  let ?S = "{f x| x. (x \<in> s \<and> norm x = norm a)}"
  let ?S' = "{x::'a. x\<in>s \<and> norm x = norm a}"
  let ?S'' = "{x::'a. norm x = norm a}"

  have "?S'' = frontier(cball 0 (norm a))" unfolding frontier_cball and dist_norm by auto
  hence "compact ?S''" using compact_frontier[OF compact_cball, of 0 "norm a"] by auto
  moreover have "?S' = s \<inter> ?S''" by auto
  ultimately have "compact ?S'" using closed_inter_compact[of s ?S''] using s(1) by auto
  moreover have *:"f ` ?S' = ?S" by auto
  ultimately have "compact ?S" using compact_continuous_image[OF linear_continuous_on[OF f(1)], of ?S'] by auto
  hence "closed ?S" using compact_imp_closed by auto
  moreover have "?S \<noteq> {}" using a by auto
  ultimately obtain b' where "b'\<in>?S" "\<forall>y\<in>?S. norm b' \<le> norm y" using distance_attains_inf[of ?S 0] unfolding dist_0_norm by auto
  then obtain b where "b\<in>s" and ba:"norm b = norm a" and b:"\<forall>x\<in>{x \<in> s. norm x = norm a}. norm (f b) \<le> norm (f x)" unfolding *[THEN sym] unfolding image_iff by auto

  let ?e = "norm (f b) / norm b"
  have "norm b > 0" using ba and a and norm_ge_zero by auto
  moreover have "norm (f b) > 0" using f(2)[THEN bspec[where x=b], OF `b\<in>s`] using `norm b >0` unfolding zero_less_norm_iff by auto
  ultimately have "0 < norm (f b) / norm b" by(simp only: divide_pos_pos)
  moreover
  { fix x assume "x\<in>s"
    hence "norm (f b) / norm b * norm x \<le> norm (f x)"
    proof(cases "x=0")
      case True thus "norm (f b) / norm b * norm x \<le> norm (f x)" by auto
    next
      case False
      hence *:"0 < norm a / norm x" using `a\<noteq>0` unfolding zero_less_norm_iff[THEN sym] by(simp only: divide_pos_pos)
      have "\<forall>c. \<forall>x\<in>s. c *\<^sub>R x \<in> s" using s[unfolded subspace_def] by auto
      hence "(norm a / norm x) *\<^sub>R x \<in> {x \<in> s. norm x = norm a}" using `x\<in>s` and `x\<noteq>0` by auto
      thus "norm (f b) / norm b * norm x \<le> norm (f x)" using b[THEN bspec[where x="(norm a / norm x) *\<^sub>R x"]]
        unfolding f.scaleR and ba using `x\<noteq>0` `a\<noteq>0`
        by (auto simp add: mult_commute pos_le_divide_eq pos_divide_le_eq)
    qed }
  ultimately
  show ?thesis by auto
qed

lemma closed_injective_image_subspace:
  fixes f :: "'a::euclidean_space \<Rightarrow> 'b::euclidean_space"
  assumes "subspace s" "bounded_linear f" "\<forall>x\<in>s. f x = 0 --> x = 0" "closed s"
  shows "closed(f ` s)"
proof-
  obtain e where "e>0" and e:"\<forall>x\<in>s. e * norm x \<le> norm (f x)" using injective_imp_isometric[OF assms(4,1,2,3)] by auto
  show ?thesis using complete_isometric_image[OF `e>0` assms(1,2) e] and assms(4)
    unfolding complete_eq_closed[THEN sym] by auto
qed


subsection {* Some properties of a canonical subspace *}

lemma subspace_substandard:
  "subspace {x::'a::euclidean_space. (\<forall>i\<in>Basis. P i \<longrightarrow> x\<bullet>i = 0)}"
  unfolding subspace_def by (auto simp: inner_add_left)

lemma closed_substandard:
 "closed {x::'a::euclidean_space. \<forall>i\<in>Basis. P i --> x\<bullet>i = 0}" (is "closed ?A")
proof-
  let ?D = "{i\<in>Basis. P i}"
  have "closed (\<Inter>i\<in>?D. {x::'a. x\<bullet>i = 0})"
    by (simp add: closed_INT closed_Collect_eq)
  also have "(\<Inter>i\<in>?D. {x::'a. x\<bullet>i = 0}) = ?A"
    by auto
  finally show "closed ?A" .
qed

lemma dim_substandard: assumes d: "d \<subseteq> Basis"
  shows "dim {x::'a::euclidean_space. \<forall>i\<in>Basis. i \<notin> d \<longrightarrow> x\<bullet>i = 0} = card d" (is "dim ?A = _")
proof-
  let ?D = "Basis :: 'a set"
  have "d \<subseteq> ?A" using d by (auto simp: inner_Basis)
  moreover
  { fix x::"'a" assume "x \<in> ?A"
    hence "finite d" "x \<in> ?A" using assms by(auto intro: finite_subset[OF _ finite_Basis])
    from this d have "x \<in> span d"
    proof(induct d arbitrary: x)
      case empty hence "x=0" apply(rule_tac euclidean_eqI) by auto
      thus ?case using subspace_0[OF subspace_span[of "{}"]] by auto
    next
      case (insert k F)
      hence *:"\<forall>i\<in>Basis. i \<notin> insert k F \<longrightarrow> x \<bullet> i = 0" by auto
      have **:"F \<subseteq> insert k F" by auto
      def y \<equiv> "x - (x\<bullet>k) *\<^sub>R k"
      have y:"x = y + (x\<bullet>k) *\<^sub>R k" unfolding y_def by auto
      { fix i assume i': "i \<notin> F" "i \<in> Basis"
        hence "y \<bullet> i = 0" unfolding y_def 
          using *[THEN bspec[where x=i]] insert by (auto simp: inner_simps inner_Basis) }
      hence "y \<in> span F" using insert by auto
      hence "y \<in> span (insert k F)"
        using span_mono[of F "insert k F"] using assms by auto
      moreover
      have "k \<in> span (insert k F)" by(rule span_superset, auto)
      hence "(x\<bullet>k) *\<^sub>R k \<in> span (insert k F)"
        using span_mul by auto
      ultimately
      have "y + (x\<bullet>k) *\<^sub>R k \<in> span (insert k F)"
        using span_add by auto
      thus ?case using y by auto
    qed
  }
  hence "?A \<subseteq> span d" by auto
  moreover
  { fix x assume "x \<in> d" hence "x \<in> ?D" using assms by auto  }
  hence "independent d" using independent_mono[OF independent_Basis, of d] and assms by auto
  moreover
  have "d \<subseteq> ?D" unfolding subset_eq using assms by auto
  ultimately show ?thesis using dim_unique[of d ?A] by auto
qed

text{* Hence closure and completeness of all subspaces.                          *}

lemma ex_card: assumes "n \<le> card A" shows "\<exists>S\<subseteq>A. card S = n"
proof cases
  assume "finite A"
  from ex_bij_betw_nat_finite[OF this] guess f ..
  moreover with `n \<le> card A` have "{..< n} \<subseteq> {..< card A}" "inj_on f {..< n}"
    by (auto simp: bij_betw_def intro: subset_inj_on)
  ultimately have "f ` {..< n} \<subseteq> A" "card (f ` {..< n}) = n"
    by (auto simp: bij_betw_def card_image)
  then show ?thesis by blast
next
  assume "\<not> finite A" with `n \<le> card A` show ?thesis by force
qed

lemma closed_subspace: fixes s::"('a::euclidean_space) set"
  assumes "subspace s" shows "closed s"
proof-
  have "dim s \<le> card (Basis :: 'a set)" using dim_subset_UNIV by auto
  with ex_card[OF this] obtain d :: "'a set" where t: "card d = dim s" and d: "d \<subseteq> Basis" by auto
  let ?t = "{x::'a. \<forall>i\<in>Basis. i \<notin> d \<longrightarrow> x\<bullet>i = 0}"
  have "\<exists>f. linear f \<and> f ` {x::'a. \<forall>i\<in>Basis. i \<notin> d \<longrightarrow> x \<bullet> i = 0} = s \<and>
      inj_on f {x::'a. \<forall>i\<in>Basis. i \<notin> d \<longrightarrow> x \<bullet> i = 0}"
    using dim_substandard[of d] t d assms
    by (intro subspace_isomorphism[OF subspace_substandard[of "\<lambda>i. i \<notin> d"]]) (auto simp: inner_Basis)
  then guess f by (elim exE conjE) note f = this
  interpret f: bounded_linear f using f unfolding linear_conv_bounded_linear by auto
  { fix x have "x\<in>?t \<Longrightarrow> f x = 0 \<Longrightarrow> x = 0" using f.zero d f(3)[THEN inj_onD, of x 0] by auto }
  moreover have "closed ?t" using closed_substandard .
  moreover have "subspace ?t" using subspace_substandard .
  ultimately show ?thesis using closed_injective_image_subspace[of ?t f]
    unfolding f(2) using f(1) unfolding linear_conv_bounded_linear by auto
qed

lemma complete_subspace:
  fixes s :: "('a::euclidean_space) set" shows "subspace s ==> complete s"
  using complete_eq_closed closed_subspace
  by auto

lemma dim_closure:
  fixes s :: "('a::euclidean_space) set"
  shows "dim(closure s) = dim s" (is "?dc = ?d")
proof-
  have "?dc \<le> ?d" using closure_minimal[OF span_inc, of s]
    using closed_subspace[OF subspace_span, of s]
    using dim_subset[of "closure s" "span s"] unfolding dim_span by auto
  thus ?thesis using dim_subset[OF closure_subset, of s] by auto
qed


subsection {* Affine transformations of intervals *}

lemma real_affinity_le:
 "0 < (m::'a::linordered_field) ==> (m * x + c \<le> y \<longleftrightarrow> x \<le> inverse(m) * y + -(c / m))"
  by (simp add: field_simps inverse_eq_divide)

lemma real_le_affinity:
 "0 < (m::'a::linordered_field) ==> (y \<le> m * x + c \<longleftrightarrow> inverse(m) * y + -(c / m) \<le> x)"
  by (simp add: field_simps inverse_eq_divide)

lemma real_affinity_lt:
 "0 < (m::'a::linordered_field) ==> (m * x + c < y \<longleftrightarrow> x < inverse(m) * y + -(c / m))"
  by (simp add: field_simps inverse_eq_divide)

lemma real_lt_affinity:
 "0 < (m::'a::linordered_field) ==> (y < m * x + c \<longleftrightarrow> inverse(m) * y + -(c / m) < x)"
  by (simp add: field_simps inverse_eq_divide)

lemma real_affinity_eq:
 "(m::'a::linordered_field) \<noteq> 0 ==> (m * x + c = y \<longleftrightarrow> x = inverse(m) * y + -(c / m))"
  by (simp add: field_simps inverse_eq_divide)

lemma real_eq_affinity:
 "(m::'a::linordered_field) \<noteq> 0 ==> (y = m * x + c  \<longleftrightarrow> inverse(m) * y + -(c / m) = x)"
  by (simp add: field_simps inverse_eq_divide)

lemma image_affinity_interval: fixes m::real
  fixes a b c :: "'a::ordered_euclidean_space"
  shows "(\<lambda>x. m *\<^sub>R x + c) ` {a .. b} =
            (if {a .. b} = {} then {}
            else (if 0 \<le> m then {m *\<^sub>R a + c .. m *\<^sub>R b + c}
            else {m *\<^sub>R b + c .. m *\<^sub>R a + c}))"
proof(cases "m=0")  
  { fix x assume "x \<le> c" "c \<le> x"
    hence "x=c" unfolding eucl_le[where 'a='a] apply-
      apply(subst euclidean_eq_iff) by (auto intro: order_antisym) }
  moreover case True
  moreover have "c \<in> {m *\<^sub>R a + c..m *\<^sub>R b + c}" unfolding True by(auto simp add: eucl_le[where 'a='a])
  ultimately show ?thesis by auto
next
  case False
  { fix y assume "a \<le> y" "y \<le> b" "m > 0"
    hence "m *\<^sub>R a + c \<le> m *\<^sub>R y + c"  "m *\<^sub>R y + c \<le> m *\<^sub>R b + c"
      unfolding eucl_le[where 'a='a] by (auto simp: inner_simps)
  } moreover
  { fix y assume "a \<le> y" "y \<le> b" "m < 0"
    hence "m *\<^sub>R b + c \<le> m *\<^sub>R y + c"  "m *\<^sub>R y + c \<le> m *\<^sub>R a + c"
      unfolding eucl_le[where 'a='a] by(auto simp add: mult_left_mono_neg inner_simps)
  } moreover
  { fix y assume "m > 0"  "m *\<^sub>R a + c \<le> y"  "y \<le> m *\<^sub>R b + c"
    hence "y \<in> (\<lambda>x. m *\<^sub>R x + c) ` {a..b}"
      unfolding image_iff Bex_def mem_interval eucl_le[where 'a='a]
      apply (intro exI[where x="(1 / m) *\<^sub>R (y - c)"])
      by(auto simp add: pos_le_divide_eq pos_divide_le_eq mult_commute diff_le_iff inner_simps)
  } moreover
  { fix y assume "m *\<^sub>R b + c \<le> y" "y \<le> m *\<^sub>R a + c" "m < 0"
    hence "y \<in> (\<lambda>x. m *\<^sub>R x + c) ` {a..b}"
      unfolding image_iff Bex_def mem_interval eucl_le[where 'a='a]
      apply (intro exI[where x="(1 / m) *\<^sub>R (y - c)"])
      by(auto simp add: neg_le_divide_eq neg_divide_le_eq mult_commute diff_le_iff inner_simps)
  }
  ultimately show ?thesis using False by auto
qed

lemma image_smult_interval:"(\<lambda>x. m *\<^sub>R (x::_::ordered_euclidean_space)) ` {a..b} =
  (if {a..b} = {} then {} else if 0 \<le> m then {m *\<^sub>R a..m *\<^sub>R b} else {m *\<^sub>R b..m *\<^sub>R a})"
  using image_affinity_interval[of m 0 a b] by auto


subsection {* Banach fixed point theorem (not really topological...) *}

lemma banach_fix:
  assumes s:"complete s" "s \<noteq> {}" and c:"0 \<le> c" "c < 1" and f:"(f ` s) \<subseteq> s" and
          lipschitz:"\<forall>x\<in>s. \<forall>y\<in>s. dist (f x) (f y) \<le> c * dist x y"
  shows "\<exists>! x\<in>s. (f x = x)"
proof-
  have "1 - c > 0" using c by auto

  from s(2) obtain z0 where "z0 \<in> s" by auto
  def z \<equiv> "\<lambda>n. (f ^^ n) z0"
  { fix n::nat
    have "z n \<in> s" unfolding z_def
    proof(induct n) case 0 thus ?case using `z0 \<in>s` by auto
    next case Suc thus ?case using f by auto qed }
  note z_in_s = this

  def d \<equiv> "dist (z 0) (z 1)"

  have fzn:"\<And>n. f (z n) = z (Suc n)" unfolding z_def by auto
  { fix n::nat
    have "dist (z n) (z (Suc n)) \<le> (c ^ n) * d"
    proof(induct n)
      case 0 thus ?case unfolding d_def by auto
    next
      case (Suc m)
      hence "c * dist (z m) (z (Suc m)) \<le> c ^ Suc m * d"
        using `0 \<le> c` using mult_left_mono[of "dist (z m) (z (Suc m))" "c ^ m * d" c] by auto
      thus ?case using lipschitz[THEN bspec[where x="z m"], OF z_in_s, THEN bspec[where x="z (Suc m)"], OF z_in_s]
        unfolding fzn and mult_le_cancel_left by auto
    qed
  } note cf_z = this

  { fix n m::nat
    have "(1 - c) * dist (z m) (z (m+n)) \<le> (c ^ m) * d * (1 - c ^ n)"
    proof(induct n)
      case 0 show ?case by auto
    next
      case (Suc k)
      have "(1 - c) * dist (z m) (z (m + Suc k)) \<le> (1 - c) * (dist (z m) (z (m + k)) + dist (z (m + k)) (z (Suc (m + k))))"
        using dist_triangle and c by(auto simp add: dist_triangle)
      also have "\<dots> \<le> (1 - c) * (dist (z m) (z (m + k)) + c ^ (m + k) * d)"
        using cf_z[of "m + k"] and c by auto
      also have "\<dots> \<le> c ^ m * d * (1 - c ^ k) + (1 - c) * c ^ (m + k) * d"
        using Suc by (auto simp add: field_simps)
      also have "\<dots> = (c ^ m) * (d * (1 - c ^ k) + (1 - c) * c ^ k * d)"
        unfolding power_add by (auto simp add: field_simps)
      also have "\<dots> \<le> (c ^ m) * d * (1 - c ^ Suc k)"
        using c by (auto simp add: field_simps)
      finally show ?case by auto
    qed
  } note cf_z2 = this
  { fix e::real assume "e>0"
    hence "\<exists>N. \<forall>m n. N \<le> m \<and> N \<le> n \<longrightarrow> dist (z m) (z n) < e"
    proof(cases "d = 0")
      case True
      have *: "\<And>x. ((1 - c) * x \<le> 0) = (x \<le> 0)" using `1 - c > 0`
        by (metis mult_zero_left mult_commute real_mult_le_cancel_iff1)
      from True have "\<And>n. z n = z0" using cf_z2[of 0] and c unfolding z_def
        by (simp add: *)
      thus ?thesis using `e>0` by auto
    next
      case False hence "d>0" unfolding d_def using zero_le_dist[of "z 0" "z 1"]
        by (metis False d_def less_le)
      hence "0 < e * (1 - c) / d" using `e>0` and `1-c>0`
        using divide_pos_pos[of "e * (1 - c)" d] and mult_pos_pos[of e "1 - c"] by auto
      then obtain N where N:"c ^ N < e * (1 - c) / d" using real_arch_pow_inv[of "e * (1 - c) / d" c] and c by auto
      { fix m n::nat assume "m>n" and as:"m\<ge>N" "n\<ge>N"
        have *:"c ^ n \<le> c ^ N" using `n\<ge>N` and c using power_decreasing[OF `n\<ge>N`, of c] by auto
        have "1 - c ^ (m - n) > 0" using c and power_strict_mono[of c 1 "m - n"] using `m>n` by auto
        hence **:"d * (1 - c ^ (m - n)) / (1 - c) > 0"
          using mult_pos_pos[OF `d>0`, of "1 - c ^ (m - n)"]
          using divide_pos_pos[of "d * (1 - c ^ (m - n))" "1 - c"]
          using `0 < 1 - c` by auto

        have "dist (z m) (z n) \<le> c ^ n * d * (1 - c ^ (m - n)) / (1 - c)"
          using cf_z2[of n "m - n"] and `m>n` unfolding pos_le_divide_eq[OF `1-c>0`]
          by (auto simp add: mult_commute dist_commute)
        also have "\<dots> \<le> c ^ N * d * (1 - c ^ (m - n)) / (1 - c)"
          using mult_right_mono[OF * order_less_imp_le[OF **]]
          unfolding mult_assoc by auto
        also have "\<dots> < (e * (1 - c) / d) * d * (1 - c ^ (m - n)) / (1 - c)"
          using mult_strict_right_mono[OF N **] unfolding mult_assoc by auto
        also have "\<dots> = e * (1 - c ^ (m - n))" using c and `d>0` and `1 - c > 0` by auto
        also have "\<dots> \<le> e" using c and `1 - c ^ (m - n) > 0` and `e>0` using mult_right_le_one_le[of e "1 - c ^ (m - n)"] by auto
        finally have  "dist (z m) (z n) < e" by auto
      } note * = this
      { fix m n::nat assume as:"N\<le>m" "N\<le>n"
        hence "dist (z n) (z m) < e"
        proof(cases "n = m")
          case True thus ?thesis using `e>0` by auto
        next
          case False thus ?thesis using as and *[of n m] *[of m n] unfolding nat_neq_iff by (auto simp add: dist_commute)
        qed }
      thus ?thesis by auto
    qed
  }
  hence "Cauchy z" unfolding cauchy_def by auto
  then obtain x where "x\<in>s" and x:"(z ---> x) sequentially" using s(1)[unfolded compact_def complete_def, THEN spec[where x=z]] and z_in_s by auto

  def e \<equiv> "dist (f x) x"
  have "e = 0" proof(rule ccontr)
    assume "e \<noteq> 0" hence "e>0" unfolding e_def using zero_le_dist[of "f x" x]
      by (metis dist_eq_0_iff dist_nz e_def)
    then obtain N where N:"\<forall>n\<ge>N. dist (z n) x < e / 2"
      using x[unfolded LIMSEQ_def, THEN spec[where x="e/2"]] by auto
    hence N':"dist (z N) x < e / 2" by auto

    have *:"c * dist (z N) x \<le> dist (z N) x" unfolding mult_le_cancel_right2
      using zero_le_dist[of "z N" x] and c
      by (metis dist_eq_0_iff dist_nz order_less_asym less_le)
    have "dist (f (z N)) (f x) \<le> c * dist (z N) x" using lipschitz[THEN bspec[where x="z N"], THEN bspec[where x=x]]
      using z_in_s[of N] `x\<in>s` using c by auto
    also have "\<dots> < e / 2" using N' and c using * by auto
    finally show False unfolding fzn
      using N[THEN spec[where x="Suc N"]] and dist_triangle_half_r[of "z (Suc N)" "f x" e x]
      unfolding e_def by auto
  qed
  hence "f x = x" unfolding e_def by auto
  moreover
  { fix y assume "f y = y" "y\<in>s"
    hence "dist x y \<le> c * dist x y" using lipschitz[THEN bspec[where x=x], THEN bspec[where x=y]]
      using `x\<in>s` and `f x = x` by auto
    hence "dist x y = 0" unfolding mult_le_cancel_right1
      using c and zero_le_dist[of x y] by auto
    hence "y = x" by auto
  }
  ultimately show ?thesis using `x\<in>s` by blast+
qed

subsection {* Edelstein fixed point theorem *}

lemma edelstein_fix:
  fixes s :: "'a::metric_space set"
  assumes s:"compact s" "s \<noteq> {}" and gs:"(g ` s) \<subseteq> s"
      and dist:"\<forall>x\<in>s. \<forall>y\<in>s. x \<noteq> y \<longrightarrow> dist (g x) (g y) < dist x y"
  shows "\<exists>! x\<in>s. g x = x"
proof(cases "\<exists>x\<in>s. g x \<noteq> x")
  obtain x where "x\<in>s" using s(2) by auto
  case False hence g:"\<forall>x\<in>s. g x = x" by auto
  { fix y assume "y\<in>s"
    hence "x = y" using `x\<in>s` and dist[THEN bspec[where x=x], THEN bspec[where x=y]]
      unfolding g[THEN bspec[where x=x], OF `x\<in>s`]
      unfolding g[THEN bspec[where x=y], OF `y\<in>s`] by auto  }
  thus ?thesis using `x\<in>s` and g by blast+
next
  case True
  then obtain x where [simp]:"x\<in>s" and "g x \<noteq> x" by auto
  { fix x y assume "x \<in> s" "y \<in> s"
    hence "dist (g x) (g y) \<le> dist x y"
      using dist[THEN bspec[where x=x], THEN bspec[where x=y]] by auto } note dist' = this
  def y \<equiv> "g x"
  have [simp]:"y\<in>s" unfolding y_def using gs[unfolded image_subset_iff] and `x\<in>s` by blast
  def f \<equiv> "\<lambda>n. g ^^ n"
  have [simp]:"\<And>n z. g (f n z) = f (Suc n) z" unfolding f_def by auto
  have [simp]:"\<And>z. f 0 z = z" unfolding f_def by auto
  { fix n::nat and z assume "z\<in>s"
    have "f n z \<in> s" unfolding f_def
    proof(induct n)
      case 0 thus ?case using `z\<in>s` by simp
    next
      case (Suc n) thus ?case using gs[unfolded image_subset_iff] by auto
    qed } note fs = this
  { fix m n ::nat assume "m\<le>n"
    fix w z assume "w\<in>s" "z\<in>s"
    have "dist (f n w) (f n z) \<le> dist (f m w) (f m z)" using `m\<le>n`
    proof(induct n)
      case 0 thus ?case by auto
    next
      case (Suc n)
      thus ?case proof(cases "m\<le>n")
        case True thus ?thesis using Suc(1)
          using dist'[OF fs fs, OF `w\<in>s` `z\<in>s`, of n n] by auto
      next
        case False hence mn:"m = Suc n" using Suc(2) by simp
        show ?thesis unfolding mn  by auto
      qed
    qed } note distf = this

  def h \<equiv> "\<lambda>n. (f n x, f n y)"
  let ?s2 = "s \<times> s"
  obtain l r where "l\<in>?s2" and r:"subseq r" and lr:"((h \<circ> r) ---> l) sequentially"
    using compact_Times [OF s(1) s(1), unfolded compact_def, THEN spec[where x=h]] unfolding  h_def
    using fs[OF `x\<in>s`] and fs[OF `y\<in>s`] by blast
  def a \<equiv> "fst l" def b \<equiv> "snd l"
  have lab:"l = (a, b)" unfolding a_def b_def by simp
  have [simp]:"a\<in>s" "b\<in>s" unfolding a_def b_def using `l\<in>?s2` by auto

  have lima:"((fst \<circ> (h \<circ> r)) ---> a) sequentially"
   and limb:"((snd \<circ> (h \<circ> r)) ---> b) sequentially"
    using lr
    unfolding o_def a_def b_def by (rule tendsto_intros)+

  { fix n::nat
    have *:"\<And>fx fy (x::'a) y. dist fx fy \<le> dist x y \<Longrightarrow> \<not> (\<bar>dist fx fy - dist a b\<bar> < dist a b - dist x y)" by auto

    { assume as:"dist a b > dist (f n x) (f n y)"
      then obtain Na Nb where "\<forall>m\<ge>Na. dist (f (r m) x) a < (dist a b - dist (f n x) (f n y)) / 2"
        and "\<forall>m\<ge>Nb. dist (f (r m) y) b < (dist a b - dist (f n x) (f n y)) / 2"
        using lima limb unfolding h_def LIMSEQ_def by (fastforce simp del: less_divide_eq_numeral1)
      hence "\<bar>dist (f (r (Na + Nb + n)) x) (f (r (Na + Nb + n)) y) - dist a b\<bar> < dist a b - dist (f n x) (f n y)"
        apply -
        apply (drule_tac x="Na+Nb+n" in spec, drule mp, simp)
        apply (drule_tac x="Na+Nb+n" in spec, drule mp, simp)
        apply (drule (1) add_strict_mono, simp only: real_sum_of_halves)
        apply (erule le_less_trans [rotated])
        apply (erule thin_rl)
        apply (rule abs_leI)
        apply (simp add: diff_le_iff add_assoc)
        apply (rule order_trans [OF dist_triangle add_left_mono])
        apply (subst add_commute, rule dist_triangle2)
        apply (simp add: diff_le_iff add_assoc)
        apply (rule order_trans [OF dist_triangle3 add_left_mono])
        apply (subst add_commute, rule dist_triangle)
        done
      moreover
      have "\<bar>dist (f (r (Na + Nb + n)) x) (f (r (Na + Nb + n)) y) - dist a b\<bar> \<ge> dist a b - dist (f n x) (f n y)"
        using distf[of n "r (Na+Nb+n)", OF _ `x\<in>s` `y\<in>s`]
        using seq_suble[OF r, of "Na+Nb+n"]
        using *[of "f (r (Na + Nb + n)) x" "f (r (Na + Nb + n)) y" "f n x" "f n y"] by auto
      ultimately have False by simp
    }
    hence "dist a b \<le> dist (f n x) (f n y)" by(rule ccontr)auto }
  note ab_fn = this

  have [simp]:"a = b" proof(rule ccontr)
    def e \<equiv> "dist a b - dist (g a) (g b)"
    assume "a\<noteq>b" hence "e > 0" unfolding e_def using dist by fastforce
    hence "\<exists>n. dist (f n x) a < e/2 \<and> dist (f n y) b < e/2"
      using lima limb unfolding LIMSEQ_def
      apply (auto elim!: allE[where x="e/2"]) apply(rename_tac N N', rule_tac x="r (max N N')" in exI) unfolding h_def by fastforce
    then obtain n where n:"dist (f n x) a < e/2 \<and> dist (f n y) b < e/2" by auto
    have "dist (f (Suc n) x) (g a) \<le> dist (f n x) a"
      using dist[THEN bspec[where x="f n x"], THEN bspec[where x="a"]] and fs by auto
    moreover have "dist (f (Suc n) y) (g b) \<le> dist (f n y) b"
      using dist[THEN bspec[where x="f n y"], THEN bspec[where x="b"]] and fs by auto
    ultimately have "dist (f (Suc n) x) (g a) + dist (f (Suc n) y) (g b) < e" using n by auto
    thus False unfolding e_def using ab_fn[of "Suc n"]
      using dist_triangle2 [of "f (Suc n) y" "g a" "g b"]
      using dist_triangle2 [of "f (Suc n) x" "f (Suc n) y" "g a"]
      by auto
  qed

  have [simp]:"\<And>n. f (Suc n) x = f n y" unfolding f_def y_def by(induct_tac n)auto
  { fix x y assume "x\<in>s" "y\<in>s" moreover
    fix e::real assume "e>0" ultimately
    have "dist y x < e \<longrightarrow> dist (g y) (g x) < e" using dist by fastforce }
  hence "continuous_on s g" unfolding continuous_on_iff by auto

  hence "((snd \<circ> h \<circ> r) ---> g a) sequentially" unfolding continuous_on_sequentially
    apply (rule allE[where x="\<lambda>n. (fst \<circ> h \<circ> r) n"]) apply (erule ballE[where x=a])
    using lima unfolding h_def o_def using fs[OF `x\<in>s`] by (auto simp add: y_def)
  hence "g a = a" using tendsto_unique[OF trivial_limit_sequentially limb, of "g a"]
    unfolding `a=b` and o_assoc by auto
  moreover
  { fix x assume "x\<in>s" "g x = x" "x\<noteq>a"
    hence "False" using dist[THEN bspec[where x=a], THEN bspec[where x=x]]
      using `g a = a` and `a\<in>s` by auto  }
  ultimately show "\<exists>!x\<in>s. g x = x" using `a\<in>s` by blast
qed

declare tendsto_const [intro] (* FIXME: move *)

end
