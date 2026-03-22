defmodule SpecLedEx.Status do
  @moduledoc false

  alias SpecLedEx.ChangeAnalysis
  alias SpecLedEx.Coverage
  alias SpecLedEx.VerificationStrength

  def build(index, verification_report, root) do
    subjects = index["subjects"] || []
    decisions = index["decisions"] || []
    covered_files = Coverage.covered_files(index, root)
    subject_file_map = Coverage.subject_file_map(index, root)
    findings = verification_report["findings"] || []
    claims = get_in(verification_report, ["verification", "claims"]) || []
    source_coverage = Coverage.category_summary(root, covered_files, "lib")
    guide_coverage = Coverage.category_summary(root, covered_files, "guides")
    test_coverage = Coverage.category_summary(root, covered_files, "test")

    %{
      "generated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "summary" => %{
        "subjects" => length(subjects),
        "decisions" => length(decisions),
        "requirements" => index["summary"]["requirements"] || 0,
        "scenarios" => index["summary"]["scenarios"] || 0,
        "verification_items" => index["summary"]["verification_items"] || 0,
        "errors" => verification_report["summary"]["errors"] || 0,
        "warnings" => verification_report["summary"]["warnings"] || 0
      },
      "verification" => verification_report["verification"] || default_verification_summary(),
      "coverage" => %{
        "source" => source_coverage,
        "guides" => guide_coverage,
        "tests" => test_coverage
      },
      "frontier" => ChangeAnalysis.frontier(index, root),
      "decisions" => decision_summary(subjects, decisions),
      "weak_spots" => weak_spots(subjects, subject_file_map, findings, claims)
    }
  end

  def format_human(report) do
    verification = report["verification"] || %{}
    strength_summary = verification["strength_summary"] || %{}
    coverage = report["coverage"] || %{}

    lines =
      [
        "Spec Led Status",
        "subjects=#{report["summary"]["subjects"]} decisions=#{report["summary"]["decisions"]} requirements=#{report["summary"]["requirements"]}",
        "findings errors=#{report["summary"]["errors"]} warnings=#{report["summary"]["warnings"]}",
        "verification claimed=#{strength_summary["claimed"] || 0} linked=#{strength_summary["linked"] || 0} executed=#{strength_summary["executed"] || 0}",
        format_category_line("source", coverage["source"]),
        format_category_line("guides", coverage["guides"]),
        format_category_line("tests", coverage["tests"])
      ] ++
        format_weak_spots(report["weak_spots"] || []) ++
        format_frontier(report["frontier"])

    Enum.join(lines, "\n")
  end

  defp format_category_line(_label, nil), do: nil

  defp format_category_line(label, category) do
    "#{label} covered=#{category["covered"] || 0}/#{category["total"] || 0}"
  end

  defp format_weak_spots([]), do: ["weak_spots=none"]

  defp format_weak_spots(weak_spots) do
    ["weak_spots=#{length(weak_spots)}"] ++
      Enum.map(weak_spots, fn weak_spot ->
        "#{weak_spot["id"]} warnings=#{weak_spot["warnings"]} errors=#{weak_spot["errors"]} covered_files=#{weak_spot["covered_files"]}"
      end)
  end

  defp format_frontier(nil), do: []

  defp format_frontier(frontier) do
    lines = [
      "frontier covered_subjects=#{frontier["covered_subject_count"] || 0} uncovered_files=#{frontier["uncovered_file_count"] || 0}"
    ]

    next_gap_lines =
      [
        format_gap_line("source", frontier["uncovered_source_files"] || []),
        format_gap_line("guides", frontier["uncovered_guide_files"] || []),
        format_gap_line("tests", frontier["uncovered_test_files"] || [])
      ]
      |> Enum.reject(&is_nil/1)

    if next_gap_lines == [] do
      lines ++ ["next_gaps=none"]
    else
      lines ++ next_gap_lines
    end
  end

  defp format_gap_line(_label, []), do: nil

  defp format_gap_line(label, files) do
    "next_gaps #{label}=#{Enum.join(Enum.take(files, 3), ", ")}"
  end

  defp decision_summary(subjects, decisions) do
    subject_decision_refs =
      subjects
      |> Enum.reduce(%{}, fn subject, acc ->
        subject_id = Coverage.subject_id(subject)

        subject
        |> decision_refs()
        |> List.wrap()
        |> Enum.reduce(acc, fn decision_id, inner_acc ->
          Map.update(inner_acc, decision_id, [subject_id], &[subject_id | &1])
        end)
      end)

    %{
      "count" => length(decisions),
      "accepted" => Enum.count(decisions, &(decision_status(&1) == "accepted")),
      "superseded" => Enum.count(decisions, &(decision_status(&1) == "superseded")),
      "references" =>
        subject_decision_refs
        |> Enum.map(fn {decision_id, subject_ids} ->
          %{
            "decision_id" => decision_id,
            "subject_ids" => Enum.sort(Enum.uniq(subject_ids))
          }
        end)
        |> Enum.sort_by(& &1["decision_id"])
    }
  end

  defp weak_spots(subjects, subject_file_map, findings, claims) do
    findings_by_subject = Enum.group_by(findings, &(&1["subject_id"] || "<global>"))
    claims_by_subject = Enum.group_by(claims, &(&1["subject_id"] || "<global>"))

    subjects
    |> Enum.map(fn subject ->
      id = Coverage.subject_id(subject)
      subject_findings = Map.get(findings_by_subject, id, [])
      subject_claims = Map.get(claims_by_subject, id, [])

      %{
        "id" => id,
        "file" => subject["file"],
        "warnings" => Enum.count(subject_findings, &(&1["severity"] == "warning")),
        "errors" => Enum.count(subject_findings, &(&1["severity"] == "error")),
        "covered_files" => Map.get(subject_file_map, id, MapSet.new()) |> MapSet.size(),
        "claim_strengths" => strength_summary(subject_claims)
      }
    end)
    |> Enum.filter(fn weak_spot ->
      weak_spot["warnings"] > 0 or weak_spot["errors"] > 0 or weak_spot["covered_files"] == 0
    end)
    |> Enum.sort_by(fn weak_spot ->
      {-weak_spot["errors"], -weak_spot["warnings"], weak_spot["id"]}
    end)
  end

  defp strength_summary(claims) do
    Enum.reduce(VerificationStrength.levels(), %{}, fn level, acc ->
      Map.put(acc, level, Enum.count(claims, &(&1["strength"] == level)))
    end)
  end

  defp decision_status(decision) do
    meta = Map.get(decision, "meta", Map.get(decision, :meta, %{}))
    Map.get(meta, "status", Map.get(meta, :status, ""))
  end

  defp decision_refs(subject) do
    meta = Map.get(subject, "meta", Map.get(subject, :meta, %{}))
    Map.get(meta, "decisions", Map.get(meta, :decisions, []))
  end

  defp default_verification_summary do
    %{
      "default_minimum_strength" => VerificationStrength.default(),
      "cli_minimum_strength" => nil,
      "strength_summary" => %{"claimed" => 0, "linked" => 0, "executed" => 0},
      "threshold_failures" => 0,
      "claims" => []
    }
  end
end
