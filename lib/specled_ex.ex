defmodule SpecLedEx do
  @moduledoc """
  Local tooling for Spec Led Development repositories.
  """

  alias SpecLedEx.{BranchCheck, Index, Json, Next, Prime, Status, VerificationStrength, Verifier}

  @default_state ".spec/state.json"

  def build_index(root \\ File.cwd!(), opts \\ []) do
    Index.build(root, opts)
  end

  def index(root \\ File.cwd!(), opts \\ []) do
    build_index(root, opts)
  end

  def verify(index, root \\ File.cwd!(), opts \\ []) do
    Verifier.verify(index, root, opts)
  end

  def validate(index, root \\ File.cwd!(), opts \\ []) do
    verify(index, root, opts)
  end

  def report(index, verification_report, root \\ File.cwd!()) do
    Status.build(index, verification_report, root)
  end

  def status(index, verification_report, root \\ File.cwd!()) do
    report(index, verification_report, root)
  end

  def diffcheck(index, root \\ File.cwd!(), opts \\ []) do
    BranchCheck.run(index, root, opts)
  end

  def branch_check(index, root \\ File.cwd!(), opts \\ []) do
    diffcheck(index, root, opts)
  end

  def assist(index, root \\ File.cwd!(), opts \\ []) do
    Next.run(index, root, opts)
  end

  def next(index, root \\ File.cwd!(), opts \\ []) do
    assist(index, root, opts)
  end

  def prime(index, verification_report, root \\ File.cwd!(), opts \\ []) do
    Prime.build(index, verification_report, root, opts)
  end

  def read_state(root \\ File.cwd!(), output_path \\ @default_state) do
    path = Path.expand(output_path, root)
    Json.read(path)
  end

  def write_state(index, report, root \\ File.cwd!(), output_path \\ @default_state) do
    path = Path.expand(output_path, root)
    subjects = index["subjects"] || []
    decisions = index["decisions"] || []
    findings = if report, do: report["findings"] || [], else: []

    summary =
      (index["summary"] || %{})
      |> Map.merge(%{
        "findings" => length(findings),
        "verifications" => (index["summary"] || %{})["verification_items"] || 0
      })
      |> Map.delete("verification_items")
      |> Map.delete("parse_errors")

    state =
      %{
        "specification_version" => "1.0",
        "workspace" => %{
          "spec_count" => length(subjects),
          "decision_count" => length(decisions)
        },
        "index" => normalize_index(subjects),
        "decisions" => normalize_decisions(decisions),
        "findings" => normalize_findings(findings),
        "summary" => summary
      }
      |> maybe_put("verification", normalize_verification(report))

    Json.write!(path, state)
    path
  end

  def detect_spec_dir(root \\ File.cwd!()) do
    Index.detect_spec_dir(root)
  end

  def detect_authored_dir(root \\ File.cwd!(), spec_dir \\ nil) do
    Index.detect_authored_dir(root, spec_dir || detect_spec_dir(root))
  end

  def detect_decision_dir(root \\ File.cwd!(), spec_dir \\ nil) do
    Index.detect_decision_dir(root, spec_dir || detect_spec_dir(root))
  end

  defp normalize_index(subjects) do
    %{
      "subjects" =>
        subjects
        |> Enum.map(fn s ->
          meta = string_key_map(value_for(s, "meta"))

          %{
            "id" => value_for(meta, "id"),
            "file" => value_for(s, "file"),
            "title" => value_for(s, "title"),
            "meta" => meta
          }
        end)
        |> stable_sort(fn subject, index ->
          {
            value_for(subject, "file") || "",
            value_for(subject, "id") || "",
            index
          }
        end),
      "requirements" =>
        flatten_subject_items(subjects, "requirements")
        |> stable_sort(fn item, index ->
          {
            value_for(item, "subject_id") || "",
            value_for(item, "id") || "",
            index
          }
        end),
      "scenarios" =>
        flatten_subject_items(subjects, "scenarios")
        |> stable_sort(fn item, index ->
          {
            value_for(item, "subject_id") || "",
            value_for(item, "id") || "",
            index
          }
        end),
      "verifications" =>
        flatten_subject_items(subjects, "verification")
        |> stable_sort(fn item, index ->
          {
            value_for(item, "subject_id") || "",
            value_for(item, "verification_index") || 0,
            index
          }
        end)
        |> Enum.map(&Map.delete(&1, "verification_index")),
      "exceptions" =>
        flatten_subject_items(subjects, "exceptions")
        |> stable_sort(fn item, index ->
          {
            value_for(item, "subject_id") || "",
            value_for(item, "id") || "",
            index
          }
        end)
    }
  end

  defp normalize_findings(findings) do
    findings
    |> Enum.flat_map(fn
      f when is_map(f) ->
        [
          %{
            "code" => f["code"],
            "level" => f["severity"] || f["level"],
            "message" => f["message"]
          }
          |> maybe_put("file", f["file"])
          |> maybe_put("entity_id", f["subject_id"])
        ]

      _ ->
        []
    end)
    |> stable_sort(fn finding, index ->
      {
        value_for(finding, "file") || "",
        value_for(finding, "entity_id") || "",
        value_for(finding, "code") || "",
        value_for(finding, "message") || "",
        index
      }
    end)
  end

  defp normalize_decisions(decisions) do
    %{
      "items" =>
        decisions
        |> Enum.flat_map(fn
          decision when is_map(decision) ->
            meta = string_key_map(value_for(decision, "meta"))

            [
              %{
                "id" => value_for(meta, "id"),
                "file" => value_for(decision, "file"),
                "title" => value_for(decision, "title"),
                "status" => value_for(meta, "status"),
                "date" => value_for(meta, "date"),
                "affects" => value_for(meta, "affects") || [],
                "superseded_by" => value_for(meta, "superseded_by")
              }
              |> drop_nil_values()
            ]

          _ ->
            []
        end)
        |> stable_sort(fn decision, index ->
          {
            value_for(decision, "file") || "",
            value_for(decision, "id") || "",
            index
          }
        end)
    }
  end

  defp normalize_verification(nil), do: nil

  defp normalize_verification(report) when is_map(report) do
    verification = value_for(report, "verification")

    if is_map(verification) do
      claims =
        verification
        |> value_for("claims")
        |> normalize_verification_claims()

      %{
        "default_minimum_strength" =>
          value_for(verification, "default_minimum_strength") || VerificationStrength.default(),
        "cli_minimum_strength" => value_for(verification, "cli_minimum_strength"),
        "strength_summary" =>
          normalize_strength_summary(value_for(verification, "strength_summary")),
        "threshold_failures" => value_for(verification, "threshold_failures") || 0,
        "claims" => claims
      }
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp flatten_subject_items(subjects, key) do
    subjects
    |> Enum.flat_map(fn subject ->
      file = value_for(subject, "file")
      meta = string_key_map(value_for(subject, "meta"))
      subject_id = value_for(meta, "id")

      subject
      |> list_or_empty(key)
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {item, item_index} when is_map(item) ->
          [
            item
            |> string_key_map()
            |> Map.merge(%{
              "file" => file,
              "subject_id" => subject_id,
              "verification_index" => if(key == "verification", do: item_index)
            })
            |> drop_nil_values()
          ]

        _ ->
          []
      end)
    end)
  end

  defp normalize_verification_claims(claims) when is_list(claims) do
    claims
    |> Enum.flat_map(fn
      claim when is_map(claim) ->
        [string_key_map(claim)]

      _ ->
        []
    end)
    |> stable_sort(fn claim, index ->
      {
        value_for(claim, "subject_id") || "",
        value_for(claim, "file") || "",
        value_for(claim, "verification_index") || 0,
        value_for(claim, "cover_id") || "",
        index
      }
    end)
  end

  defp normalize_verification_claims(_claims), do: []

  defp normalize_strength_summary(summary) when is_map(summary) do
    Enum.reduce(VerificationStrength.levels(), %{}, fn level, acc ->
      Map.put(acc, level, value_for(summary, level) || 0)
    end)
  end

  defp normalize_strength_summary(_summary) do
    Enum.into(VerificationStrength.levels(), %{}, fn level -> {level, 0} end)
  end

  defp list_or_empty(map, key) when is_map(map) do
    case value_for(map, key) do
      value when is_list(value) -> value
      _ -> []
    end
  end

  defp list_or_empty(_value, _key), do: []

  defp string_key_map(value) when is_map(value) do
    value
    |> maybe_from_struct()
    |> Enum.reduce(%{}, fn {key, item}, acc ->
      Map.put(acc, to_string(key), normalize_value(item))
    end)
  end

  defp string_key_map(_value), do: nil

  defp normalize_value(value) when is_map(value), do: string_key_map(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value

  defp drop_nil_values(map) do
    Enum.reduce(map, %{}, fn
      {_key, nil}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  defp stable_sort(items, sorter) do
    items
    |> Enum.with_index()
    |> Enum.sort_by(fn {item, index} -> sorter.(item, index) end)
    |> Enum.map(&elem(&1, 0))
  end

  defp maybe_from_struct(%{__struct__: _} = value), do: Map.from_struct(value)
  defp maybe_from_struct(value), do: value

  defp value_for(map, key) when is_map(map) and is_binary(key) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    Map.get(map, key, if(atom_key, do: Map.get(map, atom_key)))
  end

  defp value_for(_map, _key), do: nil
end
