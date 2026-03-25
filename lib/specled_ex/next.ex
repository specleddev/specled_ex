defmodule SpecLedEx.Next do
  @moduledoc false

  alias SpecLedEx.ChangeAnalysis

  def run(index, root, opts \\ []) do
    analysis = ChangeAnalysis.analyze(index, root, opts)
    focused_subject_ids = focused_subject_ids(analysis)
    subject_refs = subject_refs(index, focused_subject_ids)
    classification = classify(analysis, focused_subject_ids)
    reconciliation = reconciliation_status(classification, analysis, focused_subject_ids)

    %{
      "base" => analysis.base,
      "since" => analysis.since,
      "bugfix" => Keyword.get(opts, :bugfix, false),
      "guidance_scope" => guidance_scope_label(analysis),
      "check_scope" => check_scope_label(analysis),
      "changed_files" => analysis.changed_files,
      "policy_files" => analysis.policy_files,
      "classification" => classification,
      "classification_label" => classification_label(classification),
      "reconciliation" => reconciliation,
      "reconciliation_label" => reconciliation_label(reconciliation),
      "changed_subject_ids" => analysis.changed_subject_ids,
      "impacted_subject_ids" => focused_subject_ids,
      "subject_refs" => subject_refs,
      "uncovered_policy_files" => analysis.uncovered_policy_files,
      "rationale" => rationale(classification, analysis, subject_refs),
      "next_steps" => next_steps(classification, reconciliation, analysis, subject_refs, opts),
      "suggested_commands" => suggested_commands(reconciliation, analysis)
    }
  end

  def format_human(report) do
    lines =
      [
        "Spec Led Next",
        "base=#{report["base"]} changed_files=#{length(report["changed_files"] || [])} policy_files=#{length(report["policy_files"] || [])}",
        "guidance_scope=#{report["guidance_scope"]} check_scope=#{report["check_scope"]}",
        "classification=#{report["classification_label"]}",
        "reconciliation=#{report["reconciliation_label"]}",
        "rationale=#{report["rationale"]}"
      ] ++
        format_items("changed_files", report["changed_files"] || []) ++
        format_subjects(report["subject_refs"] || []) ++
        format_items("uncovered_policy_files", report["uncovered_policy_files"] || []) ++
        format_items("next_steps", report["next_steps"] || []) ++
        format_items("commands", report["suggested_commands"] || [])

    Enum.join(lines, "\n")
  end

  defp classify(analysis, focused_subject_ids) do
    cond do
      analysis.uncovered_policy_files != [] ->
        "uncovered_frontier_change"

      length(focused_subject_ids) > 1 ->
        "covered_cross_cutting_change"

      length(focused_subject_ids) == 1 ->
        "covered_local_change"

      true ->
        "likely_non_contract_change"
    end
  end

  defp classification_label("covered_local_change"), do: "covered local change"
  defp classification_label("covered_cross_cutting_change"), do: "covered cross-cutting change"
  defp classification_label("uncovered_frontier_change"), do: "uncovered frontier change"
  defp classification_label("likely_non_contract_change"), do: "likely non-contract change"

  defp reconciliation_label("ready_for_check"), do: "ready for check"
  defp reconciliation_label("needs_subject_updates"), do: "needs subject updates"
  defp reconciliation_label("needs_decision_update"), do: "needs decision update"
  defp reconciliation_label("needs_new_subject"), do: "needs new subject"
  defp reconciliation_label("no_contract_update_needed"), do: "no contract update needed"

  defp rationale("covered_local_change", analysis, [%{"id" => id}]) do
    changed_subject? = Enum.member?(analysis.changed_subject_ids, id)

    if changed_subject? do
      "The current change set points at one known subject, and that subject spec is already part of the change."
    else
      "The current change set points at one known subject, so this is a focused subject update."
    end
  end

  defp rationale("covered_cross_cutting_change", _analysis, subject_refs) do
    "The current change set spans multiple known subjects: #{Enum.map_join(subject_refs, ", ", & &1["id"])}."
  end

  defp rationale("uncovered_frontier_change", analysis, _subject_refs) do
    "These changed files are outside current subject coverage: #{Enum.join(analysis.uncovered_policy_files, ", ")}."
  end

  defp rationale("likely_non_contract_change", %{git_repo?: false}, _subject_refs) do
    "Git is not initialized, so the current change set could not be inspected."
  end

  defp rationale("likely_non_contract_change", _analysis, _subject_refs) do
    "The current change set does not clearly point at a covered runtime contract."
  end

  defp next_steps("covered_local_change", "ready_for_check", _analysis, [subject_ref], opts) do
    bugfix_step =
      if Keyword.get(opts, :bugfix, false) do
        [
          "Keep the regression proof. Review #{subject_ref["file"]} once and avoid extra spec churn if the wording already captures the fix."
        ]
      else
        [
          "Current truth for #{subject_ref["file"]} is already in the change set. Review the proof and move to the strict check."
        ]
      end

    bugfix_step ++ ["Run `mix spec.check` when the branch is ready."]
  end

  defp next_steps("covered_local_change", "needs_subject_updates", _analysis, [subject_ref], opts) do
    bugfix_steps =
      if Keyword.get(opts, :bugfix, false) do
        [
          "Add or keep a regression test that fails before the fix and passes after it.",
          "Review #{subject_ref["file"]}. If the current wording already captures the fix, keep the regression proof and stop. Otherwise tighten the requirement or scenario now."
        ]
      else
        [
          "Update #{subject_ref["file"]} if the change affects current truth."
        ]
      end

    bugfix_steps ++
      [
        "Add or tighten the smallest verification that proves the changed behavior.",
        "Run `mix spec.check` when the subject and verification are aligned."
      ]
  end

  defp next_steps(
         "covered_cross_cutting_change",
         "ready_for_check",
         analysis,
         subject_refs,
         _opts
       ) do
    [
      "Current truth is already updated across: #{Enum.map_join(subject_refs, ", ", & &1["file"])}.",
      review_decision_step(analysis),
      "Run `mix spec.check` when the current truth, proof, and code agree."
    ]
  end

  defp next_steps(
         "covered_cross_cutting_change",
         "needs_subject_updates",
         analysis,
         subject_refs,
         _opts
       ) do
    [
      "Update the impacted subjects together: #{Enum.map_join(subject_refs, ", ", & &1["file"])}.",
      "Add or tighten the smallest proof that covers the cross-subject behavior.",
      review_decision_step(analysis),
      "Run `mix spec.check` when the current truth, proof, and code agree."
    ]
  end

  defp next_steps(
         "covered_cross_cutting_change",
         "needs_decision_update",
         _analysis,
         subject_refs,
         _opts
       ) do
    [
      "The subject updates are already in the change set: #{Enum.map_join(subject_refs, ", ", & &1["file"])}.",
      "Add or revise an ADR if this branch changes durable cross-cutting policy.",
      "Run `mix spec.check` after the ADR decision is settled."
    ]
  end

  defp next_steps("uncovered_frontier_change", _reconciliation, _analysis, _subject_refs, opts) do
    bugfix_steps =
      if Keyword.get(opts, :bugfix, false) do
        [
          "Add or keep the regression test first so the bug stays locked down while you expand coverage."
        ]
      else
        []
      end

    bugfix_steps ++
      [
        "Create or expand one subject in `.spec/specs/` so the changed runtime surface is covered.",
        "Start with the smallest current-truth subject that matches the changed files, then add the verification that proves it.",
        "Run `mix spec.check` after the new or expanded subject is in place."
      ]
  end

  defp next_steps("likely_non_contract_change", _reconciliation, analysis, subject_refs, _opts) do
    cond do
      subject_refs != [] ->
        [
          "You already changed subject files. Review those authored updates and run `mix spec.check`."
        ]

      analysis.changed_files == [] and not analysis.git_repo? ->
        [
          "Git is not initialized yet, so review the nearest subject manually or start a repository before relying on change-set guidance."
        ]

      analysis.changed_files == [] ->
        ["No changed files were detected, so there is nothing to reconcile right now."]

      true ->
        [
          "If behavior did not change, a subject or ADR update is usually not needed.",
          "Run `mix spec.check` if you want a full verification pass before you finish."
        ]
    end
  end

  defp reconciliation_status("uncovered_frontier_change", _analysis, _focused_subject_ids),
    do: "needs_new_subject"

  defp reconciliation_status("likely_non_contract_change", _analysis, _focused_subject_ids),
    do: "no_contract_update_needed"

  defp reconciliation_status(_classification, analysis, focused_subject_ids) do
    subjects_updated? =
      focused_subject_ids != [] and
        Enum.all?(focused_subject_ids, &Enum.member?(analysis.changed_subject_ids, &1))

    decision_needed? =
      ChangeAnalysis.decision_update_needed?(analysis.policy_files, focused_subject_ids)

    cond do
      not subjects_updated? ->
        "needs_subject_updates"

      decision_needed? and not analysis.decision_changed? ->
        "needs_decision_update"

      true ->
        "ready_for_check"
    end
  end

  defp suggested_commands("needs_new_subject", analysis) do
    [check_command(analysis)]
  end

  defp suggested_commands("needs_subject_updates", analysis) do
    [check_command(analysis)]
  end

  defp suggested_commands("needs_decision_update", analysis) do
    [check_command(analysis)]
  end

  defp suggested_commands("ready_for_check", analysis) do
    [check_command(analysis)]
  end

  defp suggested_commands("no_contract_update_needed", analysis) do
    [check_command(analysis)]
  end

  defp focused_subject_ids(analysis) do
    case analysis.impacted_subject_ids do
      [] -> analysis.changed_subject_ids
      ids -> ids
    end
  end

  defp subject_refs(index, subject_ids) do
    subject_ids = MapSet.new(subject_ids)

    index["subjects"]
    |> List.wrap()
    |> Enum.filter(&(SpecLedEx.Coverage.subject_id(&1) in subject_ids))
    |> Enum.map(fn subject ->
      %{
        "id" => SpecLedEx.Coverage.subject_id(subject),
        "file" => Map.get(subject, "file", Map.get(subject, :file))
      }
    end)
    |> Enum.sort_by(&{&1["id"], &1["file"]})
  end

  defp format_items(label, []), do: ["#{label}=none"]

  defp format_items(label, items) do
    ["#{label}:"] ++ Enum.map(items, &"- #{&1}")
  end

  defp format_subjects([]), do: ["impacted_subjects=none"]

  defp format_subjects(subject_refs) do
    items =
      Enum.map(subject_refs, fn subject_ref ->
        "#{subject_ref["id"]} (#{subject_ref["file"]})"
      end)

    ["impacted_subjects:"] ++ Enum.map(items, &"- #{&1}")
  end

  defp review_decision_step(analysis) do
    if analysis.decision_changed? do
      "The ADR update is already in the change set. Review it alongside the subject updates."
    else
      "If this branch changes durable cross-cutting policy, add or revise an ADR before you finish."
    end
  end

  defp check_command(%{git_repo?: true, base: base}), do: "mix spec.check --base #{base}"
  defp check_command(_analysis), do: "mix spec.check"

  defp guidance_scope_label(%{since: since}) when is_binary(since), do: "since #{since}"
  defp guidance_scope_label(%{git_repo?: true, base: base}), do: "branch vs #{base}"
  defp guidance_scope_label(_analysis), do: "workspace"

  defp check_scope_label(%{git_repo?: true, base: base}), do: "full branch vs #{base}"
  defp check_scope_label(_analysis), do: "workspace"
end
