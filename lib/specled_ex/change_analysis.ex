defmodule SpecLedEx.ChangeAnalysis do
  @moduledoc false

  alias SpecLedEx.Coverage

  @decision_pattern ~r/^\.spec\/decisions\/.+\.md$/
  @policy_prefixes ~w(lib/ test/ guides/ docs/ priv/ skills/ test_support/)
  @policy_root_files ~w(README.md AGENTS.md CHANGELOG.md mix.exs)

  def analyze(index, root, opts \\ []) do
    git_repo? = git_repo?(root)
    base = detect_base_ref(root, opts[:base], git_repo?)
    changed_files = changed_files(root, base, git_repo?)
    subject_file_map = Coverage.subject_file_map(index, root)
    changed_subject_ids = changed_subject_ids(index, changed_files)
    policy_files = Enum.filter(changed_files, &policy_target?/1)

    impacted_by_file =
      Map.new(policy_files, fn path ->
        impacted_subject_ids =
          subject_file_map
          |> Coverage.subject_ids_for_path(path)
          |> MapSet.to_list()
          |> Enum.sort()

        {path, impacted_subject_ids}
      end)

    impacted_subject_ids =
      impacted_by_file
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    %{
      git_repo?: git_repo?,
      base: base,
      changed_files: changed_files,
      policy_files: policy_files,
      subject_file_map: subject_file_map,
      changed_subject_ids: changed_subject_ids |> MapSet.to_list() |> Enum.sort(),
      impacted_by_file: impacted_by_file,
      impacted_subject_ids: impacted_subject_ids,
      uncovered_policy_files:
        Enum.filter(policy_files, fn path ->
          Map.get(impacted_by_file, path, []) == [] and
            not ignorable_deleted_policy_file?(root, path, changed_subject_ids)
        end),
      decision_changed?: Enum.any?(changed_files, &decision_file?/1)
    }
  end

  def frontier(index, root) do
    covered_files = Coverage.covered_files(index, root)
    source = Coverage.category_summary(root, covered_files, "lib")
    guides = Coverage.category_summary(root, covered_files, "guides")
    tests = Coverage.category_summary(root, covered_files, "test")

    %{
      "covered_subject_count" => length(index["subjects"] || []),
      "uncovered_source_files" => source["uncovered"] || [],
      "uncovered_guide_files" => guides["uncovered"] || [],
      "uncovered_test_files" => tests["uncovered"] || [],
      "uncovered_file_count" =>
        length(source["uncovered"] || []) +
          length(guides["uncovered"] || []) +
          length(tests["uncovered"] || [])
    }
  end

  def changed_files(root, explicit_base \\ nil) do
    git_repo? = git_repo?(root)
    base = detect_base_ref(root, explicit_base, git_repo?)
    changed_files(root, base, git_repo?)
  end

  defp changed_files(_root, _base, false), do: []

  defp changed_files(root, base, true) do
    [
      diff_against_base(root, base),
      working_tree_diff(root),
      staged_diff(root),
      untracked_files(root)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(&generated_state_file?/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def detect_base_ref(root, explicit_base \\ nil) do
    detect_base_ref(root, explicit_base, git_repo?(root))
  end

  defp detect_base_ref(_root, explicit_base, _git_repo?) when is_binary(explicit_base),
    do: explicit_base

  defp detect_base_ref(_root, nil, false), do: "HEAD"

  defp detect_base_ref(root, nil, true) do
    Enum.find(["origin/main", "main", "master", "HEAD"], &git_ref_exists?(root, &1)) || "HEAD"
  end

  def decision_file?(path) do
    Regex.match?(@decision_pattern, path) and Path.basename(path) != "README.md"
  end

  def decision_update_needed?(policy_files, impacted_subject_ids) when is_list(policy_files) do
    length(policy_files) > 1 and length(impacted_subject_ids) > 1
  end

  def ignorable_deleted_policy_file?(root, path, changed_subject_ids)
      when is_list(changed_subject_ids) do
    ignorable_deleted_policy_file?(root, path, MapSet.new(changed_subject_ids))
  end

  def ignorable_deleted_policy_file?(root, path, changed_subject_ids) do
    not File.exists?(Path.join(root, path)) and MapSet.size(changed_subject_ids) > 0
  end

  def policy_target?(path) do
    (Enum.any?(@policy_prefixes, &String.starts_with?(path, &1)) and
       not String.starts_with?(path, "docs/plans/")) or path in @policy_root_files
  end

  defp changed_subject_ids(index, changed_files) do
    changed_files = MapSet.new(changed_files)

    index["subjects"]
    |> List.wrap()
    |> Enum.reduce(MapSet.new(), fn subject, acc ->
      if MapSet.member?(changed_files, subject_file(subject)) do
        MapSet.put(acc, Coverage.subject_id(subject))
      else
        acc
      end
    end)
  end

  defp diff_against_base(root, base) do
    git_lines(root, ["diff", "--name-only", "#{base}...HEAD"])
  end

  defp working_tree_diff(root) do
    git_lines(root, ["diff", "--name-only"])
  end

  defp staged_diff(root) do
    git_lines(root, ["diff", "--cached", "--name-only"])
  end

  defp untracked_files(root) do
    git_lines(root, ["ls-files", "--others", "--exclude-standard"])
  end

  defp git_ref_exists?(root, ref) do
    {_output, exit_code} =
      System.cmd("git", ["-C", root, "rev-parse", "--verify", ref], stderr_to_stdout: true)

    exit_code == 0
  end

  defp git_lines(root, args) do
    {output, exit_code} = System.cmd("git", ["-C", root | args], stderr_to_stdout: true)

    if exit_code == 0 do
      String.split(output, "\n", trim: true)
    else
      raise "git command failed: git #{Enum.join(args, " ")}\n#{String.trim(output)}"
    end
  end

  defp git_repo?(root) do
    {output, exit_code} =
      System.cmd("git", ["-C", root, "rev-parse", "--is-inside-work-tree"],
        stderr_to_stdout: true
      )

    exit_code == 0 and String.trim(output) == "true"
  end

  defp generated_state_file?(path), do: path == ".spec/state.json"

  defp subject_file(subject) when is_map(subject) do
    Map.get(subject, "file", Map.get(subject, :file))
  end
end
