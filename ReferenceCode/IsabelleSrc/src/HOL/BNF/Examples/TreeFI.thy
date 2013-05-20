(*  Title:      HOL/BNF/Examples/TreeFI.thy
    Author:     Dmitriy Traytel, TU Muenchen
    Author:     Andrei Popescu, TU Muenchen
    Copyright   2012

Finitely branching possibly infinite trees.
*)

header {* Finitely Branching Possibly Infinite Trees *}

theory TreeFI
imports ListF
begin

codata 'a treeFI = Tree (lab: 'a) (sub: "'a treeFI listF")

lemma pre_treeFI_listF_set[simp]: "pre_treeFI_set2 (i, xs) = listF_set xs"
unfolding pre_treeFI_set2_def collect_def[abs_def] prod_set_defs
by (auto simp add: listF.set_natural')

lemma dtor[simp]: "treeFI_dtor tr = (lab tr, sub tr)"
unfolding lab_def sub_def treeFI_case_def
by (metis fst_def pair_collapse snd_def)

definition pair_fun (infixr "\<odot>" 50) where
  "f \<odot> g \<equiv> \<lambda>x. (f x, g x)"

(* Tree reverse:*)
definition "trev \<equiv> treeFI_unfold lab (lrev o sub)"

lemma trev_simps1[simp]: "lab (trev t) = lab t"
unfolding trev_def by simp

lemma trev_simps2[simp]: "sub (trev t) = listF_map trev (lrev (sub t))"
unfolding trev_def by simp

lemma treeFI_coinduct:
assumes *: "phi x y"
and step: "\<And>a b. phi a b \<Longrightarrow>
   lab a = lab b \<and>
   lengthh (sub a) = lengthh (sub b) \<and>
   (\<forall>i < lengthh (sub a). phi (nthh (sub a) i) (nthh (sub b) i))"
shows "x = y"
proof (rule mp[OF treeFI.dtor_map_coinduct, of phi, OF _ *])
  fix a b :: "'a treeFI"
  let ?zs = "zipp (sub a) (sub b)"
  let ?z = "(lab a, ?zs)"
  assume "phi a b"
  with step have step': "lab a = lab b" "lengthh (sub a) = lengthh (sub b)"
    "\<forall>i < lengthh (sub a). phi (nthh (sub a) i) (nthh (sub b) i)" by auto
  hence "pre_treeFI_map id fst ?z = treeFI_dtor a" "pre_treeFI_map id snd ?z = treeFI_dtor b"
    unfolding pre_treeFI_map_def by auto
  moreover have "\<forall>(x, y) \<in> pre_treeFI_set2 ?z. phi x y"
  proof safe
    fix z1 z2
    assume "(z1, z2) \<in> pre_treeFI_set2 ?z"
    hence "(z1, z2) \<in> listF_set ?zs" by auto
    hence "\<exists>i < lengthh ?zs. nthh ?zs i = (z1, z2)" by auto
    with step'(2) obtain i where "i < lengthh (sub a)"
      "nthh (sub a) i = z1" "nthh (sub b) i = z2" by auto
    with step'(3) show "phi z1 z2" by auto
  qed
  ultimately show "\<exists>z.
    (pre_treeFI_map id fst z = treeFI_dtor a \<and>
    pre_treeFI_map id snd z = treeFI_dtor b) \<and>
    (\<forall>x y. (x, y) \<in> pre_treeFI_set2 z \<longrightarrow> phi x y)" by blast
qed

lemma trev_trev: "trev (trev tr) = tr"
by (rule treeFI_coinduct[of "%a b. trev (trev b) = a"]) auto

end
