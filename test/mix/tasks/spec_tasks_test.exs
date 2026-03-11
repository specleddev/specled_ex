defmodule Mix.Tasks.SpecTasksTest do
  use SpecLedEx.Case

  test "spec.init scaffolds files, keeps existing content, and overwrites with force", %{
    root: root
  } do
    answer_shell_yes(false, 3)

    Mix.Tasks.Spec.Init.run(["--root", root])

    readme = Path.join(root, ".spec/README.md")
    agents = Path.join(root, ".spec/AGENTS.md")
    package_spec = Path.join(root, ".spec/specs/package.spec.md")

    assert File.exists?(readme)
    assert File.exists?(agents)
    assert File.exists?(package_spec)
    assert File.read!(readme) == render_spec_init_template("README.md.eex")
    assert File.read!(agents) == render_spec_init_template("AGENTS.md.eex")

    File.write!(agents, "# Custom Spec Agents\n")
    File.write!(package_spec, "# Custom Package Spec\n")

    Mix.Tasks.Spec.Init.run(["--root", root])
    assert File.read!(agents) == "# Custom Spec Agents\n"
    assert File.read!(package_spec) == "# Custom Package Spec\n"

    Mix.Tasks.Spec.Init.run(["--root", root, "--force"])
    assert File.read!(agents) == render_spec_init_template("AGENTS.md.eex")
    assert File.read!(package_spec) == render_spec_init_template("specs/package.spec.md.eex")

    messages = drain_shell_messages()

    assert message_contains?(messages, "spec.init scaffolded")
    assert message_contains?(messages, "kept")
    assert message_contains?(messages, "wrote")
  end

  @tag :spec_init_local_skill
  test "spec.init scaffolds the local Skill when accepted", %{root: root} do
    answer_shell_yes(true)

    Mix.Tasks.Spec.Init.run(["--root", root])

    skill_path = Path.join(root, ".agents/skills/spec-led-development/SKILL.md")
    messages = drain_shell_messages()

    assert File.exists?(skill_path)

    assert File.read!(skill_path) ==
             render_spec_init_template("agents/skills/spec-led-development/SKILL.md.eex")

    assert message_contains?(messages, "Add a local Skill to help with Spec Led Development?")
    assert message_contains?(messages, "wrote #{skill_path}")
  end

  test "spec.init skips the local Skill when declined", %{root: root} do
    answer_shell_yes(false)

    Mix.Tasks.Spec.Init.run(["--root", root])

    refute File.exists?(Path.join(root, ".agents/skills/spec-led-development/SKILL.md"))
  end

  test "spec.init scaffold passes spec.check", %{root: root} do
    answer_shell_yes(false)

    Mix.Tasks.Spec.Init.run(["--root", root])

    drain_shell_messages()
    reenable_tasks()

    Mix.Tasks.Spec.Check.run(["--root", root])

    assert read_state(root)["summary"]["findings"] == 0
  end

  test "spec.plan writes state for malformed specs without crashing", %{root: root} do
    write_spec(
      root,
      "malformed",
      """
      # Malformed

      ```spec-meta
      id: malformed.subject
      kind: module
      status: active
      ```

      ```spec-requirements
      - just-a-string
      ```
      """
    )

    Mix.Tasks.Spec.Plan.run(["--root", root])

    state = read_state(root)
    messages = drain_shell_messages()

    assert state["workspace"]["spec_count"] == 1
    assert state["index"]["requirements"] == []
    assert message_contains?(messages, "spec.plan wrote")
    assert message_contains?(messages, "subjects=1")
  end

  test "spec.plan supports absolute spec_dir paths", %{root: root} do
    abs_spec_dir = Path.join(root, "custom_spec")

    write_subject_spec(
      root,
      "../../custom_spec/specs/absolute",
      title: "Absolute",
      meta: %{"id" => "absolute.subject", "kind" => "module", "status" => "active"}
    )

    Mix.Tasks.Spec.Plan.run(["--root", root, "--spec-dir", abs_spec_dir])

    state = read_state(root, Path.join(abs_spec_dir, "state.json"))

    assert state["workspace"]["spec_count"] == 1
    assert state["index"]["subjects"] |> Enum.map(& &1["id"]) == ["absolute.subject"]
  end

  test "spec.verify writes state and exits non-zero when the report fails", %{root: root} do
    write_subject_spec(
      root,
      "warning",
      meta: %{"id" => "warning.subject", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "warning.requirement", "statement" => "Needs coverage"}]
    )

    assert_raise Mix.Error, ~r/Spec verify failed: 1 finding/, fn ->
      Mix.Tasks.Spec.Verify.run(["--root", root, "--strict"])
    end

    state = read_state(root)
    messages = drain_shell_messages()

    assert [%{"code" => "requirement_without_verification", "entity_id" => "warning.subject"}] =
             state["findings"]

    assert message_contains?(messages, "spec.verify wrote")
    assert message_contains?(messages, "status=fail errors=0 warnings=1")

    assert message_contains?(
             messages,
             "[WARNING] warning.subject requirement_without_verification"
           )
  end

  test "spec.verify rejects invalid CLI options", %{root: root} do
    assert_raise Mix.Error, ~r/Invalid arguments for spec.verify: --strcit/, fn ->
      Mix.Tasks.Spec.Verify.run(["--root", root, "--strcit"])
    end
  end

  test "spec.verify does not execute malformed command verifications", %{root: root} do
    write_spec(
      root,
      "malformed_command",
      """
      # Malformed Command

      ```spec-meta
      id: malformed.command
      kind: module
      status: active
      ```

      ```spec-verification
      - kind: command
        target: printf executed >> ran.txt
        execute: true
      ```
      """
    )

    assert_raise Mix.Error, ~r/Spec verify failed: 1 finding/, fn ->
      Mix.Tasks.Spec.Verify.run(["--root", root, "--run-commands"])
    end

    refute File.exists?(Path.join(root, "ran.txt"))
  end

  test "spec.verify emits debug output on passing runs", %{root: root} do
    write_files(root, %{"README.md" => "readme\n# passing.requirement"})

    write_subject_spec(
      root,
      "passing",
      meta: %{"id" => "passing.subject", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "passing.requirement", "statement" => "Covered requirement"}],
      verification: [
        %{"kind" => "source_file", "target" => "README.md", "covers" => ["passing.requirement"]}
      ]
    )

    Mix.Tasks.Spec.Verify.run(["--root", root, "--debug"])

    messages = drain_shell_messages()

    assert Enum.any?(messages, &String.contains?(&1, "status=pass errors=0 warnings=0"))
    assert Enum.any?(messages, &String.contains?(&1, "debug_checks="))
    assert Enum.any?(messages, &String.contains?(&1, "[PASS] passing.subject"))
  end

  test "spec.verify requires explicit --run-commands to execute commands", %{root: root} do
    write_subject_spec(
      root,
      "command_only",
      meta: %{"id" => "command.only", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "command.requirement", "statement" => "Covered by command"}],
      verification: [
        %{
          "kind" => "command",
          "target" => "printf verify-only >> verify_only.txt",
          "covers" => ["command.requirement"],
          "execute" => true
        }
      ]
    )

    Mix.Tasks.Spec.Verify.run(["--root", root])

    refute File.exists?(Path.join(root, "verify_only.txt"))
    assert read_state(root)["summary"]["findings"] == 0
  end

  test "spec.check succeeds for covered specs", %{root: root} do
    write_files(root, %{"README.md" => "readme\n# covered.requirement"})

    write_subject_spec(
      root,
      "covered",
      meta: %{"id" => "covered.subject", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "covered.requirement", "statement" => "Covered requirement"}],
      verification: [
        %{"kind" => "source_file", "target" => "README.md", "covers" => ["covered.requirement"]}
      ]
    )

    Mix.Tasks.Spec.Check.run(["--root", root])
    assert read_state(root)["summary"]["findings"] == 0
  end

  test "spec.check fails for strict findings", %{root: root} do
    failing_root = Path.join(root, "failing")
    File.mkdir_p!(failing_root)

    write_subject_spec(
      failing_root,
      "failing",
      meta: %{"id" => "failing.subject", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "failing.requirement", "statement" => "Missing verification"}]
    )

    assert_raise Mix.Error, ~r/Spec verify failed: 1 finding/, fn ->
      Mix.Tasks.Spec.Check.run(["--root", failing_root])
    end

    assert read_state(failing_root)["summary"]["findings"] == 1
  end

  test "spec.check executes commands by default", %{root: root} do
    write_subject_spec(
      root,
      "commanded",
      meta: %{"id" => "commanded.subject", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "commanded.requirement", "statement" => "Covered by command"}],
      verification: [
        %{
          "kind" => "command",
          "target" => "printf checked >> checked.txt",
          "covers" => ["commanded.requirement"],
          "execute" => true
        }
      ]
    )

    Mix.Tasks.Spec.Check.run(["--root", root, "--debug"])

    messages = drain_shell_messages()

    assert read_state(root)["summary"]["findings"] == 0
    assert File.read!(Path.join(root, "checked.txt")) == "checked"
    assert message_contains?(messages, "debug_checks=")
    assert message_contains?(messages, "status=pass errors=0 warnings=0")
  end

  test "spec.check allows opting out of command execution", %{root: root} do
    write_subject_spec(
      root,
      "commanded_skipped",
      meta: %{"id" => "commanded.skipped", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "commanded.skipped.requirement", "statement" => "Covered"}],
      verification: [
        %{
          "kind" => "command",
          "target" => "printf skipped >> skipped.txt",
          "covers" => ["commanded.skipped.requirement"],
          "execute" => true
        }
      ]
    )

    Mix.Tasks.Spec.Check.run(["--root", root, "--no-run-commands"])

    refute File.exists?(Path.join(root, "skipped.txt"))
    assert read_state(root)["summary"]["findings"] == 0
  end

  test "spec.check forwards min strength to strict verify", %{root: root} do
    write_files(root, %{"lib/linked.ex" => "# req.forwarded\n"})

    write_subject_spec(
      root,
      "forwarded",
      meta: %{"id" => "forwarded.subject", "kind" => "module", "status" => "active"},
      requirements: [%{"id" => "req.forwarded", "statement" => "Linked only"}],
      verification: [
        %{"kind" => "source_file", "target" => "lib/linked.ex", "covers" => ["req.forwarded"]}
      ]
    )

    assert_raise Mix.Error, ~r/Spec verify failed: 1 finding/, fn ->
      Mix.Tasks.Spec.Check.run(["--root", root, "--min-strength", "executed"])
    end

    state = read_state(root)

    assert state["verification"]["cli_minimum_strength"] == "executed"
    assert state["verification"]["threshold_failures"] == 1
    assert Enum.map(state["findings"], & &1["code"]) == ["verification_strength_below_minimum"]
  end

  test "spec.check rejects strict toggles because it is always strict", %{root: root} do
    assert_raise Mix.Error, ~r/Invalid arguments for spec.check: --no-strict/, fn ->
      Mix.Tasks.Spec.Check.run(["--root", root, "--no-strict"])
    end
  end

  test "spec.verify rejects invalid min strength values", %{root: root} do
    assert_raise Mix.Error, ~r/Invalid value for --min-strength/, fn ->
      Mix.Tasks.Spec.Verify.run(["--root", root, "--min-strength", "strongest"])
    end
  end
end
