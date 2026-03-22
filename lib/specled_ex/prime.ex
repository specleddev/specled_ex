defmodule SpecLedEx.Prime do
  @moduledoc false

  alias SpecLedEx.{Next, Status}

  def build(index, verification_report, root, opts \\ []) do
    run_commands? = opts[:run_commands] == true
    bugfix? = opts[:bugfix] == true
    status_report = Status.build(index, verification_report, root)
    next_report = Next.run(index, root, base: opts[:base], bugfix: bugfix?)

    %{
      "generated_at" => status_report["generated_at"],
      "summary" => %{
        "purpose" => "session_start_context",
        "run_commands" => run_commands?,
        "bugfix" => bugfix?
      },
      "status" => status_report,
      "next" => next_report,
      "loop" => %{
        "steps" => default_loop(next_report["base"], bugfix?)
      }
    }
  end

  def format_human(report) do
    summary = report["summary"] || %{}

    lines =
      [
        "Spec Led Prime",
        "purpose=#{purpose_label(summary["purpose"])} run_commands=#{summary["run_commands"] || false} bugfix=#{summary["bugfix"] || false}",
        "",
        "Status"
      ] ++
        section_lines(Status.format_human(report["status"] || %{}), "Spec Led Status") ++
        [
          "",
          "Next"
        ] ++
        section_lines(Next.format_human(report["next"] || %{}), "Spec Led Next") ++
        [
          "",
          "Loop"
        ] ++ Enum.map(loop_steps(report), &"* #{&1}")

    Enum.join(lines, "\n")
  end

  defp loop_steps(report) do
    get_in(report, ["loop", "steps"]) || default_loop(nil, false)
  end

  defp default_loop(base, true) do
    [
      "Read `.spec/README.md` and `.spec/decisions/README.md` before editing current truth.",
      "Make the smallest change and keep the regression proof in place.",
      "Run `mix spec.next --bugfix` after code, docs, or tests change.",
      "If next says `needs subject updates`, update the named subject before you finish.",
      "If next says `needs decision update`, revise ADRs only when the rule is durable and cross-cutting.",
      "When next says `ready for check`, run `#{check_command(base)}`."
    ]
  end

  defp default_loop(base, false) do
    [
      "Read `.spec/README.md` and `.spec/decisions/README.md` before editing current truth.",
      "Make the smallest change and tighten the smallest proof that matters.",
      "Run `mix spec.next` after code, docs, or tests change.",
      "If next says `needs subject updates`, update the named subject before you finish.",
      "If next says `needs decision update`, revise ADRs only when the rule is durable and cross-cutting.",
      "When next says `ready for check`, run `#{check_command(base)}`."
    ]
  end

  defp check_command(nil), do: "mix spec.check"
  defp check_command(base), do: "mix spec.check --base #{base}"

  defp purpose_label("session_start_context"), do: "session-start context"
  defp purpose_label(nil), do: "session-start context"
  defp purpose_label(value), do: value

  defp section_lines(text, header) do
    text
    |> String.split("\n")
    |> drop_header(header)
  end

  defp drop_header([header | rest], header), do: rest
  defp drop_header(lines, _header), do: lines
end
