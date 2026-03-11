defmodule Mix.Tasks.Spec.Verify do
  use Mix.Task

  @shortdoc "Validates authored specs and writes .spec/state.json"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, invalid} =
      OptionParser.parse(
        args,
        strict: [
          root: :string,
          output: :string,
          strict: :boolean,
          debug: :boolean,
          run_commands: :boolean,
          spec_dir: :string
        ],
        aliases: [r: :root, o: :output, s: :strict, d: :debug]
      )

    validate_args!(rest, invalid)

    root = opts[:root] || File.cwd!()
    spec_dir = opts[:spec_dir] || SpecLedEx.detect_spec_dir(root)
    authored_dir = SpecLedEx.detect_authored_dir(root, spec_dir)
    output = opts[:output] || "#{spec_dir}/state.json"
    strict? = opts[:strict] || false
    debug? = opts[:debug] || false
    run_commands? = opts[:run_commands] || false

    index = SpecLedEx.build_index(root, spec_dir: spec_dir, authored_dir: authored_dir)

    report =
      SpecLedEx.verify(index, root, strict: strict?, debug: debug?, run_commands: run_commands?)

    path = SpecLedEx.write_state(index, report, root, output)

    Mix.shell().info("spec.verify wrote #{path}")

    summary = report["summary"]

    Mix.shell().info(
      "status=#{report["status"]} errors=#{summary["errors"]} warnings=#{summary["warnings"]}"
    )

    if debug? do
      checks = report["checks"] || []
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

    if report["status"] == "fail" do
      Enum.each(report["findings"] || [], fn finding ->
        severity = String.upcase(finding["severity"] || "warning")
        subject_id = finding["subject_id"] || "global"
        file = finding["file"] || "-"
        code = finding["code"] || "finding"
        message = finding["message"] || ""
        Mix.shell().info("[#{severity}] #{subject_id} #{code} #{file} :: #{message}")
      end)

      Mix.raise("Spec verify failed: #{length(report["findings"] || [])} finding(s)")
    end
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(rest, invalid) do
    invalid_flags = Enum.map(invalid, fn {flag, _value} -> flag end)
    extra_args = Enum.map(rest, &inspect/1)
    details = Enum.join(invalid_flags ++ extra_args, ", ")
    Mix.raise("Invalid arguments for spec.verify: #{details}")
  end
end
