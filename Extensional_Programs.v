(**********************************************************************)
(* This program is free software; you can redistribute it and/or      *)
(* modify it under the terms of the GNU Lesser General Public License *)
(* as published by the Free Software Foundation; either version 2.1   *)
(* of the License, or (at your option) any later version.             *)
(*                                                                    *)
(* This program is distributed in the hope that it will be useful,    *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of     *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the      *)
(* GNU General Public License for more details.                       *)
(*                                                                    *)
(* You should have received a copy of the GNU Lesser General Public   *)
(* License along with this program; if not, write to the Free         *)
(* Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA *)
(* 02110-1301 USA                                                     *)
(**********************************************************************)

(**********************************************************************)
(*            Reflective Programming in Tree Calculus                 *)
(*               Chapter 4: Extensional Programs                      *)
(*                                                                    *)
(*                     Barry Jay                                      *)
(*                                                                    *)
(**********************************************************************)


Require Import Arith Lia Bool List String.
Require Import Reflective.Tree_Calculus.

Set Default Proof Using "Type".


(* 4.2 Combinations versus Terms *)

Inductive combination : Tree -> Prop :=
| is_Node : combination △
| is_App : forall M N, combination M -> combination N -> combination (M@ N)
.
Hint Constructors combination : TreeHintDb.

Ltac combination_tac := inv1 combination; subst; repeat (apply is_App || apply is_Node). 

Lemma programs_are_combinations: forall M, program M -> combination M.
Proof.
  induction M; intro pr; inversion pr; auto_t; subst;  eapply is_App; auto; 
  apply IHM1; inversion pr; now apply pr_stem. 
Qed. 

Hint Resolve programs_are_combinations : TreeHintDb.

Fixpoint substitute M x N :=
  match M with
  | Ref y => if eqb x y then N else Ref y
  | △ => △
  | App M1 M2 => App (substitute M1 x N) (substitute M2 x N)
end. 



Lemma substitute_combination: forall M x N, combination M -> substitute M x N = M.
Proof. induction M;intros x N c; inversion c; subst; simpl; auto; rewrite IHM1; rewrite ? IHM2; auto. Qed. 


Ltac subst_tac := unfold_op;  repeat (unfold substitute; fold substitute;  unfold eqb, Ascii.eqb, Bool.eqb).


(* 4.3 Variable Binding *) 
       
Fixpoint bracket x M := 
match M with 
| Ref y =>  if eqb x y then Id else (K@ (Ref y))
| △ => K@ △ 
| App M1 M2 => d (bracket x M2) @ (bracket x M1)
end
.

(* never used, just for show *) 
Theorem bracket_beta: forall M x N, (bracket x M) @ N = substitute M x N.
Proof.  induction M; intros; simpl; [ caseEq (x=?s) | | rewrite <- IHM1; rewrite <- IHM2]; tree_eq. Qed.



Fixpoint occurs x M :=
  match M with
  | Ref y => eqb x y 
  | △ => false
  | M1 @ M2 => (occurs x M1) || (occurs x M2)
  end.

Lemma occurs_combination: forall M x,  combination M -> occurs x M = false.
Proof. induction M; intros x c; inversion c; subst; simpl; auto; rewrite IHM1; rewrite ? IHM2; auto. Qed. 


Lemma substitute_occurs_false: forall M x N, occurs x M = false -> substitute M x N = M. 
Proof.
  induction M; intros x N occ; simpl in *; auto;
    [ rewrite occ; auto
    | rewrite orb_false_iff in *; inversion occ; rewrite IHM1; rewrite ? IHM2; auto]. 
Qed.


Fixpoint star x M :=
  match M with
  | Ref y =>  if eqb x y then Id else (K@ (Ref y))
  | △ => K@ △ 
  | App M1 (Ref y) => if eqb x y
                      then if occurs x M1
                           then d Id @ (star x M1)
                           else M1
                      else  if occurs x M1
                           then d (K@ (Ref y)) @ (star x M1)
                            else K@ (M1 @ (Ref y))
  | App M1 M2 => if occurs x (M1 @ M2)
                 then d (star x M2) @ (star x M1)
                 else K@ (M1 @ M2)
  end. 

Notation "\" := star : tree_scope.

Lemma star_id: forall x, \x (Ref x) = Id.
Proof. intro; unfold star, occurs; rewrite eqb_refl; auto. Qed.


Lemma eta_red: forall M x, occurs x M = false -> \x (M@ (Ref x)) = M.
Proof. intros M x occ; unfold star; fold star; rewrite eqb_refl; rewrite occ; auto. Qed.


Lemma star_occurs_false: forall M x, occurs x M = false -> \x M = K@ M. 
Proof.
  induction M; intros x occ; auto; 
    [ simpl in *;  rewrite occ; auto
    | unfold star; fold star; rewrite occ; simpl in occ;
    rewrite orb_false_iff in occ;  elim occ; intros occ1 occ2;  
    caseEq M2; intros; subst; simpl in *; auto;  rewrite ? occ1; rewrite occ2; auto]. 
Qed.


Lemma star_occurs_true:
  forall M1 M2 x, occurs x (M1@ M2) = true -> M2 <> Ref x ->
                  \x (M1@ M2) = △@ (△@ (\x M2))@ (\x M1).
