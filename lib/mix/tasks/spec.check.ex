defmodule Mix.Tasks.Spec.Check do
  use Mix.Task

  alias SpecLedEx.VerificationStrength

  @shortdoc "Runs the full local Spec Led gate"
  @moduledoc """
  Runs `mix spec.index`, strict `mix spec.validate`, and the branch guard in one command.

  `mix spec.check` enables command execution by default. Use `--no-run-commands`
  to keep command verifications structural-only for a given run.

  ## Options

    * `--no-run-commands` - skip executing `kind: command` verifications
    * `--min-strength claimed|linked|executed` - require a minimum verification strength
    * `--base <ref>` - compare the current branch against the given Git base
  """

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [
          root: :string,
          output: :string,
          spec_dir: :string,
          debug: :boolean,
          run_commands: :boolean,
          base: :string,
          min_strength: :string
        ],
        aliases: [r: :root, o: :output, d: :debug]
      )

    validate_args!(rest, invalid)

    min_strength = validate_min_strength!(opts[:min_strength])
    root = opts[:root] || File.cwd!()
    spec_dir = opts[:spec_dir] || SpecLedEx.detect_spec_dir(root)
    authored_dir = SpecLedEx.detect_authored_dir(root, spec_dir)
    output = opts[:output] || "#{spec_dir}/state.json"
    debug? = opts[:debug] || false
    run_commands? = run_commands?(opts)

    index = SpecLedEx.index(root, spec_dir: spec_dir, authored_dir: authored_dir)
    path = SpecLedEx.write_state(index, nil, root, output)
    Mix.shell().info("spec.index wrote #{path}")

    Mix.shell().info(
      "authored_dir=#{index["authored_dir"]} subjects=#{index["summary"]["subjects"]} requirements=#{index["summary"]["requirements"]}"
    )

    report =
      SpecLedEx.validate(index, root,
        strict: true,
        debug: debug?,
        run_commands: run_commands?,
        min_strength: min_strength
      )

    path = SpecLedEx.write_state(index, report, root, output)
    Mix.shell().info("spec.validate wrote #{path}")

    summary = report["summary"]

    Mix.shell().info(
      "status=#{report["status"]} errors=#{summary["errors"]} warnings=#{summary["warnings"]}"
    )

    if debug? do
      print_debug_checks(report["checks"] || [])
    end

    if report["status"] == "fail" do
      print_validation_findings(report["findings"] || [])
      Mix.raise("Spec check failed: #{length(report["findings"] || [])} validation finding(s)")
    end

    branch_report = SpecLedEx.branch_check(index, root, base: opts[:base])
    print_branch_report(branch_report)

    if branch_report["status"] == "fail" do
      Mix.raise("Spec check failed: #{length(branch_report["findings"] || [])} branch finding(s)")
    end
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.check: #{details}")
  end

  defp run_commands?(opts) do
    case Keyword.fetch(opts, :run_commands) do
      {:ok, false} -> false
      _ -> true
    end
  end

  defp print_debug_checks(checks) do
    Mix.shell().info("debug_checks=#{length(checks)}")

    Enum.each(checks, fn check ->
      status = String.upcase(check["status"] || "pass")
      subject_id = check["subject_id"] || "global"
      file = check["file"] || "-"
      code = check["code"] || "check"
      message = check["message"] || ""
      Mix.shell().info("[#{status}] #{subject_id} #{code} #{file} :: #{message}")
    end)
  end

  defp print_validation_findings(findings) do
    Enum.each(findings, fn finding ->
      severity = String.upcase(finding["severity"] || "warning")
      subject_id = finding["subject_id"] || "global"
      file = finding["file"] || "-"
      code = finding["code"] || "finding"
      message = finding["message"] || ""
      Mix.shell().info("[#{severity}] #{subject_id} #{code} #{file} :: #{message}")
    end)
  end

  defp print_branch_report(report) do
    Mix.shell().info(
      "branch base=#{report["base"]} changed_files=#{report["summary"]["changed_files"]} findings=#{report["summary"]["findings"]}"
    )

    Enum.each(report["findings"] || [], fn finding ->
      severity = String.upcase(finding["severity"] || "warning")
      file = finding["file"] || "-"
      Mix.shell().info("[#{severity}] #{finding["code"]} #{file} :: #{finding["message"]}")
    end)

    guidance = report["guidance"] || %{}
    impacted_subjects = guidance["impacted_subject_ids"] || []
    uncovered_policy_files = guidance["uncovered_policy_files"] || []

    Mix.shell().info("branch change_type=#{guidance["change_type"] || "non_contract_or_meta"}")
    Mix.shell().info("branch impacted_subjects=#{Enum.join(impacted_subjects, ", ")}")

    Mix.shell().info("branch uncovered_policy_files=#{Enum.join(uncovered_policy_files, ", ")}")

    Mix.shell().info("branch next=#{guidance["suggested_command"]}")
  end

  defp validate_min_strength!(nil), do: nil

  defp validate_min_strength!(value) do
    case VerificationStrength.normalize(value) do
      {:ok, normalized} ->
        normalized

      {:error, message} ->
        Mix.raise("Invalid value for --min-strength: #{message}")
    end
  end
end
