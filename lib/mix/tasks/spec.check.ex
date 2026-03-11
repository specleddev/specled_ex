defmodule Mix.Tasks.Spec.Check do
  use Mix.Task

  @shortdoc "Runs spec.plan and strict spec.verify"

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
          run_commands: :boolean
        ],
        aliases: [r: :root, o: :output, d: :debug]
      )

    validate_args!(rest, invalid)

    shared_args = option_args(opts, [:root, :output, :spec_dir])
    verify_args = shared_args ++ option_args(opts, [:debug, :run_commands]) ++ ["--strict"]

    Mix.Task.run("spec.plan", shared_args)
    Mix.Task.run("spec.verify", verify_args)
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.check: #{details}")
  end

  defp option_args(opts, keys) do
    Enum.flat_map(keys, fn key ->
      case Keyword.get(opts, key) do
        true -> ["--#{option_name(key)}"]
        false -> []
        nil -> []
        value -> ["--#{option_name(key)}", value]
      end
    end)
  end

  defp option_name(key) do
    key
    |> Atom.to_string()
    |> String.replace("_", "-")
  end
end
