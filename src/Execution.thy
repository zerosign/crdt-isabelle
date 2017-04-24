section\<open>Model of a distributed system executing some algorithm\<close>

theory
  Execution
imports
  Util
begin

subsection\<open>Non-determinism of users and networks\<close>

type_synonym ('evt, 'state) node = "'evt list \<times> 'state"
type_synonym ('nodeid, 'msg, 'evt, 'state) system = "'msg set \<times> ('nodeid \<Rightarrow> ('evt, 'state) node)"

locale executions =
  fixes initial   :: "'nodeid \<Rightarrow> 'state"
    and valid_msg :: "'nodeid \<Rightarrow> ('evt, 'state) node \<Rightarrow> 'msg set"
    and send_msg  :: "'nodeid \<Rightarrow> ('evt, 'state) node \<Rightarrow> 'msg \<Rightarrow> 'evt list \<times> 'state"
    and recv_msg  :: "'nodeid \<Rightarrow> ('evt, 'state) node \<Rightarrow> 'msg \<Rightarrow> 'evt list \<times> 'state"
  assumes node_exists: "\<exists>node::'nodeid. True"

definition (in executions) send_step ::
  "('nodeid, 'msg, 'evt, 'state) system \<Rightarrow> ('nodeid, 'msg, 'evt, 'state) system" where
  "send_step sys \<equiv>
     let (msgs, nodes) = sys;
         sender = SOME node::'nodeid. True;
         (evts, state) = nodes sender;
         valid = valid_msg sender (nodes sender) in
     if valid \<noteq> {} then
       let msg = SOME msg. msg \<in> valid;
           (evts', state') = send_msg sender (nodes sender) msg in
       (insert msg msgs, nodes(sender := (evts @ evts', state')))
     else sys"

definition (in executions) recv_step ::
  "('nodeid, 'msg, 'evt, 'state) system \<Rightarrow> ('nodeid, 'msg, 'evt, 'state) system" where
  "recv_step sys \<equiv>
     let (msgs, nodes) = sys in
     if msgs \<noteq> {} then
       let msg = SOME msg. msg \<in> msgs;
           recipient = SOME node::'nodeid. True;
           (evts, state) = nodes recipient;
           (evts', state') = recv_msg recipient (nodes recipient) msg in
       (msgs, nodes(recipient := (evts @ evts', state')))
     else sys"

definition (in executions) take_step ::
  "('nodeid, 'msg, 'evt, 'state) system \<Rightarrow> ('nodeid, 'msg, 'evt, 'state) system" where
  "take_step \<equiv> SOME step. step \<in> {send_step, recv_step}"

definition (in executions) initial_conf :: "('nodeid, 'msg, 'evt, 'state) system" where
  "initial_conf \<equiv> ({}, \<lambda>n. ([], initial n))"

inductive (in executions) execution :: "('nodeid, 'msg, 'evt, 'state) system \<Rightarrow> bool" where
  "execution initial_conf" |
  "\<lbrakk> execution conf; take_step conf = conf' \<rbrakk> \<Longrightarrow> execution conf'"


subsection\<open>Reasoning about how the system configuration evolves over time\<close>