Proof.
  intros M1 M2 x occ ne; unfold star at 1; fold star;
    rewrite occ; simpl in occ; rewrite orb_true_iff in occ; elim occ; intro occ1; 
      caseEq M2; intros; subst; auto; 
  match goal with
  | H: Ref ?s1 <> Ref ?x1 |- _ => assert(ne1: x1=?s1 = false) by (apply eqb_neq; congruence)
  end; 
  simpl in *; rewrite ne1 in *; auto;  rewrite ? occ1; auto; discriminate.   
Qed.

Lemma star_occurs_twice:
  forall M1 x, occurs x M1 = true -> \x (M1@ (Ref x)) = △@ (△@ Id)@ (\x M1).
Proof. intros M1 x occ; unfold star; fold star; rewrite eqb_refl; rewrite occ; auto. Qed.

Ltac occurstac :=
  unfold_op; unfold occurs; fold occurs; rewrite ? orb_true_r;
  rewrite ? occurs_combination; auto; cbv; auto 1000 with *; fail. 

Ltac startac_true x :=
  rewrite (star_occurs_true _ _ x);
  [
  | occurstac
  | ( (intro; subst; inv1 combination; fail) || (cbv; discriminate))
  ]. 

Ltac startac_twice x := rewrite (star_occurs_twice _ x); [| occurstac ]. 
Ltac startac_false x :=  rewrite (star_occurs_false _ x); [ | occurstac].
Ltac startac_eta x := rewrite eta_red; [| occurstac ].
Ltac startac x :=
  repeat (startac_false x || startac_true x || startac_twice x || startac_eta x || rewrite star_id).
Ltac starstac1 xs :=
  match xs with
  | nil => eqtac
  | ?x :: ?xs1 => startac x; starstac1 xs1
  end.
Ltac starstac xs := repeat (starstac1 xs).


Lemma star_app_red : forall M N x P, \x (M@N) @ P = \x M @ P @ (\x N @ P).
Proof.
  intros M N x P; unfold star at 1; fold star; caseEq N; intros; unfold d; subst; 
  [
  caseEq (x=? s); intro b;
  [ caseEq (occurs x M); intros;
    [ eqtac;  f_equal; unfold star;  rewrite b;  eqtac; auto
    | f_equal;
      [ rewrite (star_occurs_false _ x); auto;  tree_eq
      | unfold star; rewrite b; tree_eq]]  
  | caseEq (occurs x M); intros; eqtac; f_equal;
    [ unfold star; rewrite b; tree_eq
    | eqtac;   f_equal; rewrite (star_occurs_false _ x); auto; eqtac; auto
    |rewrite (star_occurs_false _ x); auto; eqtac; auto]]
  |
  caseEq (occurs x (M@△)); intros; 
    [ unfold star;fold star; eqtac; auto; rewrite star_occurs_false; unfold star;eqtac; auto
    | simpl in *; rewrite orb_false_r in *;auto; rewrite star_occurs_false; auto; tree_eq] 
  |
  caseEq (occurs x (M@(t@t0))); intros; eqtac; f_equal;
    rewrite ! star_occurs_false; tree_eq;  simpl in *; rewrite orb_false_iff in *; tauto
  ].
Qed.

Lemma star_to_bracket : forall M N x, \x M @ N = bracket x M @ N .
Proof. induction M; intros; [ | | rewrite star_app_red; rewrite IHM1; rewrite IHM2 ]; tree_eq. Qed. 

(* never used, just for show *)

Theorem star_beta: forall M x N, App (\x M) N = (substitute M x N).
Proof. intros; rewrite star_to_bracket; now apply bracket_beta. Qed. 



(* 4.4 Fixpoints *) 


Definition ω := Eval cbv in \"w" (\"f" ((Ref "f")@ ((Ref "w")@ (Ref "w")@ (Ref "f")))).
Definition Y :=  ω @ ω. 


Lemma y_red: forall f, Y@f = (f@ (Y@f)).
Proof.  intros; unfold Y; unfold ω at 1; eqtac; auto. Qed.


(* 4.5 Waiting *) 



Definition W_0 := \"x" (\"y" (\"z" ((Ref "x") @ (Ref "y") @ (Ref "z")))).
Definition W := \"x" (\"y" (bracket "z" ((Ref "x") @ (Ref "y") @ (Ref "z")))).


Definition wait M N := d Id @ (d (K@ N) @ (K@ M)).
Definition wait1 M :=
  d
    (d (K @ (K @ M))
       @ (d (d K @ (K @ △)) @ (K @ △))
    )
    @ (K @ (d (△ @ K @ K))).

Lemma wait_red: forall M N P, (wait M N) @ P = M@N@P.
Proof. tree_eq. Qed. 

Lemma wait1_red: forall M N, (wait1 M) @ N  = wait M N. 
Proof. tree_eq. Qed. 

Lemma w_red1 : forall M N, W@M@N = (wait M N).
Proof.   tree_eq. Qed.    

Lemma w_red : forall M N P, W@M@N@P = (M@N@P).
Proof.  tree_eq. Qed.


Definition wait2 M N := d (d (K@ (d (K@N) @(K@M)))
                             @ (d (d K @ (K@ △))
                                  @ (K@ △)))
                          @ (K @ (d Id)). 

Lemma wait2_red : forall M N x y,  wait2 M N @ x @ y = M @ N @ x @ y.
Proof. tree_eq. Qed.

