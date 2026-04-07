defmodule Mix.Tasks.Spec.Prime do
  use Mix.Task

  alias SpecLedEx.VerificationStrength

  @shortdoc "Prints session-start context for agents and maintainers"
  @moduledoc """
  Combines workspace status, current-branch guidance, and the default local loop.

  `mix spec.prime` is read-only. It does not write `.spec/state.json` or edit
  current-truth files. Command verifications stay structural-only by default;
  pass `--run-commands` when you want executed proof in the embedded status
  summary.
  """

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [
          root: :string,
          spec_dir: :string,
          base: :string,
          since: :string,
          bugfix: :boolean,
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
        run_commands: run_commands?(opts),
        min_strength: validate_min_strength!(opts[:min_strength])
      )

    report =
      SpecLedEx.prime(index, verification_report, root,
        base: opts[:base],
        since: opts[:since],
        bugfix: opts[:bugfix],
        run_commands: run_commands?(opts)
      )

    if opts[:json] do
      Mix.shell().info(Jason.encode!(report, pretty: true))
    else
      Mix.shell().info(SpecLedEx.Prime.format_human(report))
    end
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.prime: #{details}")
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

  defp run_commands?(opts) do
    case Keyword.fetch(opts, :run_commands) do
      {:ok, value} -> value
      :error -> false
    end
  end
end
