(*  Title:      HOL/Number_Theory/UniqueFactorization.thy
    Author:     Jeremy Avigad

Unique factorization for the natural numbers and the integers.

Note: there were previous Isabelle formalizations of unique
factorization due to Thomas Marthedal Rasmussen, and, building on
that, by Jeremy Avigad and David Gray.  
*)

header {* UniqueFactorization *}

theory UniqueFactorization
imports Cong "~~/src/HOL/Library/Multiset"
begin

(* inherited from Multiset *)
declare One_nat_def [simp del] 

(* As a simp or intro rule,

     prime p \<Longrightarrow> p > 0

   wreaks havoc here. When the premise includes ALL x :# M. prime x, it 
   leads to the backchaining

     x > 0  
     prime x 
     x :# M   which is, unfortunately,
     count M x > 0
*)

(* Here is a version of set product for multisets. Is it worth moving
   to multiset.thy? If so, one should similarly define msetsum for abelian 
   semirings, using of_nat. Also, is it worth developing bounded quantifiers 
   "ALL i :# M. P i"? 
*)

context comm_monoid_mult
begin

definition msetprod :: "'a multiset \<Rightarrow> 'a"
where
  "msetprod M = Multiset.fold times 1 M"

lemma msetprod_empty [simp]:
  "msetprod {#} = 1"
  by (simp add: msetprod_def)

lemma msetprod_singleton [simp]:
  "msetprod {#x#} = x"
proof -
  interpret comp_fun_commute times
    by (fact comp_fun_commute)
  show ?thesis by (simp add: msetprod_def)
qed

lemma msetprod_Un [simp]:
  "msetprod (A + B) = msetprod A * msetprod B" 
proof -
  interpret comp_fun_commute times
    by (fact comp_fun_commute)
  show ?thesis by (induct B) (simp_all add: msetprod_def mult_ac)
qed

lemma msetprod_multiplicity:
  "msetprod M = setprod (\<lambda>x. x ^ count M x) (set_of M)"
  by (simp add: msetprod_def setprod_def Multiset.fold_def fold_image_def funpow_times_power)

abbreviation msetprod_image :: "('b \<Rightarrow> 'a) \<Rightarrow> 'b multiset \<Rightarrow> 'a"
where
  "msetprod_image f M \<equiv> msetprod (image_mset f M)"

end

syntax
  "_msetprod_image" :: "pttrn \<Rightarrow> 'b set \<Rightarrow> 'a \<Rightarrow> 'a::comm_monoid_mult" 
      ("(3PROD _:#_. _)" [0, 51, 10] 10)

syntax (xsymbols)
  "_msetprod_image" :: "pttrn \<Rightarrow> 'b set \<Rightarrow> 'a \<Rightarrow> 'a::comm_monoid_mult" 
      ("(3\<Pi>_\<in>#_. _)" [0, 51, 10] 10)

syntax (HTML output)
  "_msetprod_image" :: "pttrn \<Rightarrow> 'b set \<Rightarrow> 'a \<Rightarrow> 'a::comm_monoid_mult" 
      ("(3\<Pi>_\<in>#_. _)" [0, 51, 10] 10)

translations
  "PROD i :# A. b" == "CONST msetprod_image (\<lambda>i. b) A"

lemma (in comm_semiring_1) dvd_msetprod:
  assumes "x \<in># A"
  shows "x dvd msetprod A"
proof -
  from assms have "A = (A - {#x#}) + {#x#}" by simp
  then obtain B where "A = B + {#x#}" ..
  then show ?thesis by simp
qed


subsection {* unique factorization: multiset version *}

