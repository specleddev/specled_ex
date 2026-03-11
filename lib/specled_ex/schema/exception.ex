defmodule SpecLedEx.Schema.Exception do
  @moduledoc false

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: SpecLedEx.Schema.id(),
              covers: Zoi.list(Zoi.string()),
              reason: Zoi.string()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))

  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Returns the Zoi schema for Exception"
  def schema, do: @schema
end
