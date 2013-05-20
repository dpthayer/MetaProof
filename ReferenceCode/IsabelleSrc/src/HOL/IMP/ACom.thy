(* Author: Tobias Nipkow *)

theory ACom
imports Com
begin

subsection "Annotated Commands"

datatype 'a acom =
  SKIP 'a                           ("SKIP {_}" 61) |
  Assign vname aexp 'a              ("(_ ::= _/ {_})" [1000, 61, 0] 61) |
  Seq "('a acom)" "('a acom)"       ("_;//_"  [60, 61] 60) |
  If bexp 'a "('a acom)" 'a "('a acom)" 'a
    ("(IF _/ THEN ({_}/ _)/ ELSE ({_}/ _)//{_})"  [0, 0, 0, 61, 0, 0] 61) |
  While 'a bexp 'a "('a acom)" 'a
    ("({_}//WHILE _//DO ({_}//_)//{_})"  [0, 0, 0, 61, 0] 61)

text_raw{*\snip{postdef}{2}{1}{% *}
fun post :: "'a acom \<Rightarrow>'a" where
"post (SKIP {P}) = P" |
"post (x ::= e {P}) = P" |
"post (C\<^isub>1; C\<^isub>2) = post C\<^isub>2" |
"post (IF b THEN {P\<^isub>1} C\<^isub>1 ELSE {P\<^isub>2} C\<^isub>2 {Q}) = Q" |
"post ({I} WHILE b DO {P} C {Q}) = Q"
text_raw{*}%endsnip*}

text_raw{*\snip{stripdef}{1}{1}{% *}
fun strip :: "'a acom \<Rightarrow> com" where
"strip (SKIP {P}) = com.SKIP" |
"strip (x ::= e {P}) = x ::= e" |
"strip (C\<^isub>1;C\<^isub>2) = strip C\<^isub>1; strip C\<^isub>2" |
"strip (IF b THEN {P\<^isub>1} C\<^isub>1 ELSE {P\<^isub>2} C\<^isub>2 {P}) =
  IF b THEN strip C\<^isub>1 ELSE strip C\<^isub>2" |
"strip ({I} WHILE b DO {P} C {Q}) = WHILE b DO strip C"
text_raw{*}%endsnip*}

text_raw{*\snip{annodef}{1}{1}{% *}
fun anno :: "'a \<Rightarrow> com \<Rightarrow> 'a acom" where
"anno A com.SKIP = SKIP {A}" |
"anno A (x ::= e) = x ::= e {A}" |
"anno A (c\<^isub>1;c\<^isub>2) = anno A c\<^isub>1; anno A c\<^isub>2" |
"anno A (IF b THEN c\<^isub>1 ELSE c\<^isub>2) =
  IF b THEN {A} anno A c\<^isub>1 ELSE {A} anno A c\<^isub>2 {A}" |
"anno A (WHILE b DO c) =
  {A} WHILE b DO {A} anno A c {A}"
text_raw{*}%endsnip*}

text_raw{*\snip{annosdef}{1}{1}{% *}
fun annos :: "'a acom \<Rightarrow> 'a list" where
"annos (SKIP {P}) = [P]" |
"annos (x ::= e {P}) = [P]" |
"annos (C\<^isub>1;C\<^isub>2) = annos C\<^isub>1 @ annos C\<^isub>2" |
"annos (IF b THEN {P\<^isub>1} C\<^isub>1 ELSE {P\<^isub>2} C\<^isub>2 {Q}) =
  P\<^isub>1 # P\<^isub>2 # Q # annos C\<^isub>1 @ annos C\<^isub>2" |
"annos ({I} WHILE b DO {P} C {Q}) = I # P # Q # annos C"
text_raw{*}%endsnip*}

text_raw{*\snip{mapacomdef}{1}{2}{% *}
fun map_acom :: "('a \<Rightarrow> 'b) \<Rightarrow> 'a acom \<Rightarrow> 'b acom" where
"map_acom f (SKIP {P}) = SKIP {f P}" |
"map_acom f (x ::= e {P}) = x ::= e {f P}" |
"map_acom f (C\<^isub>1;C\<^isub>2) = map_acom f C\<^isub>1; map_acom f C\<^isub>2" |
"map_acom f (IF b THEN {P\<^isub>1} C\<^isub>1 ELSE {P\<^isub>2} C\<^isub>2 {Q}) =
  IF b THEN {f P\<^isub>1} map_acom f C\<^isub>1 ELSE {f P\<^isub>2} map_acom f C\<^isub>2
  {f Q}" |
"map_acom f ({I} WHILE b DO {P} C {Q}) =
  {f I} WHILE b DO {f P} map_acom f C {f Q}"
text_raw{*}%endsnip*}


lemma post_map_acom[simp]: "post(map_acom f C) = f(post C)"
by (induction C) simp_all

lemma strip_acom[simp]: "strip (map_acom f C) = strip C"
by (induction C) auto

lemma map_acom_SKIP:
 "map_acom f C = SKIP {S'} \<longleftrightarrow> (\<exists>S. C = SKIP {S} \<and> S' = f S)"
by (cases C) auto

lemma map_acom_Assign:
 "map_acom f C = x ::= e {S'} \<longleftrightarrow> (\<exists>S. C = x::=e {S} \<and> S' = f S)"
by (cases C) auto

lemma map_acom_Seq:
 "map_acom f C = C1';C2' \<longleftrightarrow>
 (\<exists>C1 C2. C = C1;C2 \<and> map_acom f C1 = C1' \<and> map_acom f C2 = C2')"
by (cases C) auto

lemma map_acom_If:
 "map_acom f C = IF b THEN {P1'} C1' ELSE {P2'} C2' {Q'} \<longleftrightarrow>
 (\<exists>P1 P2 C1 C2 Q. C = IF b THEN {P1} C1 ELSE {P2} C2 {Q} \<and>
     map_acom f C1 = C1' \<and> map_acom f C2 = C2' \<and> P1' = f P1 \<and> P2' = f P2 \<and> Q' = f Q)"
by (cases C) auto

lemma map_acom_While:
 "map_acom f w = {I'} WHILE b DO {p'} C' {P'} \<longleftrightarrow>
 (\<exists>I p P C. w = {I} WHILE b DO {p} C {P} \<and> map_acom f C = C' \<and> I' = f I \<and> p' = f p \<and> P' = f P)"
by (cases w) auto


lemma strip_anno[simp]: "strip (anno a c) = c"
by(induct c) simp_all

lemma strip_eq_SKIP:
  "strip C = com.SKIP \<longleftrightarrow> (EX P. C = SKIP {P})"
by (cases C) simp_all

lemma strip_eq_Assign:
  "strip C = x::=e \<longleftrightarrow> (EX P. C = x::=e {P})"
by (cases C) simp_all

lemma strip_eq_Seq:
  "strip C = c1;c2 \<longleftrightarrow> (EX C1 C2. C = C1;C2 & strip C1 = c1 & strip C2 = c2)"
by (cases C) simp_all

lemma strip_eq_If:
  "strip C = IF b THEN c1 ELSE c2 \<longleftrightarrow>
  (EX P1 P2 C1 C2 Q. C = IF b THEN {P1} C1 ELSE {P2} C2 {Q} & strip C1 = c1 & strip C2 = c2)"
by (cases C) simp_all

lemma strip_eq_While:
  "strip C = WHILE b DO c1 \<longleftrightarrow>
  (EX I P C1 Q. C = {I} WHILE b DO {P} C1 {Q} & strip C1 = c1)"
by (cases C) simp_all

lemma set_annos_anno[simp]: "set (annos (anno a c)) = {a}"
by(induction c)(auto)

lemma size_annos_same: "strip C1 = strip C2 \<Longrightarrow> size(annos C1) = size(annos C2)"
apply(induct C2 arbitrary: C1)
apply (auto simp: strip_eq_SKIP strip_eq_Assign strip_eq_Seq strip_eq_If strip_eq_While)
done

lemmas size_annos_same2 = eqTrueI[OF size_annos_same]

end