lemma multiset_prime_factorization_exists [rule_format]: "n > 0 --> 
    (EX M. (ALL (p::nat) : set_of M. prime p) & n = (PROD i :# M. i))"
proof (rule nat_less_induct, clarify)
  fix n :: nat
  assume ih: "ALL m < n. 0 < m --> (EX M. (ALL p : set_of M. prime p) & m = 
      (PROD i :# M. i))"
  assume "(n::nat) > 0"
  then have "n = 1 | (n > 1 & prime n) | (n > 1 & ~ prime n)"
    by arith
  moreover {
    assume "n = 1"
    then have "(ALL p : set_of {#}. prime p) & n = (PROD i :# {#}. i)"
        by (auto simp add: msetprod_def)
  } moreover {
    assume "n > 1" and "prime n"
    then have "(ALL p : set_of {# n #}. prime p) & n = (PROD i :# {# n #}. i)"
      by auto
  } moreover {
    assume "n > 1" and "~ prime n"
    with not_prime_eq_prod_nat
    obtain m k where n: "n = m * k & 1 < m & m < n & 1 < k & k < n"
      by blast
    with ih obtain Q R where "(ALL p : set_of Q. prime p) & m = (PROD i:#Q. i)"
        and "(ALL p: set_of R. prime p) & k = (PROD i:#R. i)"
      by blast
    then have "(ALL p: set_of (Q + R). prime p) & n = (PROD i :# Q + R. i)"
      by (auto simp add: n msetprod_Un)
    then have "EX M. (ALL p : set_of M. prime p) & n = (PROD i :# M. i)"..
  }
  ultimately show "EX M. (ALL p : set_of M. prime p) & n = (PROD i::nat:#M. i)"
    by blast
qed

lemma multiset_prime_factorization_unique_aux:
  fixes a :: nat
  assumes "(ALL p : set_of M. prime p)" and
    "(ALL p : set_of N. prime p)" and
    "(PROD i :# M. i) dvd (PROD i:# N. i)"
  shows
    "count M a <= count N a"
proof cases
  assume M: "a : set_of M"
  with assms have a: "prime a" by auto
  with M have "a ^ count M a dvd (PROD i :# M. i)"
    by (auto simp add: msetprod_multiplicity intro: dvd_setprod)
  also have "... dvd (PROD i :# N. i)" by (rule assms)
  also have "... = (PROD i : (set_of N). i ^ (count N i))"
    by (simp add: msetprod_multiplicity)
  also have "... = a^(count N a) * (PROD i : (set_of N - {a}). i ^ (count N i))"
  proof (cases)
    assume "a : set_of N"
    then have b: "set_of N = {a} Un (set_of N - {a})"
      by auto
    then show ?thesis
      by (subst (1) b, subst setprod_Un_disjoint, auto)
  next
    assume "a ~: set_of N" 
    then show ?thesis by auto
  qed
  finally have "a ^ count M a dvd 
      a^(count N a) * (PROD i : (set_of N - {a}). i ^ (count N i))".
  moreover
  have "coprime (a ^ count M a) (PROD i : (set_of N - {a}). i ^ (count N i))"
    apply (subst gcd_commute_nat)
    apply (rule setprod_coprime_nat)
    apply (rule primes_imp_powers_coprime_nat)
    using assms M
    apply auto
    done
  ultimately have "a ^ count M a dvd a^(count N a)"
    by (elim coprime_dvd_mult_nat)
  with a show ?thesis 
    apply (intro power_dvd_imp_le)
    apply auto
    done
next
  assume "a ~: set_of M"
  then show ?thesis by auto
qed

lemma multiset_prime_factorization_unique:
  assumes "(ALL (p::nat) : set_of M. prime p)" and
    "(ALL p : set_of N. prime p)" and
    "(PROD i :# M. i) = (PROD i:# N. i)"
  shows
    "M = N"
proof -
  {
    fix a
    from assms have "count M a <= count N a"
      by (intro multiset_prime_factorization_unique_aux, auto) 
    moreover from assms have "count N a <= count M a"
      by (intro multiset_prime_factorization_unique_aux, auto) 
    ultimately have "count M a = count N a"
      by auto
  }
  then show ?thesis by (simp add:multiset_eq_iff)
qed

definition multiset_prime_factorization :: "nat => nat multiset"
where
  "multiset_prime_factorization n ==
     if n > 0 then (THE M. ((ALL p : set_of M. prime p) & 
       n = (PROD i :# M. i)))
     else {#}"

lemma multiset_prime_factorization: "n > 0 ==>
    (ALL p : set_of (multiset_prime_factorization n). prime p) &
       n = (PROD i :# (multiset_prime_factorization n). i)"
  apply (unfold multiset_prime_factorization_def)
  apply clarsimp
  apply (frule multiset_prime_factorization_exists)
  apply clarify
  apply (rule theI)
  apply (insert multiset_prime_factorization_unique)
  apply auto
done


subsection {* Prime factors and multiplicity for nats and ints *}

class unique_factorization =
  fixes multiplicity :: "'a \<Rightarrow> 'a \<Rightarrow> nat"
    and prime_factors :: "'a \<Rightarrow> 'a set"

(* definitions for the natural numbers *)

instantiation nat :: unique_factorization
begin

definition multiplicity_nat :: "nat \<Rightarrow> nat \<Rightarrow> nat"
  where "multiplicity_nat p n = count (multiset_prime_factorization n) p"

definition prime_factors_nat :: "nat \<Rightarrow> nat set"
  where "prime_factors_nat n = set_of (multiset_prime_factorization n)"

instance ..

end

(* definitions for the integers *)

instantiation int :: unique_factorization
begin

definition multiplicity_int :: "int \<Rightarrow> int \<Rightarrow> nat"
  where "multiplicity_int p n = multiplicity (nat p) (nat n)"

definition prime_factors_int :: "int \<Rightarrow> int set"
  where "prime_factors_int n = int ` (prime_factors (nat n))"

instance ..

end


subsection {* Set up transfer *}

lemma transfer_nat_int_prime_factors: "prime_factors (nat n) = nat ` prime_factors n"
  unfolding prime_factors_int_def
  apply auto
  apply (subst transfer_int_nat_set_return_embed)
  apply assumption
  done

lemma transfer_nat_int_prime_factors_closure: "n >= 0 \<Longrightarrow> nat_set (prime_factors n)"
  by (auto simp add: nat_set_def prime_factors_int_def)

lemma transfer_nat_int_multiplicity: "p >= 0 \<Longrightarrow> n >= 0 \<Longrightarrow>
    multiplicity (nat p) (nat n) = multiplicity p n"
  by (auto simp add: multiplicity_int_def)

declare transfer_morphism_nat_int[transfer add return: 
  transfer_nat_int_prime_factors transfer_nat_int_prime_factors_closure
  transfer_nat_int_multiplicity]


lemma transfer_int_nat_prime_factors: "prime_factors (int n) = int ` prime_factors n"
  unfolding prime_factors_int_def by auto

lemma transfer_int_nat_prime_factors_closure: "is_nat n \<Longrightarrow> 
    nat_set (prime_factors n)"
  by (simp only: transfer_nat_int_prime_factors_closure is_nat_def)

lemma transfer_int_nat_multiplicity: 
    "multiplicity (int p) (int n) = multiplicity p n"
  by (auto simp add: multiplicity_int_def)

declare transfer_morphism_int_nat[transfer add return: 
  transfer_int_nat_prime_factors transfer_int_nat_prime_factors_closure
  transfer_int_nat_multiplicity]


subsection {* Properties of prime factors and multiplicity for nats and ints *}

lemma prime_factors_ge_0_int [elim]: "p : prime_factors (n::int) \<Longrightarrow> p >= 0"
  unfolding prime_factors_int_def by auto

lemma prime_factors_prime_nat [intro]: "p : prime_factors (n::nat) \<Longrightarrow> prime p"
  apply (cases "n = 0")
  apply (simp add: prime_factors_nat_def multiset_prime_factorization_def)
  apply (auto simp add: prime_factors_nat_def multiset_prime_factorization)
  done

lemma prime_factors_prime_int [intro]:
  assumes "n >= 0" and "p : prime_factors (n::int)"
  shows "prime p"
  apply (rule prime_factors_prime_nat [transferred, of n p])
  using assms apply auto
  done

lemma prime_factors_gt_0_nat [elim]: "p : prime_factors x \<Longrightarrow> p > (0::nat)"
  apply (frule prime_factors_prime_nat)
  apply auto
  done

lemma prime_factors_gt_0_int [elim]: "x >= 0 \<Longrightarrow> p : prime_factors x \<Longrightarrow> 
    p > (0::int)"
  apply (frule (1) prime_factors_prime_int)
  apply auto
  done

lemma prime_factors_finite_nat [iff]: "finite (prime_factors (n::nat))"
  unfolding prime_factors_nat_def by auto

lemma prime_factors_finite_int [iff]: "finite (prime_factors (n::int))"
  unfolding prime_factors_int_def by auto

lemma prime_factors_altdef_nat: "prime_factors (n::nat) = 
    {p. multiplicity p n > 0}"
  by (force simp add: prime_factors_nat_def multiplicity_nat_def)

lemma prime_factors_altdef_int: "prime_factors (n::int) = 
    {p. p >= 0 & multiplicity p n > 0}"
  apply (unfold prime_factors_int_def multiplicity_int_def)
  apply (subst prime_factors_altdef_nat)
  apply (auto simp add: image_def)
  done

lemma prime_factorization_nat: "(n::nat) > 0 \<Longrightarrow> 
    n = (PROD p : prime_factors n. p^(multiplicity p n))"
  apply (frule multiset_prime_factorization)
  apply (simp add: prime_factors_nat_def multiplicity_nat_def msetprod_multiplicity)
  done

lemma prime_factorization_int: 
  assumes "(n::int) > 0"
  shows "n = (PROD p : prime_factors n. p^(multiplicity p n))"
  apply (rule prime_factorization_nat [transferred, of n])
  using assms apply auto
  done

lemma neq_zero_eq_gt_zero_nat: "((x::nat) ~= 0) = (x > 0)"
  by auto

lemma prime_factorization_unique_nat: 
  fixes f :: "nat \<Rightarrow> _"
  assumes S_eq: "S = {p. 0 < f p}" and "finite S"
    and "\<forall>p\<in>S. prime p" "n = (\<Prod>p\<in>S. p ^ f p)"
  shows "S = prime_factors n \<and> (\<forall>p. f p = multiplicity p n)"
proof -
  from assms have "f \<in> multiset"
    by (auto simp add: multiset_def)
  moreover from assms have "n > 0" by force
  ultimately have "multiset_prime_factorization n = Abs_multiset f"
    apply (unfold multiset_prime_factorization_def)
    apply (subst if_P, assumption)
    apply (rule the1_equality)
    apply (rule ex_ex1I)
    apply (rule multiset_prime_factorization_exists, assumption)
    apply (rule multiset_prime_factorization_unique)
    apply force
    apply force
    apply force
    using assms
    apply (simp add: Abs_multiset_inverse set_of_def msetprod_multiplicity)
    done
  with `f \<in> multiset` have "count (multiset_prime_factorization n) = f"
    by (simp add: Abs_multiset_inverse)
  with S_eq show ?thesis
    by (simp add: set_of_def multiset_def prime_factors_nat_def multiplicity_nat_def)
qed

lemma prime_factors_characterization_nat: "S = {p. 0 < f (p::nat)} \<Longrightarrow> 
    finite S \<Longrightarrow> (ALL p:S. prime p) \<Longrightarrow> n = (PROD p:S. p ^ f p) \<Longrightarrow>
      prime_factors n = S"
  apply (rule prime_factorization_unique_nat [THEN conjunct1, symmetric])
  apply assumption+
  done

lemma prime_factors_characterization'_nat: 
  "finite {p. 0 < f (p::nat)} \<Longrightarrow>
    (ALL p. 0 < f p \<longrightarrow> prime p) \<Longrightarrow>
      prime_factors (PROD p | 0 < f p . p ^ f p) = {p. 0 < f p}"
  apply (rule prime_factors_characterization_nat)
  apply auto
  done

(* A minor glitch:*)

thm prime_factors_characterization'_nat 
    [where f = "%x. f (int (x::nat))", 
      transferred direction: nat "op <= (0::int)", rule_format]

(*
  Transfer isn't smart enough to know that the "0 < f p" should 
  remain a comparison between nats. But the transfer still works. 
*)

lemma primes_characterization'_int [rule_format]: 
    "finite {p. p >= 0 & 0 < f (p::int)} \<Longrightarrow>
      (ALL p. 0 < f p \<longrightarrow> prime p) \<Longrightarrow>
        prime_factors (PROD p | p >=0 & 0 < f p . p ^ f p) = 
          {p. p >= 0 & 0 < f p}"

  apply (insert prime_factors_characterization'_nat 
    [where f = "%x. f (int (x::nat))", 
    transferred direction: nat "op <= (0::int)"])
  apply auto
  done

declare [[simproc del: finite_Collect]]
lemma prime_factors_characterization_int: "S = {p. 0 < f (p::int)} \<Longrightarrow> 
    finite S \<Longrightarrow> (ALL p:S. prime p) \<Longrightarrow> n = (PROD p:S. p ^ f p) \<Longrightarrow>
      prime_factors n = S"
  apply simp
  apply (subgoal_tac "{p. 0 < f p} = {p. 0 <= p & 0 < f p}")
  apply (simp only:)
  apply (subst primes_characterization'_int)
  apply auto
  apply (auto simp add: prime_ge_0_int)
  done

lemma multiplicity_characterization_nat: "S = {p. 0 < f (p::nat)} \<Longrightarrow> 
    finite S \<Longrightarrow> (ALL p:S. prime p) \<Longrightarrow> n = (PROD p:S. p ^ f p) \<Longrightarrow>
      multiplicity p n = f p"
  apply (frule prime_factorization_unique_nat [THEN conjunct2, rule_format, symmetric])
  apply auto
  done

lemma multiplicity_characterization'_nat: "finite {p. 0 < f (p::nat)} \<longrightarrow>
    (ALL p. 0 < f p \<longrightarrow> prime p) \<longrightarrow>
      multiplicity p (PROD p | 0 < f p . p ^ f p) = f p"
  apply (intro impI)
  apply (rule multiplicity_characterization_nat)
  apply auto
  done

lemma multiplicity_characterization'_int [rule_format]: 
  "finite {p. p >= 0 & 0 < f (p::int)} \<Longrightarrow>
    (ALL p. 0 < f p \<longrightarrow> prime p) \<Longrightarrow> p >= 0 \<Longrightarrow>
      multiplicity p (PROD p | p >= 0 & 0 < f p . p ^ f p) = f p"
  apply (insert multiplicity_characterization'_nat 
    [where f = "%x. f (int (x::nat))", 
      transferred direction: nat "op <= (0::int)", rule_format])
  apply auto
  done

lemma multiplicity_characterization_int: "S = {p. 0 < f (p::int)} \<Longrightarrow> 
    finite S \<Longrightarrow> (ALL p:S. prime p) \<Longrightarrow> n = (PROD p:S. p ^ f p) \<Longrightarrow>
      p >= 0 \<Longrightarrow> multiplicity p n = f p"
  apply simp
  apply (subgoal_tac "{p. 0 < f p} = {p. 0 <= p & 0 < f p}")
  apply (simp only:)
  apply (subst multiplicity_characterization'_int)
  apply auto
  apply (auto simp add: prime_ge_0_int)
  done

lemma multiplicity_zero_nat [simp]: "multiplicity (p::nat) 0 = 0"
  by (simp add: multiplicity_nat_def multiset_prime_factorization_def)

lemma multiplicity_zero_int [simp]: "multiplicity (p::int) 0 = 0"
  by (simp add: multiplicity_int_def) 

lemma multiplicity_one_nat [simp]: "multiplicity p (1::nat) = 0"
  by (subst multiplicity_characterization_nat [where f = "%x. 0"], auto)

lemma multiplicity_one_int [simp]: "multiplicity p (1::int) = 0"
  by (simp add: multiplicity_int_def)

lemma multiplicity_prime_nat [simp]: "prime (p::nat) \<Longrightarrow> multiplicity p p = 1"
  apply (subst multiplicity_characterization_nat [where f = "(%q. if q = p then 1 else 0)"])
  apply auto
  apply (case_tac "x = p")
  apply auto
  done

lemma multiplicity_prime_int [simp]: "prime (p::int) \<Longrightarrow> multiplicity p p = 1"
  unfolding prime_int_def multiplicity_int_def by auto

lemma multiplicity_prime_power_nat [simp]: "prime (p::nat) \<Longrightarrow> multiplicity p (p^n) = n"
  apply (cases "n = 0")
  apply auto
  apply (subst multiplicity_characterization_nat [where f = "(%q. if q = p then n else 0)"])
  apply auto
  apply (case_tac "x = p")
  apply auto
  done

lemma multiplicity_prime_power_int [simp]: "prime (p::int) \<Longrightarrow> multiplicity p (p^n) = n"
  apply (frule prime_ge_0_int)
  apply (auto simp add: prime_int_def multiplicity_int_def nat_power_eq)
  done

lemma multiplicity_nonprime_nat [simp]: "~ prime (p::nat) \<Longrightarrow> multiplicity p n = 0"
  apply (cases "n = 0")
  apply auto
  apply (frule multiset_prime_factorization)
  apply (auto simp add: set_of_def multiplicity_nat_def)
  done

lemma multiplicity_nonprime_int [simp]: "~ prime (p::int) \<Longrightarrow> multiplicity p n = 0"
  unfolding multiplicity_int_def prime_int_def by auto

lemma multiplicity_not_factor_nat [simp]: 
    "p ~: prime_factors (n::nat) \<Longrightarrow> multiplicity p n = 0"
  apply (subst (asm) prime_factors_altdef_nat)
  apply auto
  done

lemma multiplicity_not_factor_int [simp]: 
    "p >= 0 \<Longrightarrow> p ~: prime_factors (n::int) \<Longrightarrow> multiplicity p n = 0"
  apply (subst (asm) prime_factors_altdef_int)
  apply auto
  done

lemma multiplicity_product_aux_nat: "(k::nat) > 0 \<Longrightarrow> l > 0 \<Longrightarrow>
    (prime_factors k) Un (prime_factors l) = prime_factors (k * l) &
    (ALL p. multiplicity p k + multiplicity p l = multiplicity p (k * l))"
  apply (rule prime_factorization_unique_nat)
  apply (simp only: prime_factors_altdef_nat)
  apply auto
  apply (subst power_add)
  apply (subst setprod_timesf)
  apply (rule arg_cong2)back back
  apply (subgoal_tac "prime_factors k Un prime_factors l = prime_factors k Un 
      (prime_factors l - prime_factors k)")
  apply (erule ssubst)
  apply (subst setprod_Un_disjoint)
  apply auto
  apply(simp add: prime_factorization_nat)
  apply (subgoal_tac "prime_factors k Un prime_factors l = prime_factors l Un 
      (prime_factors k - prime_factors l)")
  apply (erule ssubst)
  apply (subst setprod_Un_disjoint)
  apply auto
  apply (subgoal_tac "(\<Prod>p\<in>prime_factors k - prime_factors l. p ^ multiplicity p l) = 
      (\<Prod>p\<in>prime_factors k - prime_factors l. 1)")
  apply (simp add: prime_factorization_nat)
  apply (rule setprod_cong, auto)
  done

(* transfer doesn't have the same problem here with the right 
   choice of rules. *)

lemma multiplicity_product_aux_int: 
  assumes "(k::int) > 0" and "l > 0"
  shows 
    "(prime_factors k) Un (prime_factors l) = prime_factors (k * l) &
    (ALL p >= 0. multiplicity p k + multiplicity p l = multiplicity p (k * l))"
  apply (rule multiplicity_product_aux_nat [transferred, of l k])
  using assms apply auto
  done

lemma prime_factors_product_nat: "(k::nat) > 0 \<Longrightarrow> l > 0 \<Longrightarrow> prime_factors (k * l) = 
    prime_factors k Un prime_factors l"
  by (rule multiplicity_product_aux_nat [THEN conjunct1, symmetric])

lemma prime_factors_product_int: "(k::int) > 0 \<Longrightarrow> l > 0 \<Longrightarrow> prime_factors (k * l) = 
    prime_factors k Un prime_factors l"
  by (rule multiplicity_product_aux_int [THEN conjunct1, symmetric])

lemma multiplicity_product_nat: "(k::nat) > 0 \<Longrightarrow> l > 0 \<Longrightarrow> multiplicity p (k * l) = 
    multiplicity p k + multiplicity p l"
  by (rule multiplicity_product_aux_nat [THEN conjunct2, rule_format, 
      symmetric])

lemma multiplicity_product_int: "(k::int) > 0 \<Longrightarrow> l > 0 \<Longrightarrow> p >= 0 \<Longrightarrow> 
    multiplicity p (k * l) = multiplicity p k + multiplicity p l"
  by (rule multiplicity_product_aux_int [THEN conjunct2, rule_format, 
      symmetric])

lemma multiplicity_setprod_nat: "finite S \<Longrightarrow> (ALL x : S. f x > 0) \<Longrightarrow> 
    multiplicity (p::nat) (PROD x : S. f x) = 
      (SUM x : S. multiplicity p (f x))"
  apply (induct set: finite)
  apply auto
  apply (subst multiplicity_product_nat)
  apply auto
  done

(* Transfer is delicate here for two reasons: first, because there is
   an implicit quantifier over functions (f), and, second, because the 
   product over the multiplicity should not be translated to an integer 
   product.

   The way to handle the first is to use quantifier rules for functions.
   The way to handle the second is to turn off the offending rule.
*)

lemma transfer_nat_int_sum_prod_closure3:
  "(SUM x : A. int (f x)) >= 0"
  "(PROD x : A. int (f x)) >= 0"
  apply (rule setsum_nonneg, auto)
  apply (rule setprod_nonneg, auto)
  done

declare transfer_morphism_nat_int[transfer 
  add return: transfer_nat_int_sum_prod_closure3
  del: transfer_nat_int_sum_prod2 (1)]

lemma multiplicity_setprod_int: "p >= 0 \<Longrightarrow> finite S \<Longrightarrow> 
  (ALL x : S. f x > 0) \<Longrightarrow> 
    multiplicity (p::int) (PROD x : S. f x) = 
      (SUM x : S. multiplicity p (f x))"

  apply (frule multiplicity_setprod_nat
    [where f = "%x. nat(int(nat(f x)))", 
      transferred direction: nat "op <= (0::int)"])
  apply auto
  apply (subst (asm) setprod_cong)
  apply (rule refl)
  apply (rule if_P)
  apply auto
  apply (rule setsum_cong)
  apply auto
  done

declare transfer_morphism_nat_int[transfer 
  add return: transfer_nat_int_sum_prod2 (1)]

lemma multiplicity_prod_prime_powers_nat:
    "finite S \<Longrightarrow> (ALL p : S. prime (p::nat)) \<Longrightarrow>
       multiplicity p (PROD p : S. p ^ f p) = (if p : S then f p else 0)"
  apply (subgoal_tac "(PROD p : S. p ^ f p) = 
      (PROD p : S. p ^ (%x. if x : S then f x else 0) p)")
  apply (erule ssubst)
  apply (subst multiplicity_characterization_nat)
  prefer 5 apply (rule refl)
  apply (rule refl)
  apply auto
  apply (subst setprod_mono_one_right)
  apply assumption
  prefer 3
  apply (rule setprod_cong)
  apply (rule refl)
  apply auto
done

(* Here the issue with transfer is the implicit quantifier over S *)

lemma multiplicity_prod_prime_powers_int:
    "(p::int) >= 0 \<Longrightarrow> finite S \<Longrightarrow> (ALL p : S. prime p) \<Longrightarrow>
       multiplicity p (PROD p : S. p ^ f p) = (if p : S then f p else 0)"
  apply (subgoal_tac "int ` nat ` S = S")
  apply (frule multiplicity_prod_prime_powers_nat [where f = "%x. f(int x)" 
    and S = "nat ` S", transferred])
  apply auto
  apply (metis prime_int_def)
  apply (metis prime_ge_0_int)
  apply (metis nat_set_def prime_ge_0_int transfer_nat_int_set_return_embed)
  done

lemma multiplicity_distinct_prime_power_nat: "prime (p::nat) \<Longrightarrow> prime q \<Longrightarrow>
    p ~= q \<Longrightarrow> multiplicity p (q^n) = 0"
  apply (subgoal_tac "q^n = setprod (%x. x^n) {q}")
  apply (erule ssubst)
  apply (subst multiplicity_prod_prime_powers_nat)
  apply auto
  done

lemma multiplicity_distinct_prime_power_int: "prime (p::int) \<Longrightarrow> prime q \<Longrightarrow>
    p ~= q \<Longrightarrow> multiplicity p (q^n) = 0"
  apply (frule prime_ge_0_int [of q])
  apply (frule multiplicity_distinct_prime_power_nat [transferred leaving: n]) 
  prefer 4
  apply assumption
  apply auto
  done

lemma dvd_multiplicity_nat:
    "(0::nat) < y \<Longrightarrow> x dvd y \<Longrightarrow> multiplicity p x <= multiplicity p y"
  apply (cases "x = 0")
  apply (auto simp add: dvd_def multiplicity_product_nat)
  done

lemma dvd_multiplicity_int: 
    "(0::int) < y \<Longrightarrow> 0 <= x \<Longrightarrow> x dvd y \<Longrightarrow> p >= 0 \<Longrightarrow> 
      multiplicity p x <= multiplicity p y"
  apply (cases "x = 0")
  apply (auto simp add: dvd_def)
  apply (subgoal_tac "0 < k")
  apply (auto simp add: multiplicity_product_int)
  apply (erule zero_less_mult_pos)
  apply arith
  done

lemma dvd_prime_factors_nat [intro]:
    "0 < (y::nat) \<Longrightarrow> x dvd y \<Longrightarrow> prime_factors x <= prime_factors y"
  apply (simp only: prime_factors_altdef_nat)
  apply auto
  apply (metis dvd_multiplicity_nat le_0_eq neq_zero_eq_gt_zero_nat)
  done

lemma dvd_prime_factors_int [intro]:
    "0 < (y::int) \<Longrightarrow> 0 <= x \<Longrightarrow> x dvd y \<Longrightarrow> prime_factors x <= prime_factors y"
  apply (auto simp add: prime_factors_altdef_int)
  apply (metis dvd_multiplicity_int le_0_eq neq_zero_eq_gt_zero_nat)
  done

lemma multiplicity_dvd_nat: "0 < (x::nat) \<Longrightarrow> 0 < y \<Longrightarrow> 
    ALL p. multiplicity p x <= multiplicity p y \<Longrightarrow> x dvd y"
  apply (subst prime_factorization_nat [of x], assumption)
  apply (subst prime_factorization_nat [of y], assumption)
  apply (rule setprod_dvd_setprod_subset2)
  apply force
  apply (subst prime_factors_altdef_nat)+
  apply auto
  apply (metis gr0I le_0_eq less_not_refl)
  apply (metis le_imp_power_dvd)
  done

lemma multiplicity_dvd_int: "0 < (x::int) \<Longrightarrow> 0 < y \<Longrightarrow> 
    ALL p >= 0. multiplicity p x <= multiplicity p y \<Longrightarrow> x dvd y"
  apply (subst prime_factorization_int [of x], assumption)
  apply (subst prime_factorization_int [of y], assumption)
  apply (rule setprod_dvd_setprod_subset2)
  apply force
  apply (subst prime_factors_altdef_int)+
  apply auto
  apply (metis le_imp_power_dvd prime_factors_ge_0_int)
  done

lemma multiplicity_dvd'_nat: "(0::nat) < x \<Longrightarrow> 
    \<forall>p. prime p \<longrightarrow> multiplicity p x \<le> multiplicity p y \<Longrightarrow> x dvd y"
  by (metis gcd_lcm_complete_lattice_nat.top_greatest le_refl multiplicity_dvd_nat
      multiplicity_nonprime_nat neq0_conv)

lemma multiplicity_dvd'_int: "(0::int) < x \<Longrightarrow> 0 <= y \<Longrightarrow>
    \<forall>p. prime p \<longrightarrow> multiplicity p x \<le> multiplicity p y \<Longrightarrow> x dvd y"
  by (metis eq_imp_le gcd_lcm_complete_lattice_nat.top_greatest int_eq_0_conv
      multiplicity_dvd_int multiplicity_nonprime_int nat_int transfer_nat_int_relations(4)
      less_le)

lemma dvd_multiplicity_eq_nat: "0 < (x::nat) \<Longrightarrow> 0 < y \<Longrightarrow>
    (x dvd y) = (ALL p. multiplicity p x <= multiplicity p y)"
  by (auto intro: dvd_multiplicity_nat multiplicity_dvd_nat)

lemma dvd_multiplicity_eq_int: "0 < (x::int) \<Longrightarrow> 0 < y \<Longrightarrow>
    (x dvd y) = (ALL p >= 0. multiplicity p x <= multiplicity p y)"
  by (auto intro: dvd_multiplicity_int multiplicity_dvd_int)

lemma prime_factors_altdef2_nat: "(n::nat) > 0 \<Longrightarrow> 
    (p : prime_factors n) = (prime p & p dvd n)"
  apply (cases "prime p")
  apply auto
  apply (subst prime_factorization_nat [where n = n], assumption)
  apply (rule dvd_trans) 
  apply (rule dvd_power [where x = p and n = "multiplicity p n"])
  apply (subst (asm) prime_factors_altdef_nat, force)
  apply (rule dvd_setprod)
  apply auto
  apply (metis One_nat_def Zero_not_Suc dvd_multiplicity_nat le0 le_antisym multiplicity_not_factor_nat multiplicity_prime_nat)  
  done

lemma prime_factors_altdef2_int: 
  assumes "(n::int) > 0" 
  shows "(p : prime_factors n) = (prime p & p dvd n)"
  apply (cases "p >= 0")
  apply (rule prime_factors_altdef2_nat [transferred])
  using assms apply auto
  apply (auto simp add: prime_ge_0_int prime_factors_ge_0_int)
  done

lemma multiplicity_eq_nat:
  fixes x and y::nat 
  assumes [arith]: "x > 0" "y > 0" and
    mult_eq [simp]: "!!p. prime p \<Longrightarrow> multiplicity p x = multiplicity p y"
  shows "x = y"
  apply (rule dvd_antisym)
  apply (auto intro: multiplicity_dvd'_nat) 
  done

lemma multiplicity_eq_int:
  fixes x and y::int 
  assumes [arith]: "x > 0" "y > 0" and
    mult_eq [simp]: "!!p. prime p \<Longrightarrow> multiplicity p x = multiplicity p y"
  shows "x = y"
  apply (rule dvd_antisym [transferred])
  apply (auto intro: multiplicity_dvd'_int) 
  done


subsection {* An application *}

lemma gcd_eq_nat: 
  assumes pos [arith]: "x > 0" "y > 0"
  shows "gcd (x::nat) y = 
    (PROD p: prime_factors x Un prime_factors y. 
      p ^ (min (multiplicity p x) (multiplicity p y)))"
proof -
  def z == "(PROD p: prime_factors (x::nat) Un prime_factors y. 
      p ^ (min (multiplicity p x) (multiplicity p y)))"
  have [arith]: "z > 0"
    unfolding z_def by (rule setprod_pos_nat, auto)
  have aux: "!!p. prime p \<Longrightarrow> multiplicity p z = 
      min (multiplicity p x) (multiplicity p y)"
    unfolding z_def
    apply (subst multiplicity_prod_prime_powers_nat)
    apply auto
    done
  have "z dvd x" 
    by (intro multiplicity_dvd'_nat, auto simp add: aux)
  moreover have "z dvd y" 
    by (intro multiplicity_dvd'_nat, auto simp add: aux)
  moreover have "ALL w. w dvd x & w dvd y \<longrightarrow> w dvd z"
    apply auto
    apply (case_tac "w = 0", auto)
    apply (erule multiplicity_dvd'_nat)
    apply (auto intro: dvd_multiplicity_nat simp add: aux)
    done
  ultimately have "z = gcd x y"
    by (subst gcd_unique_nat [symmetric], blast)
  then show ?thesis
    unfolding z_def by auto
qed

lemma lcm_eq_nat: 
  assumes pos [arith]: "x > 0" "y > 0"
  shows "lcm (x::nat) y = 
    (PROD p: prime_factors x Un prime_factors y. 
      p ^ (max (multiplicity p x) (multiplicity p y)))"
proof -
  def z == "(PROD p: prime_factors (x::nat) Un prime_factors y. 
      p ^ (max (multiplicity p x) (multiplicity p y)))"
  have [arith]: "z > 0"
    unfolding z_def by (rule setprod_pos_nat, auto)
  have aux: "!!p. prime p \<Longrightarrow> multiplicity p z = 
      max (multiplicity p x) (multiplicity p y)"
    unfolding z_def
    apply (subst multiplicity_prod_prime_powers_nat)
    apply auto
    done
  have "x dvd z" 
    by (intro multiplicity_dvd'_nat, auto simp add: aux)
  moreover have "y dvd z" 
    by (intro multiplicity_dvd'_nat, auto simp add: aux)
  moreover have "ALL w. x dvd w & y dvd w \<longrightarrow> z dvd w"
    apply auto
    apply (case_tac "w = 0", auto)
    apply (rule multiplicity_dvd'_nat)
    apply (auto intro: dvd_multiplicity_nat simp add: aux)
    done
  ultimately have "z = lcm x y"
    by (subst lcm_unique_nat [symmetric], blast)
  then show ?thesis
    unfolding z_def by auto
qed

lemma multiplicity_gcd_nat: 
  assumes [arith]: "x > 0" "y > 0"
  shows "multiplicity (p::nat) (gcd x y) = min (multiplicity p x) (multiplicity p y)"
  apply (subst gcd_eq_nat)
  apply auto
  apply (subst multiplicity_prod_prime_powers_nat)
  apply auto
  done

lemma multiplicity_lcm_nat: 
  assumes [arith]: "x > 0" "y > 0"
  shows "multiplicity (p::nat) (lcm x y) = max (multiplicity p x) (multiplicity p y)"
  apply (subst lcm_eq_nat)
  apply auto
  apply (subst multiplicity_prod_prime_powers_nat)
  apply auto
  done

lemma gcd_lcm_distrib_nat: "gcd (x::nat) (lcm y z) = lcm (gcd x y) (gcd x z)"
  apply (cases "x = 0 | y = 0 | z = 0") 
  apply auto
  apply (rule multiplicity_eq_nat)
  apply (auto simp add: multiplicity_gcd_nat multiplicity_lcm_nat lcm_pos_nat)
  done

lemma gcd_lcm_distrib_int: "gcd (x::int) (lcm y z) = lcm (gcd x y) (gcd x z)"
  apply (subst (1 2 3) gcd_abs_int)
  apply (subst lcm_abs_int)
  apply (subst (2) abs_of_nonneg)
  apply force
  apply (rule gcd_lcm_distrib_nat [transferred])
  apply auto
  done

declare [[simproc add: finite_Collect]]

end

