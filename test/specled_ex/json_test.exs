defmodule SpecLedEx.JsonTest do
  use SpecLedEx.Case

  alias SpecLedEx.Json

  test "read returns an empty map for missing and invalid files", %{root: root} do
    missing = Path.join(root, "missing.json")
    invalid = Path.join(root, "invalid.json")

    File.write!(invalid, "{not json}")

    assert Json.read(missing) == %{}
    assert Json.read(invalid) == %{}
  end

  test "write! creates parent directories and persists json data", %{root: root} do
    path = Path.join(root, "nested/state.json")

    Json.write!(path, %{"value" => 1})

    assert File.exists?(path)
    assert Json.read(path) == %{"value" => 1}
  end
end
