defmodule SpecLedEx.BranchCheck do
  @moduledoc false

  alias SpecLedEx.ChangeAnalysis

  def run(index, root, opts \\ []) do
    analysis = ChangeAnalysis.analyze(index, root, opts)
    changed_subject_ids = MapSet.new(analysis.changed_subject_ids)

    file_findings =
      Enum.flat_map(analysis.policy_files, fn path ->
        impacted_subjects = Map.get(analysis.impacted_by_file, path, []) |> MapSet.new()

        cond do
          MapSet.size(impacted_subjects) == 0 and
              ChangeAnalysis.ignorable_deleted_policy_file?(root, path, changed_subject_ids) ->
            []

          MapSet.size(impacted_subjects) == 0 ->
            [
              finding(
                "error",
                "branch_guard_unmapped_change",
                "Changed file is not covered by any current-truth subject: #{path}",
                path
              )
            ]

          true ->
            missing_subject_ids =
              impacted_subjects
              |> MapSet.difference(changed_subject_ids)
              |> MapSet.to_list()
              |> Enum.sort()

            if missing_subject_ids == [] do
              []
            else
              [
                finding(
                  "error",
                  "branch_guard_missing_subject_update",
                  "Changed file #{path} impacts subject specs that were not updated: #{Enum.join(missing_subject_ids, ", ")}",
                  path
                )
              ]
            end
        end
      end)

    impacted_subjects = analysis.impacted_subject_ids |> MapSet.new()

    governance_findings =
      if needs_decision_update?(analysis.policy_files, impacted_subjects) and
           not analysis.decision_changed? do
        [
          finding(
            "error",
            "branch_guard_missing_decision_update",
            "Cross-cutting change spans multiple subjects but no decision file changed",
            nil
          )
        ]
      else
        []
      end

    findings =
      Enum.sort_by(
        file_findings ++ governance_findings,
        &{&1["code"], &1["file"] || "", &1["message"]}
      )

    %{
      "base" => analysis.base,
      "changed_files" => analysis.changed_files,
      "status" => if(findings == [], do: "pass", else: "fail"),
      "summary" => %{
        "changed_files" => length(analysis.changed_files),
        "policy_files" => length(analysis.policy_files),
        "findings" => length(findings)
      },
      "findings" => findings,
      "guidance" => guidance(analysis)
    }
  end

  defp guidance(analysis) do
    change_type =
      cond do
        analysis.uncovered_policy_files != [] -> "outside_current_coverage"
        length(analysis.impacted_subject_ids) > 1 -> "cross_cutting"
        length(analysis.impacted_subject_ids) == 1 -> "single_subject"
        true -> "non_contract_or_meta"
      end

    %{
      "change_type" => change_type,
      "impacted_subject_ids" => analysis.impacted_subject_ids,
      "uncovered_policy_files" => analysis.uncovered_policy_files,
      "suggested_command" => "mix spec.next --base #{analysis.base}"
    }
  end

  defp needs_decision_update?(policy_files, impacted_subjects) do
    length(policy_files) > 1 and MapSet.size(impacted_subjects) > 1
  end

  defp finding(severity, code, message, file) do
    %{
      "severity" => severity,
      "code" => code,
      "message" => message,
      "file" => file
    }
  end
end
