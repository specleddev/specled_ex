defmodule SpecLedEx.Schema.Requirement do
  @moduledoc false

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: SpecLedEx.Schema.id(),
              statement: Zoi.string(),
              priority: Zoi.string() |> Zoi.optional(),
              stability: Zoi.string() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Requirement"
  def schema, do: @schema
end
