defmodule SpecLedEx.Json do
  @moduledoc false

  def read(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, decoded} when is_map(decoded) -> decoded
            _ -> %{}
          end

        _ ->
          %{}
      end
    else
      %{}
    end
  end

  def write!(path, data) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    encoded = Jason.encode_to_iodata!(data, pretty: true)
    File.write!(path, encoded)
  end
end
