defmodule Mix.Tasks.SpecReportTaskTest do
  use SpecLedEx.Case

  test "spec.report executes commands by default and allows opting out", %{root: root} do
    write_subject_spec(
      root,
      "report_commands",
      meta: %{"id" => "report.commands", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "report.commands.requirement", "statement" => "Covered by command"}],
      verification: [
        %{
          "kind" => "command",
          "target" => "printf reported >> reported.txt",
          "covers" => ["report.commands.requirement"],
          "execute" => true
        }
      ]
    )

    Mix.Tasks.Spec.Report.run(["--root", root])

    assert File.read!(Path.join(root, "reported.txt")) == "reported"

    File.rm!(Path.join(root, "reported.txt"))
    reenable_tasks(["spec.report"])

    Mix.Tasks.Spec.Report.run(["--root", root, "--no-run-commands"])

    refute File.exists?(Path.join(root, "reported.txt"))
  end
end