definition (in executions) config_evolution ::
  "('nodeid, 'msg, 'evt, 'state) system \<Rightarrow> ('nodeid, 'msg, 'evt, 'state) system list \<Rightarrow> bool" where
  "config_evolution c cs \<equiv>
     cs \<noteq> [] \<and>
     hd cs = initial_conf \<and>
     last cs = c \<and>
     (\<forall>x \<in> set cs. execution x) \<and>
     (\<forall>pre x y suf. cs = pre@x#y#suf \<longrightarrow> send_step x = y \<or> recv_step x = y)"

lemma (in executions) config_evolution_drop_last:
  assumes "config_evolution c2 (confs@[c1,c2])"
  shows "config_evolution c1 (confs@[c1])"
  using assms apply(simp add: config_evolution_def)
  apply(erule conjE)+
  apply(rule conjI)
  apply(simp add: list_head_unaffected)
  apply(metis (no_types, lifting) append.assoc append.simps(2) self_append_conv2)
done

lemma (in executions) config_evolution_drop_last2:
  assumes "config_evolution (last cs) cs"
    and "length cs > 1"
  shows "config_evolution (last (butlast cs)) (butlast cs)"
  using assms apply -
  apply(subgoal_tac "\<exists>c1 c2 confs. cs = confs@[c1,c2]")
  apply(erule exE)+
  apply(simp add: butlast_append config_evolution_drop_last)
  using list_two_at_end apply blast
done

lemma (in executions) take_step_disj:
  assumes "take_step conf = conf'"
  shows "send_step conf = conf' \<or> recv_step conf = conf'"
  using assms apply -
  apply(subgoal_tac "take_step \<in> {send_step, recv_step}") defer
  apply(rule choose_set_memb, simp, simp add: take_step_def, force)
done

lemma (in executions) config_evolution_exists:
  assumes "execution conf"
  shows "\<exists>confs. config_evolution conf confs"
  using assms unfolding config_evolution_def
  apply(induction rule: execution.induct)
  apply(rule_tac x="[initial_conf]" in exI)
  apply(simp add: execution.intros(1))
  apply(erule exE)
  apply(rule_tac x="confs@[conf']" in exI, clarsimp)
  apply(rule conjI)
  using execution.intros(2) last_in_set apply blast
  apply(rule allI)+
  apply(drule take_step_disj, erule disjE, clarsimp)
  apply(case_tac suf, force)
  apply(metis (no_types, lifting) butlast.simps(2) butlast_append butlast_snoc list.simps(3))
  apply(clarsimp, case_tac suf, force)
  apply(metis (no_types, lifting) butlast.simps(2) butlast_append butlast_snoc list.simps(3))
done

lemma (in executions) config_evolution_fold:
  assumes "execution conf"
  shows "\<exists>steps. conf = fold (op \<circ>) steps id initial_conf"
  using assms unfolding config_evolution_def
  apply(induction rule: execution.induct)
  apply(rule_tac x="[]" in exI, simp)
  apply(erule exE)
  apply(rule_tac x="steps@[take_step]" in exI, simp)
done

lemma (in executions) config_evolution_butlast:
  assumes "config_evolution conf (confs@[conf])"
    and "conf \<noteq> initial_conf"
  shows "config_evolution (last confs) confs"
  using assms unfolding config_evolution_def apply clarsimp
  apply(rule conjI, force)
  apply(rule conjI)
  apply(metis (mono_tags, lifting) hd_append list.sel(1))
  apply(clarsimp, blast)
done

lemma (in executions) history_append:
  assumes "config_evolution conf confs"
  and "\<exists>suf. pre@x#y#suf = confs"
  shows "(send_step x = y \<or> recv_step x = y) \<and>
      (\<exists>i es. fst (snd x i) @ es = fst (snd y i) \<and> (\<forall>j. i\<noteq>j \<longrightarrow> fst (snd x j) = fst (snd y j)))"
  using assms apply(simp add: config_evolution_def)
  apply(erule conjE)+
  apply(erule_tac x="pre" in allE)
  apply(erule_tac x="fst x" in allE, erule_tac x="snd x" in allE)
  apply(erule_tac x="fst y" in allE, erule_tac x="snd y" in allE)
  apply(subgoal_tac "send_step x = y \<or> recv_step x = y \<Longrightarrow>
       \<exists>i. (\<exists>es. fst (snd x i) @ es = fst (snd y i)) \<and> (\<forall>j. i \<noteq> j \<longrightarrow> fst (snd x j) = fst (snd y j))")
  apply force
  apply(case_tac "x=y")
  apply(insert node_exists, (erule exE)+, rule_tac x=node in exI, simp)
  apply(erule disjE)
  apply(simp add: send_step_def case_prod_beta)
  apply(erule unpack_let)+
  apply(simp add: case_prod_beta split: if_split_asm)
  apply(erule unpack_let)
  apply(rule_tac x=sender in exI, rule conjI)
  apply(rule_tac x="fst (send_msg sender (snd x sender) msg)" in exI, force, force)
  apply(simp add: recv_step_def case_prod_beta split: if_split_asm)
  apply(erule unpack_let)+
  apply(rule_tac x=recipient in exI, rule conjI)
  apply(rule_tac x="fst (recv_msg recipient (snd x recipient) msg)" in exI, auto)
done

lemma (in executions) history_nonempty:
  assumes "execution conf"
  and "evt \<in> set (fst (snd conf i))"
  shows "\<exists>confs. config_evolution conf confs \<and> length confs > 1"
  using assms apply -
  apply(drule config_evolution_exists, erule exE)
  apply(rule_tac x=confs in exI, clarsimp)
  apply(simp add: config_evolution_def)
  apply(erule conjE)+
  apply(subgoal_tac "length confs \<le> 1 \<Longrightarrow> False", fastforce)
  apply(subgoal_tac "confs = [initial_conf]")
  using initial_conf_def apply fastforce
  apply(metis le_less length_0_conv less_one list_head_length_one)
done

lemma (in executions) history_nonempty2:
  assumes "execution conf"
  and "config_evolution conf confs"
  and "evt \<in> set (fst (snd conf i))"
  shows "\<exists>pre c. confs = pre @ [c, conf]"
  using assms apply(simp add: config_evolution_def)
  apply(erule conjE)+
  apply(subgoal_tac "butlast confs \<noteq> []")
  apply(rule_tac x="butlast (butlast confs)" in exI)
  apply(rule_tac x="fst (last (butlast confs))" in exI)
  apply(rule_tac x="snd (last (butlast confs))" in exI)
  apply(metis append_butlast_last_id append_eq_appendI butlast.simps(2) last_ConsL
    last_ConsR list.distinct(1) prod.collapse)
  apply(subgoal_tac "butlast confs = [] \<Longrightarrow> False", fastforce)
  apply(subgoal_tac "confs = [initial_conf]")
  using initial_conf_def apply fastforce
  apply(metis append_butlast_last_id append_self_conv2 list.sel(1))
done

lemma (in executions) history_append_simp:
  assumes "conf' = conf(i := (fst (conf i) @ xs, insert msg (snd (conf i))))"
  shows "fst (conf i) @ xs = fst (conf' i)"
using assms by simp

lemma (in executions) evolution_threshold:
  assumes "config_evolution conf confs"
    and "P conf" and "\<not> P initial_conf"
  shows "\<exists>pre before after suf. (\<not> P before) \<and> (P after) \<and>
    confs = pre @ [before, after] @ suf \<and> before \<noteq> after \<and>
    (send_step before = after \<or> recv_step before = after)"
  using assms
  apply(induction confs arbitrary: conf rule: rev_induct)
  apply(simp add: config_evolution_def)
  apply(case_tac "xs=[]")
  using config_evolution_def initial_conf_def apply fastforce
  apply(erule_tac x="last xs" in meta_allE)
  apply(insert config_evolution_def)
  apply(erule_tac x=conf in meta_allE, erule_tac x="xs@[x]" in meta_allE)
  apply(simp, (erule conjE)+)
  apply(erule_tac x="butlast xs" in allE)
  apply(erule_tac x="fst (last xs)" in allE)
  apply(erule_tac x="snd (last xs)" in allE)
  apply(erule_tac x="fst conf" in allE)
  apply(erule_tac x="snd conf" in allE)
  apply(subgoal_tac "\<exists>suf. xs @ [conf] = butlast xs @ last xs # conf # suf") defer
  apply(metis (no_types, lifting) append_butlast_last_id append_eq_append_conv2
    butlast.simps(2) last_ConsL last_ConsR list.simps(3))
  apply simp
  apply(case_tac "last xs = conf")
  apply(metis append_Cons append_assoc config_evolution_butlast)
  apply(case_tac "(\<not> P (last xs)) \<and> (P (conf))")
  apply(rule_tac x="butlast xs" in exI)
  apply(rule_tac x="fst (last xs)" in exI)
  apply(rule_tac x="snd (last xs)" in exI, simp)
  apply(rule_tac x="fst conf" in exI)
  apply(rule_tac x="snd conf" in exI, force)
  apply(metis append_Cons append_assoc config_evolution_butlast)
done

lemma (in executions) event_origin:
  assumes "config_evolution conf confs"
    and "evt \<in> set (fst (snd conf i))"
  shows "\<exists>pre before after suf es.
    config_evolution conf (pre @ [before, after] @ suf) \<and>
    before \<noteq> after \<and> (send_step before = after \<or> recv_step before = after) \<and>
    evt \<in> set es \<and> fst (snd before i) @ es = fst (snd after i)"
  using assms apply -
  apply(frule_tac P="\<lambda>c. evt \<in> set (fst (snd c i))" in evolution_threshold)
  apply(simp, simp add: initial_conf_def, (erule exE)+, (erule conjE)+)
  apply(erule disjE)
  apply(insert send_step_def, erule_tac x=before in meta_allE)[1]
  apply(simp add: case_prod_beta)
  apply(erule unpack_let)+
  apply(simp add: case_prod_beta split: if_split_asm)
  apply(erule unpack_let)
  apply(subgoal_tac "i = sender")
  apply(rule_tac x="pre" in exI)
  apply(rule_tac x="fst before" in exI, rule_tac x="snd before" in exI)
  apply(rule_tac x="fst after" in exI, rule_tac x="snd after" in exI)
  apply((rule conjI, force)+, force, force)
  apply(insert recv_step_def, erule_tac x=before in meta_allE)
  apply(simp add: case_prod_beta split: if_split_asm)
  apply(erule unpack_let)+
  apply(subgoal_tac "i = recipient")
  apply(rule_tac x="pre" in exI)
  apply(rule_tac x="fst before" in exI, rule_tac x="snd before" in exI)
  apply(rule_tac x="fst after" in exI, rule_tac x="snd after" in exI)
  apply((rule conjI, force)+, force, force)
done

lemma (in executions) message_origin:
  assumes "config_evolution conf confs"
    and "msg \<in> fst conf"
  shows "\<exists>pre before after suf sender valid evts state.
    config_evolution conf (pre @ [before, after] @ suf) \<and>
    valid = valid_msg sender (snd before sender) \<and> valid \<noteq> {} \<and> msg \<in> valid \<and>
    (evts, state) = send_msg sender (snd before sender) msg \<and>
    after = (insert msg (fst before),
    (snd before)(sender := (fst (snd before sender) @ evts, state)))"
  using assms apply -
  apply(frule_tac P="\<lambda>c. msg \<in> fst c" in evolution_threshold)
  apply(simp, simp add: initial_conf_def, (erule exE)+, (erule conjE)+)
  apply(erule disjE)
  apply(insert send_step_def, erule_tac x="before" in meta_allE)[1]
  apply(simp add: case_prod_beta)
  apply(erule unpack_let)+
  apply(simp add: case_prod_beta split: if_split_asm)
  apply(erule unpack_let)
  apply(case_tac "msga=msg")
  apply(rule_tac x="pre" in exI)
  apply(rule_tac x="fst before" in exI, rule_tac x="snd before" in exI)
  apply(rule_tac x="fst after" in exI, rule_tac x="snd after" in exI)
  apply(rule conjI, force)
  apply(rule_tac x="sender" in exI)
  apply(rule conjI, simp)
  apply(rule conjI, simp add: some_set_memb)
  apply(rule_tac x="fst (send_msg sender (snd before sender) msga)" in exI)
  apply(rule_tac x="snd (send_msg sender (snd before sender) msga)" in exI)
  apply(rule conjI, simp)
  apply(rule conjI, force, force)
  apply(subgoal_tac "config_evolution before (pre @ [before])", simp)
  apply(subgoal_tac "msg \<in> fst before", simp, force, force)
  apply(insert recv_step_def, erule_tac x="before" in meta_allE)
  apply(simp add: case_prod_beta split: if_split_asm)
  apply(erule unpack_let)+
  apply force
done

lemma (in executions) evolution_monotonic_prop:
  assumes "config_evolution later (pre @ [earlier] @ suf)"
    and "P earlier"
    and "\<And>conf. P conf \<Longrightarrow> P (send_step conf) \<and> P (recv_step conf)"
  shows "P later"
  using assms
  apply(induction suf arbitrary: later rule: rev_induct)
  apply(simp add: config_evolution_def)
  apply(erule_tac x="last (pre @ earlier # xs)" in meta_allE)+
  apply(subgoal_tac "x=later") defer apply(simp add: config_evolution_def)
  apply(subst (asm) config_evolution_def, (erule conjE)+)
  apply(case_tac "xs=[]")
  apply(erule_tac x=pre in allE, force)
  apply(subgoal_tac "config_evolution (last xs) (pre @ [earlier] @ xs)")
  using assms(3) apply simp
  apply(erule_tac x="butlast (pre @ earlier # xs)" in allE)
  apply(erule_tac x="fst (last xs)" in allE)
  apply(erule_tac x="snd (last xs)" in allE)
  apply(erule_tac x="fst later" in allE)
  apply(erule_tac x="snd later" in allE)
  apply(subgoal_tac "send_step (last xs) = later \<or> recv_step (last xs) = later")
  apply blast
  apply(subgoal_tac "pre @ earlier # xs @ [later] = butlast (pre @ earlier # xs) @ last xs # [later]")
  apply(simp, simp add: butlast_append)
  apply(subgoal_tac "config_evolution x (pre @ [earlier] @ xs @ [x])")
  apply(insert config_evolution_drop_last)
  apply(erule_tac x=x in meta_allE)
  apply(erule_tac x="butlast (pre @ earlier # xs)" in meta_allE)
  apply(erule_tac x="last xs" in meta_allE)
  apply(simp add: butlast_append)
  apply(metis append.assoc append_butlast_last_id butlast.simps(2) last_ConsL last_ConsR list.simps(3))
  using config_evolution_def apply presburger
done

lemma (in executions) no_return_to_initial:
  assumes "config_evolution later (pre @ [earlier] @ suf)"
    and "earlier \<noteq> initial_conf"
  shows "later \<noteq> initial_conf"
  using assms apply -
  apply(erule evolution_monotonic_prop)
  apply(simp_all add: send_step_def recv_step_def case_prod_beta Let_unfold initial_conf_def)
done

lemma (in executions) message_set_monotonic:
  assumes "config_evolution later (pre @ [earlier] @ suf)"
    and "msg \<in> fst earlier"
  shows "msg \<in> fst later"
  using assms apply -
  apply(erule evolution_monotonic_prop, simp)
  apply(simp add: send_step_def recv_step_def case_prod_beta Let_unfold)
  apply blast
done

lemma (in executions) node_history_monotonic:
  assumes "config_evolution later (pre @ [earlier] @ suf)"
  shows "\<exists>suf. fst (snd earlier i) @ suf = fst (snd later i)"
  using assms apply -
  apply(erule evolution_monotonic_prop, simp, erule exE, rule conjI)
  apply(simp add: send_step_def case_prod_beta Let_unfold)
  apply(metis append_assoc)
  apply(simp add: recv_step_def case_prod_beta Let_unfold)
  apply(metis append_assoc)
done

lemma (in executions) history_before_event:
  assumes "config_evolution conf confs"
      and "confs = pre @ [before, after] @ suf"
      and "fst (snd before i) @ es = fst (snd after i)"
      and "fst (snd conf i) = es1 @ [hd es] @ es2"
      and "hd es \<notin> set es1"
      and "hd es \<notin> set (fst (snd before i))"
      and "es \<noteq> []"
    shows "fst (snd before i) = es1"
  using assms
  apply(induction confs arbitrary: conf suf es2 rule: rev_induct)
  apply(simp, case_tac "xs=[]", simp)
  apply(case_tac "suf=[]")
  apply(subgoal_tac "fst (snd after i) = es1 @ hd es # es2")
  apply(metis Cons_eq_append_conv self_append_conv2 unique_first_occurrence)
  apply(simp add: config_evolution_def)
  apply(subgoal_tac "x=conf") defer
  apply(metis config_evolution_def last_snoc)
  apply(subgoal_tac "\<exists>esa. es1 @ hd es # esa = fst (snd (last xs) i)")
  apply(erule exE)
  apply(subgoal_tac "config_evolution (last xs) xs") prefer 2
  apply(metis append_is_Nil_conv config_evolution_butlast fst_conv initial_conf_def
    snd_conv snoc_eq_iff_butlast)
  apply(erule_tac x="last xs" in meta_allE)
  apply(erule_tac x="butlast suf" in meta_allE)
  apply(erule_tac x="esa" in meta_allE, simp)
  apply(subgoal_tac "xs = pre @ before # after # butlast suf", simp)
  apply(metis butlast.simps(2) butlast_append butlast_snoc list.simps(3))
  apply(subst (asm) config_evolution_def, (erule conjE)+)
  apply(erule_tac x="butlast xs" in allE, erule_tac x="last xs" in allE)
  apply(erule_tac x="x" in allE, erule_tac x="[]" in allE)
  apply(subgoal_tac "send_step (last xs) = x \<or> recv_step (last xs) = x") defer
  apply(simp add: append_eq_append_conv2)
  apply(erule disjE, simp add: send_step_def case_prod_beta)
  apply(erule unpack_let)+
  apply(simp add: case_prod_beta split: if_split_asm)
  apply(erule unpack_let)
  apply(case_tac "sender=i")
  apply(subgoal_tac "fst (snd x i) = fst (snd (last xs) i) @ fst (send_msg i (snd (last xs) i) msg)")
  prefer 2 apply force
  apply(case_tac "fst (send_msg i (snd (last xs) i) msg) = []")
  apply(rule_tac x="es2" in exI, simp)
  apply(subgoal_tac "hd (fst (send_msg i (snd (last xs) i) msg)) \<notin> set (fst (snd (last xs) i))")
  apply(subgoal_tac "hd (fst (send_msg i (snd (last xs) i) msg)) \<notin> set (es1 @ [hd es])")
  apply(insert drop_final_append)[1]
  apply(erule_tac x="fst (snd x i)" in meta_allE)
  apply(erule_tac x="fst (snd (last xs) i)" in meta_allE)
  apply(erule_tac x="fst (send_msg i (snd (last xs) i) msg)" in meta_allE)
  apply(erule_tac x="es1 @ [hd es]" in meta_allE)
  apply(erule_tac x="es2" in meta_allE, simp)
  

  (*
  apply(simp add: recv_step_def case_prod_beta split: if_split_asm)
  apply(erule unpack_let)+
  *)
  oops

end