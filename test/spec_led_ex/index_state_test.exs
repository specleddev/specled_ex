defmodule SpecLedEx.IndexStateTest do
  use SpecLedEx.Case

  alias SpecLedEx.Index

  test "build_index summarizes authored specs and detects directories", %{root: root} do
    write_files(root, %{
      ".spec/specs/alpha.spec.md" => """
      # Alpha

      ```spec-meta
      id: alpha.subject
      kind: module
      status: active
      ```

      ```spec-requirements
      - id: alpha.requirement
        statement: Alpha requirement
      ```

      ```spec-scenarios
      - id: alpha.scenario
        covers:
          - alpha.requirement
        given:
          - alpha given
        when:
          - alpha when
        then:
          - alpha then
      ```
      """,
      ".spec/specs/beta.spec.md" => """
      # Beta

      ```spec-meta
      id: beta.subject
      kind: module
      status: active
      ```

      ```spec-verification
      - kind: source_file
        target: README.md
        covers:
          - alpha.requirement
      ```

      ```spec-exceptions
      - id: beta.exception
        covers:
          - alpha.requirement
        reason: documented waiver
      ```
      """
    })

    assert SpecLedEx.detect_spec_dir(root) == ".spec"
    assert SpecLedEx.detect_authored_dir(root) == ".spec/specs"
    assert Index.detect_spec_dir(root) == ".spec"
    assert Index.detect_authored_dir(root, ".spec") == ".spec/specs"

    index = SpecLedEx.build_index(root)

    assert index["summary"] == %{
             "subjects" => 2,
             "requirements" => 1,
             "scenarios" => 1,
             "verification_items" => 1,
             "exceptions" => 1,
             "parse_errors" => 0
           }
  end

  test "detect_spec_dir and detect_authored_dir raise when directories are missing", %{root: root} do
    assert_raise RuntimeError, ~r/\.spec directory not found/, fn ->
      SpecLedEx.detect_spec_dir(root)
    end

    File.mkdir_p!(Path.join(root, ".spec"))

    assert_raise RuntimeError, ~r/\.spec\/specs directory not found/, fn ->
      SpecLedEx.detect_authored_dir(root)
    end
  end

  test "write_state skips malformed items and normalizes findings", %{root: root} do
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

    index = SpecLedEx.build_index(root)

    report = %{
      "findings" => [
        %{
          "code" => "parse_error",
          "severity" => "warning",
          "message" => "Malformed item",
          "file" => ".spec/specs/malformed.spec.md",
          "subject_id" => "malformed.subject"
        },
        %{
          "code" => "custom_level",
          "level" => "error",
          "message" => "Already normalized"
        },
        "not-a-finding"
      ]
    }

    path = SpecLedEx.write_state(index, report, root)
    state = read_state(root)

    assert path == Path.join(root, ".spec/state.json")
    assert state["index"]["requirements"] == []
    assert state["summary"]["requirements"] == 1
    assert state["summary"]["findings"] == 3

    assert state["findings"] == [
             %{
               "code" => "parse_error",
               "entity_id" => "malformed.subject",
               "file" => ".spec/specs/malformed.spec.md",
               "level" => "warning",
               "message" => "Malformed item"
             },
             %{
               "code" => "custom_level",
               "level" => "error",
               "message" => "Already normalized"
             }
           ]
  end

  test "read_state supports custom output paths", %{root: root} do
    index = %{
      "subjects" => [],
      "summary" => %{
        "subjects" => 0,
        "requirements" => 0,
        "scenarios" => 0,
        "verification_items" => 0,
        "exceptions" => 0,
        "parse_errors" => 0
      }
    }

    SpecLedEx.write_state(index, nil, root, "tmp/custom_state.json")

    assert SpecLedEx.read_state(root, "tmp/custom_state.json")["workspace"]["spec_count"] == 0
  end
end
