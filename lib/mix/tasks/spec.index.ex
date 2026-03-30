defmodule Mix.Tasks.Spec.Index do
  use Mix.Task
  @requirements ["loadpaths"]

  @shortdoc "Builds index state and writes .spec/state.json"

  @impl true
  def run(args) do
    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [root: :string, output: :string, spec_dir: :string],
        aliases: [r: :root, o: :output]
      )

    validate_args!(rest, invalid)

    root = opts[:root] || File.cwd!()
    spec_dir = opts[:spec_dir] || SpecLedEx.detect_spec_dir(root)
    authored_dir = SpecLedEx.detect_authored_dir(root, spec_dir)
    output = opts[:output] || "#{spec_dir}/state.json"

    index = SpecLedEx.index(root, spec_dir: spec_dir, authored_dir: authored_dir)
    path = SpecLedEx.write_state(index, nil, root, output)

    Mix.shell().info("spec.index wrote #{path}")

    Mix.shell().info(
      "authored_dir=#{index["authored_dir"]} subjects=#{index["summary"]["subjects"]} requirements=#{index["summary"]["requirements"]}"
    )
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.index: #{details}")
  end
end
