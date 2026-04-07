defmodule Mix.Tasks.Spec.Status do
  use Mix.Task

  alias SpecLedEx.VerificationStrength

  @shortdoc "Summarizes current-truth coverage, proof strength, and frontier gaps"
  @moduledoc """
  Summarizes current-truth spec coverage, verification strength, and ADR usage.

  `mix spec.status` executes eligible `kind: command` verifications by default so
  the summary reflects the same proof strength a maintainer usually cares about.
  Use `--no-run-commands` to force a structural-only report for a given run.
  """

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [
          root: :string,
          spec_dir: :string,
          run_commands: :boolean,
          min_strength: :string,
          json: :boolean
        ],
        aliases: [r: :root]
      )

    validate_args!(rest, invalid)

    root = opts[:root] || File.cwd!()
    spec_dir = opts[:spec_dir] || SpecLedEx.detect_spec_dir(root)
    authored_dir = SpecLedEx.detect_authored_dir(root, spec_dir)
    index = SpecLedEx.index(root, spec_dir: spec_dir, authored_dir: authored_dir)

    verification_report =
      SpecLedEx.validate(index, root,
        run_commands: report_run_commands?(opts),
        min_strength: validate_min_strength!(opts[:min_strength])
      )

    report = SpecLedEx.status(index, verification_report, root)

    if opts[:json] do
      Mix.shell().info(Jason.encode!(report, pretty: true))
    else
      Mix.shell().info(SpecLedEx.Status.format_human(report))
    end
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.status: #{details}")
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

  defp report_run_commands?(opts) do
    case Keyword.fetch(opts, :run_commands) do
      {:ok, false} -> false
      _ -> true
    end
  end
end
