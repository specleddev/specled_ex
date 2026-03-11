defmodule SpecLedEx.Verifier do
  @moduledoc false

  alias SpecLedEx.Schema.Verification, as: VerificationSchema

  @command_kind "command"
  @file_kinds ~w(file source_file test_file guide_file readme_file workflow_file test doc workflow contract)
  @known_verification_kinds VerificationSchema.kinds()
  @id_pattern ~r/^[a-z0-9][a-z0-9._-]*$/

  def verify(index, root, opts \\ []) do
    strict? = Keyword.get(opts, :strict, false)
    debug? = Keyword.get(opts, :debug, false)
    run_commands? = Keyword.get(opts, :run_commands, false)
    subjects = index["subjects"] || []
    command_results = build_command_results(subjects, root, run_commands?)

    findings =
      subjects
      |> Enum.flat_map(&verify_subject(&1, root, command_results))
      |> then(&(&1 ++ duplicate_subject_id_findings(subjects)))
      |> then(&(&1 ++ duplicate_requirement_id_findings(subjects)))
      |> then(&(&1 ++ duplicate_scenario_id_findings(subjects)))
      |> then(&(&1 ++ duplicate_exception_id_findings(subjects)))
      |> then(&(&1 ++ invalid_id_format_findings(subjects)))

    checks =
      if debug? do
        build_debug_checks(subjects, root, run_commands?, command_results)
      else
        []
      end

    errors = Enum.count(findings, &(&1["severity"] == "error"))
    warnings = Enum.count(findings, &(&1["severity"] == "warning"))
    fail? = errors > 0 or (strict? and warnings > 0)

    report = %{
      "generated_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "strict" => strict?,
      "run_commands" => run_commands?,
      "status" => if(fail?, do: "fail", else: "pass"),
      "summary" => %{
        "subjects" => length(subjects),
        "errors" => errors,
        "warnings" => warnings,
        "findings" => length(findings)
      },
      "findings" => findings
    }

    if debug? do
      Map.put(report, "checks", checks)
    else
      report
    end
  end

  defp verify_subject(subject, root, command_results) do
    file = string_field(subject, "file")
    meta = subject_meta(subject)
    subject_id = id_of(meta, "id") || file
    reqs = map_items(field(subject, "requirements"))
    scenarios = map_items(field(subject, "scenarios"))
    verifications = verification_entries(subject, subject_id, file, command_results)
    exceptions = map_items(field(subject, "exceptions"))
    parse_errors = list_field(subject, "parse_errors")
    requirement_ids = reqs |> Enum.map(&id_of(&1, "id")) |> Enum.reject(&is_nil/1)
    scenario_ids = scenarios |> Enum.map(&id_of(&1, "id")) |> Enum.reject(&is_nil/1)
    claim_ids = MapSet.new(requirement_ids ++ scenario_ids)

    []
    |> add_meta_findings(meta, subject_id, file)
    |> add_parse_error_findings(parse_errors, subject_id, file)
    |> add_missing_requirement_id_findings(reqs, subject_id, file)
    |> add_missing_scenario_id_findings(scenarios, subject_id, file)
    |> add_scenario_cover_findings(scenarios, MapSet.new(requirement_ids), subject_id, file)
    |> add_scenario_structure_findings(scenarios, subject_id, file)
    |> add_verification_findings(verifications, claim_ids, root, subject_id, file)
    |> add_requirement_coverage_findings(
      requirement_ids,
      verifications,
      exceptions,
      subject_id,
      file
    )
  end

  defp add_meta_findings(findings, meta, subject_id, file) do
    required = ["id", "kind", "status"]

    Enum.reduce(required, findings, fn key, acc ->
      if present_string?(meta, key) do
        acc
      else
        [
          finding(
            "error",
            "missing_meta_field",
            "Missing required spec-meta field: #{key}",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp add_parse_error_findings(findings, parse_errors, subject_id, file) do
    Enum.reduce(parse_errors, findings, fn message, acc ->
      [finding("error", "parse_error", message, subject_id, file) | acc]
    end)
  end

  defp add_missing_requirement_id_findings(findings, requirements, subject_id, file) do
    Enum.reduce(requirements, findings, fn req, acc ->
      if present_string?(req, "id") do
        acc
      else
        [
          finding(
            "error",
            "missing_requirement_id",
            "Requirement entry is missing id",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp add_missing_scenario_id_findings(findings, scenarios, subject_id, file) do
    Enum.reduce(scenarios, findings, fn scenario, acc ->
      if present_string?(scenario, "id") do
        acc
      else
        [
          finding(
            "error",
            "missing_scenario_id",
            "Scenario entry is missing id",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp add_scenario_cover_findings(findings, scenarios, requirement_ids, subject_id, file) do
    Enum.reduce(scenarios, findings, fn scenario, acc ->
      covers = list_field(scenario, "covers")
      scenario_id = id_of(scenario, "id") || "<unknown>"

      Enum.reduce(covers, acc, fn cover_id, cover_acc ->
        if MapSet.member?(requirement_ids, cover_id) do
          cover_acc
        else
          [
            finding(
              "warning",
              "scenario_unknown_cover",
              "Scenario #{scenario_id} references unknown requirement id: #{cover_id}",
              subject_id,
              file
            )
            | cover_acc
          ]
        end
      end)
    end)
  end

  defp add_scenario_structure_findings(findings, scenarios, subject_id, file) do
    Enum.reduce(scenarios, findings, fn scenario, acc ->
      scenario_id = id_of(scenario, "id") || "<unknown>"

      Enum.reduce(["given", "when", "then"], acc, fn key, inner_acc ->
        case list_field(scenario, key) do
          list when is_list(list) and list != [] ->
            inner_acc

          _ ->
            [
              finding(
                "warning",
                "scenario_missing_#{key}",
                "Scenario #{scenario_id} is missing or has empty #{key}",
                subject_id,
                file
              )
              | inner_acc
            ]
        end
      end)
    end)
  end

  defp add_verification_findings(
         findings,
         verifications,
         claim_ids,
         root,
         subject_id,
         file
       ) do
    Enum.reduce(verifications, findings, fn entry, acc ->
      verification = entry.item

      acc
      |> add_verification_kind_findings(verification, subject_id, file)
      |> add_verification_target_findings(verification, root, subject_id, file)
      |> add_verification_cover_findings(verification, claim_ids, subject_id, file)
      |> add_verification_command_runtime_findings(verification, entry.command_result, subject_id, file)
    end)
  end

  defp add_verification_kind_findings(findings, verification, subject_id, file) do
    kind = string_field(verification, "kind")

    if known_verification_kind?(kind) do
      findings
    else
      [
        finding(
          "error",
          "verification_unknown_kind",
          "Unknown verification kind: #{display_kind(kind)}",
          subject_id,
          file
        )
        | findings
      ]
    end
  end

  defp add_verification_command_runtime_findings(
         findings,
         verification,
         command_result,
         subject_id,
         file
       ) do
    kind = string_field(verification, "kind")
    target = string_field(verification, "target")
    execute? = bool_field(verification, "execute")

    if kind == @command_kind and execute? and target != "" and command_result do
      %{output: output, exit_code: exit_code} = command_result

      if exit_code == 0 do
        findings
      else
        details =
          output
          |> String.trim()
          |> String.slice(0, 1000)

        [
          finding(
            "error",
            "verification_command_failed",
            "Verification command failed: #{target}\n#{details}",
            subject_id,
            file
          )
          | findings
        ]
      end
    else
      findings
    end
  end

  defp add_verification_target_findings(findings, verification, root, subject_id, file) do
    kind = string_field(verification, "kind")
    target = string_field(verification, "target")

    cond do
      kind in @file_kinds and target == "" ->
        [
          finding(
            "error",
            "verification_missing_target",
            "Verification item is missing target path",
            subject_id,
            file
          )
          | findings
        ]

      kind in @file_kinds and not File.exists?(Path.expand(target, root)) ->
        [
          finding(
            "warning",
            "verification_target_missing",
            "Verification target file does not exist: #{target}",
            subject_id,
            file
          )
          | findings
        ]

      kind == "command" and target == "" ->
        [
          finding(
            "error",
            "verification_missing_command",
            "Verification command target is empty",
            subject_id,
            file
          )
          | findings
        ]

      true ->
        findings
    end
  end

  defp add_verification_cover_findings(findings, verification, claim_ids, subject_id, file) do
    covers = list_field(verification, "covers")

    Enum.reduce(covers, findings, fn cover_id, acc ->
      if MapSet.member?(claim_ids, cover_id) do
        acc
      else
        [
          finding(
            "warning",
            "verification_unknown_cover",
            "Verification references unknown claim id: #{cover_id}",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp add_requirement_coverage_findings(
         findings,
         requirement_ids,
         verifications,
         exceptions,
         subject_id,
         file
       ) do
    covered_ids =
      coverage_items(verifications, exceptions)
      |> Enum.flat_map(&list_field(&1, "covers"))
      |> MapSet.new()

    Enum.reduce(requirement_ids, findings, fn req_id, acc ->
      if MapSet.member?(covered_ids, req_id) do
        acc
      else
        [
          finding(
            "warning",
            "requirement_without_verification",
            "Requirement is not referenced by any verification item: #{req_id}",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp build_debug_checks(subjects, root, run_commands?, command_results) do
    subject_checks =
      subjects
      |> Enum.flat_map(&build_subject_debug_checks(&1, root, run_commands?, command_results))

    global_checks =
      []
      |> add_duplicate_subject_debug_checks(subjects)
      |> add_duplicate_requirement_debug_checks(subjects)

    subject_checks ++ global_checks
  end

  defp build_subject_debug_checks(subject, root, run_commands?, command_results) do
    file = string_field(subject, "file")
    meta = subject_meta(subject)
    subject_id = id_of(meta, "id") || file
    requirements = map_items(field(subject, "requirements"))
    scenarios = map_items(field(subject, "scenarios"))
    verifications = verification_entries(subject, subject_id, file, command_results)
    exceptions = map_items(field(subject, "exceptions"))
    parse_errors = list_field(subject, "parse_errors")
    requirement_ids = requirements |> Enum.map(&id_of(&1, "id")) |> Enum.reject(&is_nil/1)
    scenario_ids = scenarios |> Enum.map(&id_of(&1, "id")) |> Enum.reject(&is_nil/1)
    claim_ids = MapSet.new(requirement_ids ++ scenario_ids)

    []
    |> add_meta_debug_checks(meta, subject_id, file)
    |> add_parse_debug_checks(parse_errors, subject_id, file)
    |> add_requirement_id_debug_checks(requirements, subject_id, file)
    |> add_scenario_id_debug_checks(scenarios, subject_id, file)
    |> add_scenario_cover_debug_checks(scenarios, MapSet.new(requirement_ids), subject_id, file)
    |> add_verification_debug_checks(
      verifications,
      claim_ids,
      root,
      subject_id,
      file,
      run_commands?
    )
    |> add_requirement_coverage_debug_checks(
      requirement_ids,
      verifications,
      exceptions,
      subject_id,
      file
    )
  end

  defp add_meta_debug_checks(checks, meta, subject_id, file) do
    required = ["id", "kind", "status"]

    Enum.reduce(required, checks, fn key, acc ->
      if present_string?(meta, key) do
        [
          check("pass", "meta_field_present", "spec-meta field present: #{key}", subject_id, file)
          | acc
        ]
      else
        [
          check(
            "error",
            "meta_field_missing",
            "spec-meta field missing: #{key}",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp add_parse_debug_checks(checks, parse_errors, subject_id, file) do
    if parse_errors == [] do
      [
        check(
          "pass",
          "parse_blocks",
          "Structured spec blocks parsed successfully",
          subject_id,
          file
        )
        | checks
      ]
    else
      Enum.reduce(parse_errors, checks, fn message, acc ->
        [check("error", "parse_blocks", message, subject_id, file) | acc]
      end)
    end
  end

  defp add_requirement_id_debug_checks(checks, requirements, subject_id, file) do
    Enum.reduce(requirements, checks, fn requirement, acc ->
      case string_field(requirement, "id") do
        id when is_binary(id) and id != "" ->
          [
            check(
              "pass",
              "requirement_id_present",
              "Requirement id present: #{id}",
              subject_id,
              file
            )
            | acc
          ]

        _ ->
          [
            check(
              "error",
              "requirement_id_missing",
              "Requirement entry missing id",
              subject_id,
              file
            )
            | acc
          ]
      end
    end)
  end

  defp add_scenario_id_debug_checks(checks, scenarios, subject_id, file) do
    Enum.reduce(scenarios, checks, fn scenario, acc ->
      case string_field(scenario, "id") do
        id when is_binary(id) and id != "" ->
          [
            check("pass", "scenario_id_present", "Scenario id present: #{id}", subject_id, file)
            | acc
          ]

        _ ->
          [
            check("error", "scenario_id_missing", "Scenario entry missing id", subject_id, file)
            | acc
          ]
      end
    end)
  end

  defp add_scenario_cover_debug_checks(checks, scenarios, requirement_ids, subject_id, file) do
    Enum.reduce(scenarios, checks, fn scenario, acc ->
      covers = list_field(scenario, "covers")
      scenario_id = id_of(scenario, "id") || "<unknown>"

      Enum.reduce(covers, acc, fn cover_id, cover_acc ->
        if MapSet.member?(requirement_ids, cover_id) do
          [
            check(
              "pass",
              "scenario_cover_valid",
              "Scenario #{scenario_id} covers known requirement: #{cover_id}",
              subject_id,
              file
            )
            | cover_acc
          ]
        else
          [
            check(
              "warning",
              "scenario_cover_unknown",
              "Scenario #{scenario_id} covers unknown requirement: #{cover_id}",
              subject_id,
              file
            )
            | cover_acc
          ]
        end
      end)
    end)
  end

  defp add_verification_debug_checks(
         checks,
         verifications,
         claim_ids,
         root,
         subject_id,
         file,
         run_commands?
       ) do
    Enum.reduce(verifications, checks, fn entry, acc ->
      verification = entry.item
      kind = string_field(verification, "kind")
      target = string_field(verification, "target")
      covers = list_field(verification, "covers")
      execute? = bool_field(verification, "execute")
      command_result = entry.command_result

      acc =
        cond do
          not known_verification_kind?(kind) ->
            [
              check(
                "error",
                "verification_kind_invalid",
                "Unknown verification kind: #{display_kind(kind)}",
                subject_id,
                file
              )
              | acc
            ]

          kind in @file_kinds and target == "" ->
            [
              check(
                "error",
                "verification_target_missing",
                "Verification target path missing",
                subject_id,
                file
              )
              | acc
            ]

          kind in @file_kinds and File.exists?(Path.expand(target, root)) ->
            [
              check(
                "pass",
                "verification_target_exists",
                "Verification file exists: #{target}",
                subject_id,
                file
              )
              | acc
            ]

          kind in @file_kinds ->
            [
              check(
                "warning",
                "verification_target_missing_file",
                "Verification file not found: #{target}",
                subject_id,
                file
              )
              | acc
            ]

          kind == @command_kind and target == "" ->
            [
              check(
                "error",
                "verification_command_missing",
                "Verification command is empty",
                subject_id,
                file
              )
              | acc
            ]

          kind == @command_kind and run_commands? and execute? and command_result ->
            %{output: output, exit_code: exit_code} = command_result

            if exit_code == 0 do
              [
                check(
                  "pass",
                  "verification_command_passed",
                  "Verification command passed: #{target}",
                  subject_id,
                  file
                )
                | acc
              ]
            else
              details =
                output
                |> String.trim()
                |> String.slice(0, 300)

              [
                check(
                  "error",
                  "verification_command_failed",
                  "Verification command failed: #{target} #{details}",
                  subject_id,
                  file
                )
                | acc
              ]
            end

          kind == @command_kind and run_commands? and not execute? ->
            [
              check(
                "pass",
                "verification_command_skipped",
                "Verification command not executed (set execute=true to run): #{target}",
                subject_id,
                file
              )
              | acc
            ]

          kind == @command_kind ->
            [
              check(
                "pass",
                "verification_command_present",
                "Verification command present: #{target}",
                subject_id,
                file
              )
              | acc
            ]

          true ->
            [
              check(
                "pass",
                "verification_kind_seen",
                "Verification kind seen: #{kind}",
                subject_id,
                file
              )
              | acc
            ]
        end

      Enum.reduce(covers, acc, fn cover_id, cover_acc ->
        if MapSet.member?(claim_ids, cover_id) do
          [
            check(
              "pass",
              "verification_cover_valid",
              "Verification covers known claim: #{cover_id}",
              subject_id,
              file
            )
            | cover_acc
          ]
        else
          [
            check(
              "warning",
              "verification_cover_unknown",
              "Verification covers unknown claim: #{cover_id}",
              subject_id,
              file
            )
            | cover_acc
          ]
        end
      end)
    end)
  end

  defp add_requirement_coverage_debug_checks(
         checks,
         requirement_ids,
         verifications,
         exceptions,
         subject_id,
         file
       ) do
    covered_ids =
      coverage_items(verifications, exceptions)
      |> Enum.flat_map(&list_field(&1, "covers"))
      |> MapSet.new()

    Enum.reduce(requirement_ids, checks, fn req_id, acc ->
      if MapSet.member?(covered_ids, req_id) do
        [
          check(
            "pass",
            "requirement_has_verification",
            "Requirement has verification: #{req_id}",
            subject_id,
            file
          )
          | acc
        ]
      else
        [
          check(
            "warning",
            "requirement_missing_verification",
            "Requirement missing verification coverage: #{req_id}",
            subject_id,
            file
          )
          | acc
        ]
      end
    end)
  end

  defp add_duplicate_subject_debug_checks(checks, subjects) do
    duplicates =
      subjects
      |> Enum.map(fn subject -> subject |> subject_meta() |> id_of("id") end)
      |> Enum.reject(&is_nil/1)
      |> duplicates()

    if duplicates == [] do
      [check("pass", "duplicate_subject_id", "No duplicate subject ids", nil, nil) | checks]
    else
      Enum.reduce(duplicates, checks, fn id, acc ->
        [check("error", "duplicate_subject_id", "Duplicate subject id: #{id}", id, nil) | acc]
      end)
    end
  end

  defp add_duplicate_requirement_debug_checks(checks, subjects) do
    duplicates =
      subjects
      |> Enum.flat_map(fn subject -> list_field(subject, "requirements") end)
      |> Enum.map(&id_of(&1, "id"))
      |> Enum.reject(&is_nil/1)
      |> duplicates()

    if duplicates == [] do
      [
        check("pass", "duplicate_requirement_id", "No duplicate requirement ids", nil, nil)
        | checks
      ]
    else
      Enum.reduce(duplicates, checks, fn id, acc ->
        [
          check("error", "duplicate_requirement_id", "Duplicate requirement id: #{id}", nil, nil)
          | acc
        ]
      end)
    end
  end

  defp duplicate_subject_id_findings(subjects) do
    subjects
    |> Enum.map(fn subject -> subject |> subject_meta() |> id_of("id") end)
    |> Enum.reject(&is_nil/1)
    |> duplicates()
    |> Enum.map(fn id ->
      finding("error", "duplicate_subject_id", "Duplicate subject id: #{id}", id, nil)
    end)
  end

  defp duplicate_requirement_id_findings(subjects) do
    subjects
    |> Enum.flat_map(fn subject -> list_field(subject, "requirements") end)
    |> Enum.map(&id_of(&1, "id"))
    |> Enum.reject(&is_nil/1)
    |> duplicates()
    |> Enum.map(fn id ->
      finding("error", "duplicate_requirement_id", "Duplicate requirement id: #{id}", nil, nil)
    end)
  end

  defp duplicate_scenario_id_findings(subjects) do
    subjects
    |> Enum.flat_map(fn subject -> list_field(subject, "scenarios") end)
    |> Enum.map(&id_of(&1, "id"))
    |> Enum.reject(&is_nil/1)
    |> duplicates()
    |> Enum.map(fn id ->
      finding("error", "duplicate_scenario_id", "Duplicate scenario id: #{id}", nil, nil)
    end)
  end

  defp duplicate_exception_id_findings(subjects) do
    subjects
    |> Enum.flat_map(fn subject -> list_field(subject, "exceptions") end)
    |> Enum.map(&id_of(&1, "id"))
    |> Enum.reject(&is_nil/1)
    |> duplicates()
    |> Enum.map(fn id ->
      finding("error", "duplicate_exception_id", "Duplicate exception id: #{id}", nil, nil)
    end)
  end

  defp invalid_id_format_findings(subjects) do
    Enum.flat_map(subjects, fn subject ->
      meta = subject_meta(subject)
      subject_id = id_of(meta, "id")
      file = string_field(subject, "file")

      all_ids =
        [{subject_id, "subject"}] ++
          ids_from(field(subject, "requirements"), "requirement") ++
          ids_from(field(subject, "scenarios"), "scenario") ++
          ids_from(field(subject, "exceptions"), "exception")

      all_ids
      |> Enum.reject(fn {id, _kind} -> is_nil(id) end)
      |> Enum.reject(fn {id, _kind} -> Regex.match?(@id_pattern, id) end)
      |> Enum.map(fn {id, kind} ->
        finding(
          "error",
          "invalid_id_format",
          "Invalid #{kind} id format: #{id} (must match #{inspect(Regex.source(@id_pattern))})",
          subject_id,
          file
        )
      end)
    end)
  end

  defp ids_from(items, kind) when is_list(items) do
    Enum.map(items, fn item -> {id_of(item, "id"), kind} end)
  end

  defp ids_from(_, _kind), do: []

  defp build_command_results(_subjects, _root, false), do: %{}

  defp build_command_results(subjects, root, true) do
    Enum.reduce(subjects, %{}, fn subject, acc ->
      file = string_field(subject, "file")
      meta = subject_meta(subject)
      subject_id = id_of(meta, "id") || file

      subject
      |> field("verification")
      |> map_items()
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {verification, idx}, inner_acc ->
        case command_result(verification, root) do
          nil -> inner_acc
          result -> Map.put(inner_acc, verification_key(subject_id, file, idx), result)
        end
      end)
    end)
  end

  defp command_result(verification, root) do
    if runnable_command_verification?(verification) do
      target = string_field(verification, "target")
      {output, exit_code} = System.cmd("sh", ["-lc", target], cd: root, stderr_to_stdout: true)
      %{output: output, exit_code: exit_code}
    end
  end

  defp verification_entries(subject, subject_id, file, command_results) do
    subject
    |> field("verification")
    |> map_items()
    |> Enum.with_index()
    |> Enum.map(fn {verification, idx} ->
      %{
        index: idx,
        item: verification,
        command_result: Map.get(command_results, verification_key(subject_id, file, idx))
      }
    end)
  end

  defp verification_key(subject_id, file, idx), do: {subject_id, file, idx}

  defp coverage_counting_verification?(verification) do
    known_verification_kind?(string_field(verification, "kind"))
  end

  defp runnable_command_verification?(verification) do
    kind = string_field(verification, "kind")
    target = string_field(verification, "target")
    execute? = bool_field(verification, "execute")

    kind == @command_kind and execute? and target != "" and valid_covers_field?(verification)
  end

  defp valid_covers_field?(verification) do
    case field(verification, "covers") do
      covers when is_list(covers) -> Enum.all?(covers, &is_binary/1)
      _ -> false
    end
  end

  defp coverage_items(verifications, exceptions) do
    verifications
    |> Enum.filter(&coverage_counting_verification?(&1.item))
    |> Enum.map(& &1.item)
    |> Kernel.++(exceptions)
  end

  defp map_items(items) when is_list(items), do: Enum.filter(items, &is_map/1)
  defp map_items(_items), do: []

  defp list_field(item, key) when is_map(item) do
    case field(item, key) do
      value when is_list(value) -> value
      _ -> []
    end
  end

  defp list_field(_item, _key), do: []

  defp string_field(item, key) when is_map(item) do
    case field(item, key) do
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp string_field(_item, _key), do: ""

  defp bool_field(item, key) when is_map(item), do: field(item, key) == true
  defp bool_field(_item, _key), do: false

  defp known_verification_kind?(kind), do: kind in @known_verification_kinds

  defp display_kind(""), do: "<empty>"
  defp display_kind(kind), do: kind

  defp present_string?(item, key) do
    case string_field(item, key) do
      "" -> false
      value -> String.trim(value) != ""
    end
  end

  defp subject_meta(subject) when is_map(subject) do
    case field(subject, "meta") do
      meta when is_map(meta) -> meta
      _ -> %{}
    end
  end

  defp subject_meta(_subject), do: %{}

  defp duplicates(values) do
    values
    |> Enum.frequencies()
    |> Enum.filter(fn {_value, count} -> count > 1 end)
    |> Enum.map(fn {value, _count} -> value end)
  end

  defp id_of(item, key) when is_map(item) do
    case field(item, key) do
      id when is_binary(id) and id != "" -> id
      _ -> nil
    end
  end

  defp id_of(_item, _key), do: nil

  defp field(item, key) when is_map(item) and is_binary(key) do
    atom_key =
      try do
        String.to_existing_atom(key)
      rescue
        ArgumentError -> nil
      end

    Map.get(item, key, if(atom_key, do: Map.get(item, atom_key)))
  end

  defp field(_item, _key), do: nil

  defp finding(severity, code, message, subject_id, file) do
    %{
      "severity" => severity,
      "code" => code,
      "message" => message,
      "subject_id" => subject_id,
      "file" => file
    }
  end

  defp check(status, code, message, subject_id, file) do
    %{
      "status" => status,
      "code" => code,
      "message" => message,
      "subject_id" => subject_id,
      "file" => file
    }
  end
end