Definition wait2_1 M  := Eval cbv in (substitute (\"n" (wait2 (Ref "m") (Ref "n"))) "m" M).


Lemma wait2_1_red: forall M N, wait2_1 M @ N = wait2 M N.
Proof. tree_eq. Qed. 


Definition wait3_prime:= \"x" (\"t" (bracket "w" (Ref "m" @ Ref "n" @ Ref "z" @ Ref "t" @ Ref "w"))).
(* cannot do parallel substitutions for "m" and "n" so brute force instead *) 

Definition wait3 M N := 
d (K @ (K @ (d(△ @K @K)))) @
       (△ @
        (△ @
         (△ @
          (△ @
           (△ @ (△ @ (K @ (△ @ (△ @ (△ @ (△ @K) @ (K @ △))) @ (K @ △)))) @
            (△ @
             (△ @
              (△ @
               (△ @
                (△ @
                 (△ @
                  (△ @ (△ @ (K @ (△ @ (△ @ (K @ N)) @ (K @ M)))) @
                   (△ @ (△ @ (△ @ (△ @K) @ (K @ △))) @ (K @ △)))) @ 
                 (K @K))) @ (K @ △))) @ (K @ △)))) @ (K @ △))) @ 
        (K @ △)). 

Lemma wait3_red : forall M N x y z, wait3 M N @ x @ y @ z = M @ N @ x @ y @ z.
Proof. tree_eq. Qed.

Definition wait31 M N x :=
  d (d (K @ (d (K @ x) @ (d (K @ N) @ (K @ M))))
       @ (d (d K @ (K @ △)) @ (K @ △)))
    @ (K @ (d (△ @ K @ K))).


Lemma wait31_red : forall M N x,  wait3 M N @ x = wait31 M N x. 
Proof. tree_eq. Qed. 
  
Definition wait32 M N x y := d Id @ (d (K@ y) @ (d (K @ x) @ (d (K @ N) @ (K @ M)))).

Lemma wait32_red : forall M N x y,  wait3 M N @ x @ y = wait32 M N x y. 
Proof. tree_eq. Qed.


Definition stem x := △ @ (x @ △) @ △ @ K. 

Definition first_d x := stem (first x). 

Definition first_wait3 x :=
  second ((first_d (first_d (first_d (first_d(second (first_d (first_d (second x)))))))) @ △) @ △.

Lemma first_wait3_red: forall M N, first_wait3 (wait3 M N) = M.
Proof.  tree_eq.   Qed. 

Definition wait3_1 M :=
  Eval cbv in
    substitute (\"n" (wait3 (Ref "m") (Ref "n"))) "m" M.


(* 4.6: Fixpoint Functions *)

Definition self_apply := Eval cbv in (\"x" (Ref "x" @ (Ref "x"))). 

Definition Y2 f := wait self_apply (d (wait1 self_apply) @ (K@f)). 


Lemma Y2_program: forall f, program f -> program (Y2 f). 
Proof. intros; program_tac. Qed.


Theorem fixpoint_function : forall f x, Y2 f @ x = f@ (Y2 f) @ x.
Proof. tree_eq. Qed.


Definition Y2_red := fixpoint_function.

Definition swap f := d (K @ f) @ (d (d K @ (K @ △)) @ (K @ △)).

Lemma swap_red: forall f x y, swap f @ x @ y = f @ y @ x.
Proof. tree_eq. Qed.

Definition Y2s f := Y2 (swap f).

(* Y3 *)

Definition Y3 f := wait2 self_apply (d (wait2_1 self_apply) @ (K@f)).


Lemma Y3_program: forall f, program f -> program (Y3 f). 
Proof.  intros;  program_tac. Qed.


Theorem Y3_red : forall f x y, Y3 f @ x @ y = f@ (Y3 f) @ x @ y.
Proof.  tree_eq. Qed. 



(* Y4 *)

Definition Y4 f := wait3 self_apply (d (wait3_1 self_apply) @ (K@f)).


Lemma Y4_program: forall f, program f -> program (Y3 f). 
Proof.  intros;  program_tac. Qed.


Theorem Y4_red : forall f x y z, Y4 f @ x @ y @ z = f@ (Y4 f) @ x @ y @ z.
Proof.  tree_eq. Qed. 






(* 4.7: Arithmetic *)
 

Definition plus :=
  Y3 (\"p"
           (\"m"
                 (△@ (Ref "m") @ Id @
                   (K@ (\"m1" (\"n" (K@ ((Ref "p") @ (Ref "m1") @ (Ref "n"))))))
           ))).


Lemma plus_zero: forall n, plus @ zero @ n = n.
Proof. tree_eq. Qed.


Lemma plus_successor:
  forall m n,  plus @ (successor @ m) @ n = successor @ (plus @ m @ n).
Proof. tree_eq. Qed.


(* mu-recursive functions *) 

Inductive recfun : Set :=
| Zero_fn : recfun
| Succ_fn : recfun 
| Proj_fn: nat -> nat -> recfun 
| Compose_fn : recfun -> list recfun -> recfun
| Primrec : recfun -> recfun -> recfun
| Minrec : recfun -> recfun
.

Fixpoint rf_size f :=
  match f with
| Zero_fn => 1 
| Succ_fn => 1 
| Proj_fn _ _ => 1 
| Compose_fn g hs => fold_left (fun n h => n + rf_size h) hs (S (rf_size g))
| Primrec g h => rf_size g + rf_size h 
| Minrec g => S (rf_size g)
end.
    
