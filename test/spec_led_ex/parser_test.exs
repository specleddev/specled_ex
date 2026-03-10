defmodule SpecLedEx.ParserTest do
  use SpecLedEx.Case

  alias SpecLedEx.Parser

  test "parse_file extracts all supported blocks and title", %{root: root} do
    path =
      write_spec(
        root,
        "example",
        """
        # Example Subject

        ```spec-meta
        id: example.subject
        kind: module
        status: active
        summary: Example summary
        ```

        ```spec-requirements
        - id: example.requirement
          statement: Example statement
        ```

        ```spec-scenarios
        - id: example.scenario
          covers:
            - example.requirement
          given:
            - a precondition
          when:
            - an action occurs
          then:
            - the outcome is observed
        ```

        ```spec-verification
        - kind: source_file
          target: lib/example.ex
          covers:
            - example.requirement
        ```

        ```spec-exceptions
        - id: example.exception
          covers:
            - example.requirement
          reason: accepted gap
        ```
        """
      )

    spec = Parser.parse_file(path, root)

    assert spec["file"] == ".spec/specs/example.spec.md"
    assert spec["title"] == "Example Subject"
    assert spec["meta"]["summary"] == "Example summary"
    assert [%{"id" => "example.requirement"}] = spec["requirements"]
    assert [%{"id" => "example.scenario"}] = spec["scenarios"]
    assert [%{"kind" => "source_file", "target" => "lib/example.ex"}] = spec["verification"]
    assert [%{"id" => "example.exception", "reason" => "accepted gap"}] = spec["exceptions"]
    assert spec["parse_errors"] == []
  end

  test "parse_file returns nil title when no h1 is present", %{root: root} do
    path =
      write_spec(
        root,
        "untitled",
        """
        Paragraph only.

        ```spec-meta
        id: untitled.subject
        kind: module
        status: active
        ```
        """
      )

    assert Parser.parse_file(path, root)["title"] == nil
  end

  test "parse_file records decode and shape errors without crashing", %{root: root} do
    path =
      write_spec(
        root,
        "invalid",
        """
        # Invalid

        ```spec-meta
        id: [
        ```

        ```spec-requirements
        id: wrong-shape
        statement: still wrong
        ```
        """
      )

    spec = Parser.parse_file(path, root)

    assert Enum.any?(spec["parse_errors"], &String.contains?(&1, "spec-meta decode failed"))
    assert "spec-requirements must decode to a list" in spec["parse_errors"]
  end

  test "parse_file rejects duplicate spec-meta blocks even when the first one is malformed", %{
    root: root
  } do
    path =
      write_spec(
        root,
        "duplicate_meta",
        """
        # Duplicate Meta

        ```spec-meta
        id: [
        ```

        ```spec-meta
        id: duplicate.subject
        kind: module
        status: active
        ```
        """
      )

    spec = Parser.parse_file(path, root)

    assert Enum.any?(spec["parse_errors"], &String.contains?(&1, "spec-meta decode failed"))
    assert "spec-meta may only appear once per file" in spec["parse_errors"]
    assert spec["meta"] == nil
  end

  test "parse_file rejects duplicate empty list-backed blocks", %{root: root} do
    path =
      write_spec(
        root,
        "duplicate_requirements",
        """
        # Duplicate Requirements

        ```spec-meta
        id: duplicate.requirements
        kind: module
        status: active
        ```

        ```spec-requirements
        []
        ```

        ```spec-requirements
        []
        ```
        """
      )

    spec = Parser.parse_file(path, root)

    assert "spec-requirements may only appear once per file" in spec["parse_errors"]
  end

  test "parse_file preserves malformed list items for later reporting", %{root: root} do
    path =
      write_spec(
        root,
        "malformed_items",
        """
        # Malformed Items

        ```spec-meta
        id: malformed.items
        kind: module
        status: active
        ```

        ```spec-requirements
        - just-a-string
        ```
        """
      )

    spec = Parser.parse_file(path, root)

    assert spec["requirements"] == ["just-a-string"]

    assert Enum.any?(
             spec["parse_errors"],
             &String.contains?(&1, "spec-requirements[0] validation failed")
           )
  end
end
