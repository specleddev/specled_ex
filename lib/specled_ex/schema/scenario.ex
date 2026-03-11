defmodule SpecLedEx.Schema.Scenario do
  @moduledoc false

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: SpecLedEx.Schema.id(),
              covers: Zoi.list(Zoi.string()),
              given: Zoi.list(Zoi.string()),
              when: Zoi.list(Zoi.string()),
              then: Zoi.list(Zoi.string())
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Scenario"
  def schema, do: @schema
end