Lemma rf_size_positive: forall f, rf_size f > 0.
Proof.
  induction f; simpl; auto; try lia. 
  assert(p: forall l n, fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l n >= n ). clear. 
  induction l; intro n; simpl; auto; try lia. 
  match goal with | r: recfun |- _ =>  elim(IHl (n + rf_size r)); auto; lia end. 
  assert(fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l (S (rf_size f)) >= S (rf_size f))
    by apply p;  lia.
Qed. 


Definition zero_t := △ .
Definition succ_t := K.

Definition tree_map f :=
  Y2
    (\"map"
       (\"xs"
          (△
             @ (Ref "xs")
             @ △
             @ (\"x"
                  (\"xs1"
                     (△ @ (f@ (Ref "x")) @ (Ref "map" @ (Ref "xs1")))
    ))))).


Definition first_c := \"x" (△ @ (Ref "x") @ △ @ K).
Definition second_c := \"x" (△ @ (Ref "x") @ △ @ KI).
Fixpoint proj i :=
  match i with
  | 0 => first_c
  | S i => △ @ (△ @ second_c) @ (K@(proj i))
  end.


Definition rf_primrec g h := 
    Y2
      (\"f"
         (\"xs"
            (△
               @ (Ref "xs")
               @ zero_t
               @ (\"x0"
                    (\"xs1"
                       (△
                          @ (Ref "x0")
                          @ (g@ (Ref "xs1"))
                          @ (K@
                              (\"x1"
                                 (h
                                    @ (△
                                         @ ((Ref "f") @ (△ @ (Ref "x1") @ (Ref "xs1")))
                                         @ (△ @ (Ref "x1") @ (Ref "xs1"))
      )))))))))).

Lemma rf_primrec_combination: forall g h, combination g -> combination h -> combination (rf_primrec g h).
Proof. 
  intros; unfold rf_primrec.
  starstac ("x1" :: "xs1" :: "x0" :: "xs" :: "f" :: nil); now combination_tac.
Qed.


Fixpoint rf_to_tree rf :=
  match rf with
  | Zero_fn => K@ zero_t (* zero discards its tuple of arguments *) 
  | Succ_fn =>  △ @ (△ @ first_c) @ (K@ succ_t) (* succ acts on the first argument *) 
  | Proj_fn i _ =>  proj i (* proj i gets the ith argument *) 
  | Compose_fn f gs =>
    \"x" ((rf_to_tree f) @ (fold_right (fun g f => △ @ ((rf_to_tree g) @ (Ref "x")) @ f)
                                           △ gs))
  | Primrec g h => rf_primrec (rf_to_tree g) (rf_to_tree h)
  | Minrec g =>
    Y2
      (\"f"
         (\"args"
            (isLeaf
               @ ((rf_to_tree g) @ (Ref "args"))
               @ (first (Ref "args"))
               @ (△
                    @ (Ref "args")
                    @ zero_t
                    @ (\"arg0" (\"xs1" ((Ref "f") @ (△ @ (K@ (Ref "arg0")) @ (Ref "xs1")))))
                    ))))
            
  end.


Lemma rf_combination0:
  forall k,
  (forall fs,  fold_left (fun n h => n + rf_size h) fs 0  < k -> 
                combination (star "x" (fold_right (fun (g : recfun) (f0 : Tree) =>
                                                 △ @ (rf_to_tree g @ Ref "x") @ f0) △ fs))) /\
  (forall f, rf_size f < S k -> combination (rf_to_tree f)). 
