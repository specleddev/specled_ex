defmodule Mix.Tasks.Spec.Next do
  use Mix.Task

  @shortdoc "Guides the next current-truth update for the current Git change set"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [root: :string, spec_dir: :string, base: :string, bugfix: :boolean],
        aliases: [r: :root]
      )

    validate_args!(rest, invalid)

    root = opts[:root] || File.cwd!()
    spec_dir = opts[:spec_dir] || SpecLedEx.detect_spec_dir(root)
    authored_dir = SpecLedEx.detect_authored_dir(root, spec_dir)
    index = SpecLedEx.index(root, spec_dir: spec_dir, authored_dir: authored_dir)
    report = SpecLedEx.next(index, root, base: opts[:base], bugfix: opts[:bugfix])

    Mix.shell().info(SpecLedEx.Next.format_human(report))
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.next: #{details}")
  end
end
