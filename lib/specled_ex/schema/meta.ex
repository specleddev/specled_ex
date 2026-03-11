defmodule SpecLedEx.Schema.Meta do
  @moduledoc false

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: SpecLedEx.Schema.id(),
              kind: Zoi.string(),
              status: Zoi.string(),
              summary: Zoi.string() |> Zoi.optional(),
              surface: Zoi.list(Zoi.string()) |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Meta"
  def schema, do: @schema
end