Proof.
  induction k; split. 
  (* 4 *)
  intros; lia. 
  (* 3 *)
  intro f; assert(rf_size f >0) by apply rf_size_positive; lia.  
  (* 2 *)
  intro fs; caseEq fs; intros; subst; auto.
  (* 3 *)
  simpl;  cbv; now combination_tac. 
  (* 2 *)
  assert(fp: forall l n, fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l n =
                     n + fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l 0).
   clear.
   induction l; intros; simpl; auto. rewrite IHl.
   match goal with r: recfun |- _ => rewrite (IHl (rf_size r)); lia end. 
   (* 2 *)
   unfold fold_right; fold fold_right. 
   rewrite star_occurs_true; [ | simpl; rewrite orb_true_r; auto | caseEq l; intros; discriminate]. 
   combination_tac; auto. apply IHk. rewrite fp in *.   simpl in *. rewrite fp in *.
   match goal with | rf : recfun |- _ => assert(rf_size rf >0) by apply rf_size_positive end;  lia.
   assert(combination(rf_to_tree r)). apply IHk.    simpl in *. rewrite fp in *. lia. 
   startac "x". combination_tac; auto.     
    (* 1 *)
    assert(occ: forall n x, occurs x (Nat.iter n (fun z : Tree => second z) (Ref x)) = true). 
    clear.
    induction n; intros; simpl; auto. apply eqb_refl. now (rewrite IHn).
    intros f r.
    assert(fp: forall l n, fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l n =
                           n + fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l 0).
   clear.
   induction l; intros; simpl; auto. rewrite IHl.
   match goal with | r: recfun |- _ => rewrite (IHl (rf_size r)); lia end.
   caseEq f; intros; subst. 
   (* 6 *)
   1,2: cbv; combination_tac.
   (* 4 *)
   clear; simpl. induction n; intros; simpl; now combination_tac. 
   (* 3 *)
   subst.
   match goal with | r: recfun |- _ =>  assert(combination (rf_to_tree r)) end.  apply IHk.
   simpl in *. rewrite fp in *. rewrite fp in *.  lia. 
   unfold rf_to_tree; fold rf_to_tree.
   match goal with |- combination (\"x" ?b) => caseEq (occurs "x" b); intro occ1 end.
   rewrite star_occurs_true. 
   repeat (apply is_App; auto_t).
   apply IHk. 
   simpl in *.
   assert (fl: forall l m, fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l m =
                       fold_left (fun (n : nat) (h : recfun) => n + rf_size h) l 0 + m).
   clear. induction l; intros; simpl; auto; rewrite IHl; rewrite (IHl (rf_size a)); lia. 
   rewrite fl in *. 
   match goal with r: recfun |- _ =>    assert(rf_size r >0) by apply rf_size_positive end.    lia.
   startac "x"; now combination_tac. auto.  
   simpl. caseEq l; intros; discriminate.
   rewrite star_occurs_false. 2: auto.  combination_tac; auto. 
   caseEq l; intros; subst; simpl in *; auto_t. rewrite ! orb_true_r in *; discriminate.
   (* 2 *)
   subst. unfold rf_to_tree; fold rf_to_tree. unfold Y2, wait. combination_tac.
      match goal with
      | H : rf_size _ < _ , r1 : recfun, r0: recfun |- _ =>
        simpl in H;  
          assert(rf_size r1>0) by apply rf_size_positive; 
          assert(rf_size r0>0) by apply rf_size_positive; 
          assert(combination (rf_to_tree r1)) by  (eapply IHk;  lia); 
          assert(combination (rf_to_tree r0)) by (eapply IHk; lia)
      end.
      starstac ("x1" :: "xs1" :: "x0" :: "xs" :: "f" :: nil); combination_tac; auto.
   (* 1 *)
   subst; match goal with | H : rf_size (Minrec ?r) < _ |- _ =>
                            unfold rf_size in H; fold rf_size in H; 
                              assert(combination (rf_to_tree r)) by (apply IHk; auto; lia) end.
   unfold rf_to_tree; fold rf_to_tree.  unfold Y2, wait, isLeaf, query, first. combination_tac.
   starstac ("xs1" :: "arg0" :: "args":: "f" :: nil); combination_tac; auto. 
 Qed.

Lemma rf_combination: forall f, combination (rf_to_tree f).
Proof.  intros. eapply rf_combination0; auto. Qed.

Hint Resolve rf_combination : TreeHintDb. 


Lemma rf_combination_aux : forall g,   combination
    (\"f"
       (\"args"
          (isLeaf @ (rf_to_tree g @ Ref "args") @ first (Ref "args") @
           (△ @ Ref "args" @ zero_t @
            \"arg0" (\"xs1" (Ref "f" @ (△ @ (K @ Ref "arg0") @ Ref "xs1")))))))
.
Proof. 
  intros; unfold first; unfold_op; starstac ("xs1" :: "arg0" :: "args" :: "f" :: nil); combination_tac;
    auto_t. 
Qed.

Lemma rf_combination_Y2:
  forall g, combination (Y2
       (\"f"
          (\"args"
             (isLeaf @ (rf_to_tree g @ Ref "args") @ first (Ref "args") @
                     (△ @ Ref "args" @ zero_t @ \"arg0" (\"xs1" (Ref "f" @ (△ @ (K @ Ref "arg0") @ Ref "xs1")))))))).
Proof.  intros; unfold Y2, wait; combination_tac; apply rf_combination_aux. Qed.



Inductive pr_eval : recfun -> recfun -> Prop :=
| p_pr : forall xs1 x xs2, pr_eval (Compose_fn (Proj_fn (List.length xs1) (List.length xs2))
                                                  (xs1 ++ (x:: xs2))) x
| c_pr : forall f gs xs, pr_eval (Compose_fn (Compose_fn f gs) xs)
                                     (Compose_fn f (map (fun g => Compose_fn g xs) gs))
| prec_pr_z : forall g h xs,  pr_eval (Compose_fn (Primrec g h) (Zero_fn :: xs))
                                      (Compose_fn g xs)
| prec_pr_s : forall g h x xs,  pr_eval (Compose_fn (Primrec g h) ((Compose_fn Succ_fn (x:: nil)) :: xs))
                                         (Compose_fn h ((Compose_fn (Primrec g h) (x::xs)) :: 
                                                     (x:: xs)))
| min_pr_z : forall g x xs, pr_eval (Compose_fn g (x::xs)) Zero_fn ->
                            pr_eval (Compose_fn (Minrec g) (x::xs)) x 
| min_pr_s: forall g x xs y, pr_eval (Compose_fn g (x::xs)) (Compose_fn Succ_fn (y:: nil)) ->
                             pr_eval (Compose_fn (Minrec g) (x::xs))
                                     (Compose_fn (Minrec g) ((Compose_fn Succ_fn (x:: nil)) :: xs)).


Lemma aux: forall n f (x:Tree), Nat.iter (S n) f x = f (Nat.iter n f x).
Proof.  induction n; intros; simpl; auto. Qed.

