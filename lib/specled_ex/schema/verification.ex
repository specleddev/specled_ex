defmodule SpecLedEx.Schema.Verification do
  @moduledoc false

  @kinds ~w(command file source_file test_file guide_file readme_file workflow_file test doc workflow contract)

  @schema Zoi.struct(
            __MODULE__,
            %{
              kind: Zoi.enum(@kinds),
              target: Zoi.string(),
              covers: Zoi.list(Zoi.string()),
              execute: Zoi.boolean() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Verification"
  def schema, do: @schema

  def kinds, do: @kinds
end
