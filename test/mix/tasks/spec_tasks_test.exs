defmodule Mix.Tasks.SpecTasksTest do
  use SpecLedEx.Case

  test "spec.init scaffolds files, keeps existing content, and overwrites with force", %{
    root: root
  } do
    Mix.Tasks.Spec.Init.run(["--root", root])

    readme = Path.join(root, ".spec/README.md")
    package_spec = Path.join(root, ".spec/specs/package.spec.md")

    assert File.exists?(readme)
    assert File.exists?(package_spec)
    assert File.read!(readme) =~ "# `.spec`"

    File.write!(package_spec, "# Custom Package Spec\n")

    Mix.Tasks.Spec.Init.run(["--root", root])
    assert File.read!(package_spec) == "# Custom Package Spec\n"

    Mix.Tasks.Spec.Init.run(["--root", root, "--force"])
    assert File.read!(package_spec) =~ "# Package"

    messages = drain_shell_messages()

    assert Enum.any?(messages, &String.contains?(&1, "spec.init scaffolded"))
    assert Enum.any?(messages, &String.contains?(&1, "kept"))
    assert Enum.any?(messages, &String.contains?(&1, "wrote"))
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
    assert Enum.any?(messages, &String.contains?(&1, "spec.plan wrote"))
    assert Enum.any?(messages, &String.contains?(&1, "subjects=1"))
  end

  test "spec.verify writes state and exits non-zero when the report fails", %{root: root} do
    write_spec(
      root,
      "warning",
      """
      # Warning

      ```spec-meta
      id: warning.subject
      kind: module
      status: active
      ```

      ```spec-requirements
      - id: warning.requirement
        statement: Needs coverage
      ```
      """
    )

    assert_raise Mix.Error, ~r/Spec verify failed: 1 finding/, fn ->
      Mix.Tasks.Spec.Verify.run(["--root", root, "--strict"])
    end

    state = read_state(root)
    messages = drain_shell_messages()

    assert state["findings"] == [
             %{
               "code" => "requirement_without_verification",
               "entity_id" => "warning.subject",
               "file" => ".spec/specs/warning.spec.md",
               "level" => "warning",
               "message" =>
                 "Requirement is not referenced by any verification item: warning.requirement"
             }
           ]

    assert Enum.any?(messages, &String.contains?(&1, "spec.verify wrote"))
    assert Enum.any?(messages, &String.contains?(&1, "status=fail errors=0 warnings=1"))

    assert Enum.any?(
             messages,
             &String.contains?(&1, "[WARNING] warning.subject requirement_without_verification")
           )
  end

  test "spec.verify emits debug output on passing runs", %{root: root} do
    write_files(root, %{"README.md" => "readme"})

    write_spec(
      root,
      "passing",
      """
      # Passing

      ```spec-meta
      id: passing.subject
      kind: module
      status: active
      ```

      ```spec-requirements
      - id: passing.requirement
        statement: Covered requirement
      ```

      ```spec-verification
      - kind: source_file
        target: README.md
        covers:
          - passing.requirement
      ```
      """
    )

    Mix.Tasks.Spec.Verify.run(["--root", root, "--debug"])

    messages = drain_shell_messages()

    assert Enum.any?(messages, &String.contains?(&1, "status=pass errors=0 warnings=0"))
    assert Enum.any?(messages, &String.contains?(&1, "debug_checks="))
    assert Enum.any?(messages, &String.contains?(&1, "[PASS] passing.subject"))
  end

  test "spec.check succeeds for covered specs and fails for strict findings", %{root: root} do
    write_files(root, %{"README.md" => "readme"})

    write_spec(
      root,
      "covered",
      """
      # Covered

      ```spec-meta
      id: covered.subject
      kind: module
      status: active
      ```

      ```spec-requirements
      - id: covered.requirement
        statement: Covered requirement
      ```

      ```spec-verification
      - kind: source_file
        target: README.md
        covers:
          - covered.requirement
      ```
      """
    )

    Mix.Tasks.Spec.Check.run(["--root", root])
    assert read_state(root)["summary"]["findings"] == 0

    reenable_tasks()
    drain_shell_messages()

    failing_root = Path.join(root, "failing")
    File.mkdir_p!(failing_root)

    write_spec(
      failing_root,
      "failing",
      """
      # Failing

      ```spec-meta
      id: failing.subject
      kind: module
      status: active
      ```

      ```spec-requirements
      - id: failing.requirement
        statement: Missing verification
      ```
      """
    )

    assert_raise Mix.Error, ~r/Spec verify failed: 1 finding/, fn ->
      Mix.Tasks.Spec.Check.run(["--root", failing_root])
    end

    assert read_state(failing_root)["summary"]["findings"] == 1
  end
end
