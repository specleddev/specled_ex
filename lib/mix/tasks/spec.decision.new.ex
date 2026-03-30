defmodule Mix.Tasks.Spec.Decision.New do
  use Mix.Task
  @requirements ["loadpaths"]

  @shortdoc "Scaffolds a decision ADR under .spec/decisions"
  @id_pattern ~r/^[a-z0-9][a-z0-9._-]*$/

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [root: :string, title: :string, force: :boolean],
        aliases: [r: :root, f: :force]
      )

    validate_args!(rest, invalid)

    [decision_id] = rest
    validate_decision_id!(decision_id)

    root = opts[:root] || File.cwd!()
    title = opts[:title] || humanize(decision_id)
    force? = opts[:force] || false
    spec_dir = SpecLedEx.detect_spec_dir(root)
    decision_dir = SpecLedEx.Index.detect_decision_dir(root, spec_dir)
    path = Path.join(root, Path.join(decision_dir, "#{decision_id}.md"))
    content = render_decision(decision_id, title)

    cond do
      File.exists?(path) and not force? ->
        Mix.raise("Decision already exists: #{path}")

      true ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, content)
        Mix.shell().info("spec.decision.new wrote #{path}")
    end
  end

  defp render_decision(decision_id, title) do
    """
    ---
    id: #{decision_id}
    status: accepted
    date: #{Date.utc_today()}
    affects:
      - repo.governance
    ---

    # #{title}

    ## Context

    Explain the cross-cutting problem or policy.

    ## Decision

    State the durable decision.

    ## Consequences

    Explain the expected tradeoffs and follow-on constraints.
    """
  end

  defp validate_args!([_decision_id], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.drop(rest, 1) |> Enum.map(&inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")

    if details == "" do
      Mix.raise("spec.decision.new requires exactly one DECISION_ID argument")
    else
      Mix.raise("Invalid arguments for spec.decision.new: #{details}")
    end
  end

  defp validate_decision_id!(decision_id) do
    unless Regex.match?(@id_pattern, decision_id) do
      Mix.raise("Invalid DECISION_ID: #{decision_id}")
    end
  end

  defp humanize(value) do
    value
    |> String.replace(~r/[._-]+/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