Lemma proj_program: forall i, program (proj i).
Proof.  induction i; intros; program_tac.  Qed.

  
Lemma aux2:  forall xs z, substitute (fold_right  (fun (g : recfun) (f : Tree) => △ @ (rf_to_tree g @ (Ref "x")) @ f) △ xs) "x" z =  fold_right  (fun (g : recfun) (f : Tree) => △ @ (rf_to_tree g @ z) @ f) △ xs.
Proof.
  induction xs; intros; simpl; auto; rewrite ! (substitute_combination (rf_to_tree _)); rewrite ? IHxs; auto_t.
  Qed. 


Lemma minrec_red:
  forall g x xs z, combination z -> 
    rf_to_tree (Compose_fn (Minrec g) (x :: xs)) @ z = 
       (isLeaf @ (rf_to_tree (Compose_fn g (x :: xs)) @ z) @ (rf_to_tree x @ z) @
               (rf_to_tree (Compose_fn (Minrec g) (Compose_fn Succ_fn (x :: nil) :: xs)) @ z)).
Proof.
  intros. unfold rf_to_tree; fold rf_to_tree. unfold first. 
  starstac ("xs1" :: "arg0" :: "args":: "f" :: nil). rewrite Y2_red. eqtac.
  unfold fold_right. starstac ("x" :: nil). f_equal. 
  rewrite star_occurs_true. 2: unfold occurs; rewrite orb_true_r; auto.
  2: clear; induction xs; discriminate. eqtac. starstac ("x" :: nil).
  apply sym_eq.
  rewrite star_occurs_true. 2: unfold occurs; rewrite orb_true_r; auto.
  2: clear; induction xs; discriminate. eqtac. starstac ("x" :: nil). f_equal.
  unfold rf_to_tree; fold rf_to_tree. unfold first_c, succ_t.
  unfold star at 2; unfold occurs; fold occurs; simpl; rewrite ? orb_true_r; unfold orb; simpl; eqtac. 
  rewrite ! occurs_combination. unfold orb, d.  eqtac. f_equal. auto_t. 
  rewrite ! occurs_combination. all: auto_t. 
Qed.


Lemma aux_fold:
  forall xs y x, xs <> nil -> 
    occurs y (fold_right (fun (g0 : recfun) (f : Tree) => △ @ (rf_to_tree g0 @ x) @ f) △ xs)
              = occurs y x.
Proof.
  induction xs; intros y x ne.
  congruence. 
  simpl. rewrite occurs_combination; auto_t. simpl. 
  caseEq xs; intro; subst; intros. 
  (* 2 *)
  intros; apply orb_false_r.
  subst.   rewrite IHxs. 2: discriminate.
  caseEq (occurs y x); now intros.
Qed.

Lemma occurs_bracket_same: forall M x, occurs x (bracket x M) = false.
Proof.
  induction M; intro x; intros; simpl;
    [caseEq (x=? s); intro b; intros | | rewrite IHM1; rewrite IHM2]; auto.
Qed. 

Lemma aux3 :
  forall xs z,
    combination z ->
    bracket "x" (fold_right (fun (g : recfun) (f0 : Tree) => △ @ (rf_to_tree g @ Ref "x") @ f0) △ xs) @ z =
           fold_right (fun (g : recfun) (f0 : Tree) => △ @ (rf_to_tree g @ z) @ f0) △ xs. 
Proof.
  induction xs; intro z; intros; unfold d; eqtac; simpl; auto.
  eqtac; auto.
  unfold d; eqtac. rewrite <- star_to_bracket.
  rewrite star_occurs_false.  2: simpl; rewrite occurs_combination; auto; apply rf_combination. eqtac.
  rewrite IHxs; auto.   
Qed.  
       
Theorem rf_to_tree_preserves_eval:
  forall x y, pr_eval x y ->
              forall z, combination z -> rf_to_tree x @ z = rf_to_tree y @z.
