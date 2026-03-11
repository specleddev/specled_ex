defmodule SpecLedExTest do
  use ExUnit.Case

  test "build_index returns an index map" do
    root =
      System.tmp_dir!()
      |> Path.join("specled_ex_test_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(root) end)

    File.mkdir_p!(Path.join(root, ".spec/specs"))

    File.write!(
      Path.join(root, ".spec/specs/example.spec.md"),
      """
      # Example

      ```spec-meta
      {"id":"example.subject","kind":"module","status":"active"}
      ```

      ```spec-requirements
      [{"id":"example.requirement","statement":"Example statement"}]
      ```
      """
    )

    index = SpecLedEx.build_index(root)
    assert is_map(index)
    assert Map.has_key?(index, "subjects")
    assert index["summary"]["subjects"] == 1
  end
end
