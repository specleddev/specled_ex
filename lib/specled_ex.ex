defmodule SpecLedEx do
  @moduledoc """
  Local tooling for Spec Led Development repositories.
  """

  alias SpecLedEx.{Index, Json, Verifier}

  @default_state ".spec/state.json"

  def build_index(root \\ File.cwd!(), opts \\ []) do
    Index.build(root, opts)
  end

  def verify(index, root \\ File.cwd!(), opts \\ []) do
    Verifier.verify(index, root, opts)
  end

  def read_state(root \\ File.cwd!(), output_path \\ @default_state) do
    path = Path.expand(output_path, root)
    Json.read(path)
  end

  def write_state(index, report, root \\ File.cwd!(), output_path \\ @default_state) do
    path = Path.expand(output_path, root)

    subjects = index["subjects"] || []

    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    normalized_index = normalize_index(subjects)
    findings = if report, do: report["findings"] || [], else: []

    summary =
      (index["summary"] || %{})
      |> Map.merge(%{
        "findings" => length(findings),
        "verifications" => (index["summary"] || %{})["verification_items"] || 0
      })
      |> Map.delete("verification_items")
      |> Map.delete("parse_errors")

    state = %{
      "specification_version" => "1.0",
      "generated_at" => now,
      "workspace" => %{
        "root" => root,
        "spec_count" => length(subjects)
      },
      "index" => normalized_index,
      "findings" => normalize_findings(findings),
      "summary" => summary
    }

    Json.write!(path, state)
    path
  end

  def detect_spec_dir(root \\ File.cwd!()) do
    Index.detect_spec_dir(root)
  end

  def detect_authored_dir(root \\ File.cwd!(), spec_dir \\ nil) do
    Index.detect_authored_dir(root, spec_dir || detect_spec_dir(root))
  end

  defp normalize_index(subjects) do
    requirements = flatten_subject_items(subjects, "requirements")
    scenarios = flatten_subject_items(subjects, "scenarios")
    verifications = flatten_subject_items(subjects, "verification")
    exceptions = flatten_subject_items(subjects, "exceptions")

    %{
      "subjects" =>
        Enum.map(subjects, fn s ->
          meta = string_key_map(value_for(s, "meta"))

          %{
            "id" => value_for(meta, "id"),
            "file" => value_for(s, "file"),
            "title" => value_for(s, "title"),
            "meta" => meta
          }
        end),
      "requirements" => requirements,
      "scenarios" => scenarios,
      "verifications" => verifications,
      "exceptions" => exceptions
    }
  end

  defp normalize_findings(findings) do
    Enum.flat_map(findings, fn
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
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp flatten_subject_items(subjects, key) do
    Enum.flat_map(subjects, fn subject ->
      file = value_for(subject, "file")
      meta = string_key_map(value_for(subject, "meta"))
      subject_id = value_for(meta, "id")

      subject
      |> list_or_empty(key)
      |> Enum.flat_map(fn
        item when is_map(item) ->
          [item |> string_key_map() |> Map.merge(%{"file" => file, "subject_id" => subject_id})]

        _ ->
          []
      end)
    end)
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