Proof.
  intros x y e; induction e; intros z c.
  (* 6 *)
  unfold rf_to_tree; fold rf_to_tree.
  rewrite star_to_bracket.  unfold bracket, d; fold bracket. eqtac. rewrite <- ! star_to_bracket.
  rewrite star_occurs_false. 2: clear; induction xs1; intros; auto. eqtac. 
  induction xs1; intros. unfold Datatypes.length, proj, first_c. starstac ("x" :: nil).
  unfold app, fold_right. rewrite star_occurs_true. 2: unfold occurs; rewrite orb_true_r; auto.
  2: clear; induction xs2; intros; auto. eqtac. starstac ("x" :: nil); auto; discriminate. discriminate. 
  discriminate.
  replace (Datatypes.length (a :: xs1)) with (S (Datatypes.length xs1)) by auto. 
  unfold proj; fold proj. unfold second_c. starstac ("x" :: nil).
  rewrite <- app_comm_cons. unfold fold_right.
  rewrite star_occurs_true. 2: unfold occurs; rewrite orb_true_r; auto.
  2: clear; induction xs1; intros; auto. eqtac. starstac ("x" :: nil). auto.
   discriminate. discriminate. 
  (* 5 *) 
  unfold rf_to_tree; fold rf_to_tree.
  rewrite ! star_to_bracket. unfold bracket, d; fold bracket. eqtac. rewrite <- ! star_to_bracket.
  rewrite star_occurs_false.  2: apply occurs_bracket_same. eqtac. rewrite <- ! star_to_bracket.
  rewrite star_occurs_false.  2: rewrite occurs_combination; auto; apply rf_combination. eqtac.
  rewrite star_occurs_false.  2: apply occurs_bracket_same. eqtac. rewrite <- ! star_to_bracket.
  f_equal.  
  rewrite ! star_to_bracket.  rewrite ! aux3; auto. 
  all: cycle 1.
  induction xs; intros; simpl; auto; unfold d; eqtac; auto_t.
  rewrite <- star_to_bracket.
  rewrite star_occurs_false.  2: rewrite occurs_combination; auto; apply rf_combination. eqtac.
  combination_tac; auto. now apply rf_combination. inv1 combination. 
  all: cycle -1.
  induction gs; intros.
  simpl; eqtac; auto.
  unfold map; fold map; unfold fold_right in *.
  f_equal.
  unfold rf_to_tree; fold rf_to_tree. 
  rewrite star_to_bracket. unfold bracket, d; fold bracket. eqtac.
  rewrite <- ! star_to_bracket.
  rewrite ! (star_occurs_false (rf_to_tree _)).
  2: rewrite occurs_combination; auto; apply rf_combination. eqtac. 
  f_equal. f_equal. rewrite star_to_bracket.
  clear - c.   induction xs; intros; simpl; unfold d; eqtac; auto.
  rewrite <- star_to_bracket.
  rewrite ! (star_occurs_false (rf_to_tree _)).
  2: rewrite occurs_combination; auto; apply rf_combination. eqtac. 
  f_equal. apply IHxs. rewrite IHgs. f_equal.
  (* 4 *)
  unfold rf_to_tree; fold rf_to_tree.
  rewrite ! star_to_bracket. unfold bracket, d; fold bracket. eqtac. rewrite <- ! star_to_bracket.
  rewrite star_occurs_false.  2: rewrite occurs_combination; auto; apply rf_primrec_combination. eqtac.
  rewrite (star_occurs_false (rf_to_tree _)).
  2: rewrite occurs_combination; auto; apply rf_combination. eqtac.
  rewrite ! star_to_bracket. rewrite ! aux3; auto. 
  unfold fold_right, rf_primrec, rf_to_tree; fold rf_to_tree. eqtac. 
  rewrite Y2_red.
  starstac ("x1" :: "xs1" :: "x0" :: "xs" :: "f" :: nil). auto. 1,2: apply rf_combination.
  (* 3 *)
  unfold rf_to_tree; fold rf_to_tree.
  rewrite ! star_to_bracket. unfold bracket, d; fold bracket. eqtac. rewrite <- ! star_to_bracket.
  rewrite star_occurs_false.  2: rewrite occurs_combination; auto; apply rf_primrec_combination; auto. eqtac.
  rewrite (star_occurs_false (rf_to_tree _)).
  2: rewrite occurs_combination; auto; apply rf_combination. eqtac.
  rewrite ! star_to_bracket. rewrite ! aux3; auto. 
  unfold fold_right, rf_primrec, rf_to_tree; fold rf_to_tree. eqtac. 
  rewrite Y2_red. 
  replace (Y2
       (\"f"
          (\"xs"
             (△ @ Ref "xs" @ zero_t @
              \"x0"
                (\"xs1"
                   (△ @ Ref "x0" @ (rf_to_tree g @ Ref "xs1") @
                    (△ @ △ @
                     \"x1"
                       (rf_to_tree h @
                                   (△ @ (Ref "f" @ (△ @ Ref "x1" @ Ref "xs1")) @ (△ @ Ref "x1" @ Ref "xs1"))))))))))
    with  (rf_primrec (rf_to_tree g) (rf_to_tree h)) by auto. 
  starstac ("x1" :: "xs1" :: "x0" :: "xs" :: "f" :: nil).
  unfold succ_t, first_c.
  rewrite ! star_to_bracket. unfold_op; unfold bracket, d; fold bracket. eqtac.
  subst_tac.  unfold_op; unfold bracket, d; fold bracket. eqtac. rewrite ! aux3; auto.
  rewrite <- ! star_to_bracket.
  rewrite star_occurs_false.  2: rewrite occurs_combination; auto; apply rf_primrec_combination. eqtac.
  unfold fold_right. eqtac. f_equal.
  1-4: apply rf_combination.
  (* 2 *)
  1,2: rewrite minrec_red. 
  rewrite IHe. 
  unfold rf_to_tree; fold rf_to_tree. eqtac. replace (isLeaf @ zero_t) with K by tree_eq. 
  unfold d; eqtac.  all: auto.
  (* 1 *)
  rewrite IHe; auto.
  unfold rf_to_tree; fold rf_to_tree. eqtac.
  rewrite ! star_to_bracket.  unfold succ_t, first_c. unfold_op.  unfold bracket; fold bracket. 
  subst_tac.  unfold bracket, d; fold bracket. eqtac. 
  rewrite <- star_to_bracket. f_equal. 
Qed.


(* 4.8: Lists and Strings *)


Definition t_nil := △. 
Definition t_cons h t := △@ h@ t.
Definition t_head := \"xs" (App (App (△@ (Ref "xs")) (K@ Id)) K).
Definition t_tail := \"xs" (App (App (△@ (Ref "xs")) (K@ Id)) (K@ Id)).


Lemma head_red: forall h t, App t_head (t_cons h t) = h.
Proof. tree_eq. Qed. 
Lemma tail_red: forall h t, App t_tail (t_cons h t) = t.
Proof. tree_eq. Qed. 


