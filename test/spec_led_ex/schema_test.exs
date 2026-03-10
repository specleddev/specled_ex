defmodule SpecLedEx.SchemaTest do
  use SpecLedEx.Case

  alias SpecLedEx.Schema

  test "validate_block accepts valid spec-meta and preserves extra keys" do
    assert {:ok, meta} =
             Schema.validate_block("spec-meta", %{
               "id" => "example.subject",
               "kind" => "module",
               "status" => "active",
               "summary" => "preserved"
             })

    assert meta["summary"] == "preserved"
  end

  for {tag, item, assertion} <- [
        {"spec-requirements", %{"id" => "example.requirement", "statement" => "Requirement"},
         {"id", "example.requirement"}},
        {"spec-scenarios",
         %{
           "id" => "example.scenario",
           "covers" => ["example.requirement"],
           "given" => ["given"],
           "when" => ["when"],
           "then" => ["then"]
         }, {"id", "example.scenario"}},
        {"spec-verification",
         %{
           "kind" => "source_file",
           "target" => "lib/example.ex",
           "covers" => ["example.requirement"]
         }, {"target", "lib/example.ex"}},
        {"spec-exceptions",
         %{
           "id" => "example.exception",
           "covers" => ["example.requirement"],
           "reason" => "accepted"
         }, {"reason", "accepted"}}
      ] do
    @schema_tag tag
    @schema_item item
    @schema_assertion assertion

    test "#{tag} accepts valid list items" do
      assert {:ok, [validated]} = Schema.validate_block(@schema_tag, [@schema_item])
      {field, expected} = @schema_assertion
      assert validated[field] == expected
    end
  end

  test "validate_block rejects invalid meta identifiers" do
    assert {:error, message} =
             Schema.validate_block("spec-meta", %{
               "id" => "Bad Subject",
               "kind" => "module",
               "status" => "active"
             })

    assert message =~ "spec-meta validation failed"
    assert message =~ "invalid id format"
  end

  test "validate_block reports item indexes for invalid list entries" do
    assert {:error, message} =
             Schema.validate_block("spec-requirements", [
               %{"statement" => "Missing id"}
             ])

    assert message =~ "spec-requirements[0] validation failed"
  end
end