(* 4.9: Mapping and Folding *)

Definition list_map :=
  Y3 (\"m"
          (\"f"
                (\"xs"
                      (App (App (△@ (Ref "xs")) t_nil)
                           (\"h" (\"t" (t_cons (App (Ref "f") (Ref "h"))
                                                       (App (App (Ref "m") (Ref "f")) (Ref "t"))
          ))))))).


Lemma map_nil: forall f, App (App list_map f) t_nil = t_nil.
Proof.  intros; unfold list_map; rewrite Y3_red; tree_eq. Qed. 

Lemma map_cons :
  forall f h t, App (App list_map f) (t_cons h t) =
                      (t_cons (App f h) (App (App list_map f) t)).
Proof.  intros; unfold list_map; rewrite Y3_red; tree_eq. Qed.


Definition list_foldleft := 
  Y4 (\"fd"
           (\"f" 
                 (\"x"
                       (\"ys"
                             (App (App (△@ (Ref "ys")) (Ref "x"))
                                  (App (App D (App (Ref "f") (Ref "x"))) (K@ ((Ref "fd") @ (Ref "f"))))
     ))))).


Lemma list_foldleft_nil:
  forall f x, list_foldleft @ f @ x @ t_nil = x. 
Proof.  intros; unfold list_foldleft; rewrite Y4_red; tree_eq. Qed.

Lemma list_foldleft_cons:
  forall f x h t, list_foldleft @ f @ x @ (t_cons h t) = list_foldleft @ f @ (f @ x @ h) @ t. 
Proof.
  intros; unfold list_foldleft; rewrite Y4_red; fold list_foldleft.
  starstac ("ys" :: "x" :: "f" :: "fd" :: nil).  unfold t_cons. eqtac. auto.
Qed.


Definition list_foldright := 
  Y4 (\"fd"
           (\"f" 
                 (\"x"
                       (\"ys"
                             (App (App (△@ (Ref "ys")) (Ref "x"))
                                  (\"h" (\"t" (App (App (Ref "f") (Ref "h"))
                                                           (App (App (App (Ref "fd") (Ref "f"))
                                                                     (Ref "x"))
                                                                (Ref "t")))))))))).



Lemma list_foldright_nil:  forall f x, list_foldright @ f @ x@ t_nil = x.
Proof.
  intros; unfold list_foldright; rewrite Y4_red; fold list_foldright.
  starstac ("t" :: "h" :: "ys" :: "x" :: "f" :: "fd" :: nil).  auto.
Qed. 



Lemma list_foldright_cons:
  forall f x h t, list_foldright @ f @ x @ (t_cons h t) = f @ h @ (list_foldright @ f@ x @ t). 
Proof.
  intros; unfold list_foldright; rewrite Y4_red; fold list_foldright.
  starstac ("t" :: "h" :: "ys" :: "x" :: "f" :: "fd" :: nil).  unfold t_cons; eqtac. auto.
Qed. 


Definition list_append xs ys :=
  list_foldright @ (\"h" (\"t" (t_cons (Ref "h") (Ref "t")))) @ ys @ xs.


Lemma append_nil_r: forall xs, list_append t_nil xs = xs.
Proof. intros. apply list_foldright_nil. Qed. 


(* Exercises *)

(* 1 *)
(* 
Compute W.
    = △ @ (△ @ (K @ (K @ (△ @ (△ @ (△ @K @K)))))) @
       (△ @
        (△ @
         (△ @
          (△ @
           (△ @ (△ @ (K @ (△ @ (△ @ (△ @ (△ @K) @ (K @ △))) @ (K @ △)))) @
            (△ @ (△ @ (△ @ (△ @ (△ @ (△ @K) @ (K @K ))) @ (K @ △))) @ (K @ △)))) @
          (K @ △))) @ (K  @ △))
     : Tree
 *)

(* 2 *)
Definition omega' := bracket "x" (bracket "f" (Ref "f" @ (Ref "x" @ Ref "x" @ Ref "f"))).
(* \and bracket have the same functional behaviour *)

(* 3 *)
(* See Y3_program and Y3_red above *) 

(* 4 *)
(* See Y4_program and Y4_red above *) 

(* 5 *) 

Definition times :=
  Y3 (\"t"
           (\"m"
                 (\"n"
                       (App (App (△@ (Ref "n")) △)
                            (K@ (\"x" (App (App plus (Ref "m"))
                                                    (App (App (Ref "t") (Ref "m")) (Ref "x")))))
     )))).


Lemma times_zero: forall m, App (App times m) zero = zero.
Proof. tree_eq. Qed.


Lemma times_successor:
  forall m n,  App (App times m) (App successor n) =
                      (App (App plus m) (App (App times m) n)).
Proof. tree_eq. Qed. 

(* 6 *)

Definition minus := 
  Y3 (\"p"
           (\"m"
                 (\"n"
                       (App (App (△@ (Ref "n")) (Ref "m"))
                            (K@ (App (Ref "p") (App predecessor (Ref "m")))))
                  ))).

(* 7 *)

Lemma mu_succ_program : program (rf_to_tree (Minrec Succ_fn)).
Proof.  apply Y2_program. program_tac. Qed.

(* Minrec Succ_fn looks for the minimum solution to succ x = 0 but none such exists *) 
