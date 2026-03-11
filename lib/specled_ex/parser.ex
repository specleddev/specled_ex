defmodule SpecLedEx.Parser do
  @moduledoc false

  @block_pattern ~r/```(spec-meta|spec-requirements|spec-scenarios|spec-verification|spec-exceptions)\s*\n(.*?)\n```/ms
  @seen_blocks_key "__seen_blocks__"

  def parse_file(path, root) do
    content = File.read!(path)

    @block_pattern
    |> Regex.scan(content)
    |> Enum.reduce(base_spec(path, root, content), fn [_, tag, raw], spec ->
      decode_block(spec, tag, raw)
    end)
    |> Map.delete(@seen_blocks_key)
  end

  defp base_spec(path, root, content) do
    %{
      "file" => Path.relative_to(path, root),
      "title" => extract_title(content),
      "meta" => nil,
      "requirements" => [],
      "scenarios" => [],
      "verification" => [],
      "exceptions" => [],
      "parse_errors" => [],
      @seen_blocks_key => MapSet.new()
    }
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content, capture: :all_but_first) do
      [title] -> String.trim(title)
      _ -> nil
    end
  end

  defp decode_block(spec, "spec-meta", raw) do
    if seen_block?(spec, "spec-meta") do
      push_parse_error(spec, "spec-meta may only appear once per file")
    else
      spec = mark_block_seen(spec, "spec-meta")

      case decode_yaml(raw) do
        {:ok, meta} when is_map(meta) ->
          case SpecLedEx.Schema.validate_block("spec-meta", meta) do
            {:ok, validated} -> Map.put(spec, "meta", validated)
            {:error, message} -> push_parse_error(Map.put(spec, "meta", meta), message)
          end

        {:ok, _invalid_shape} ->
          push_parse_error(spec, "spec-meta must decode to a mapping")

        {:error, message} ->
          push_parse_error(spec, "spec-meta decode failed: #{message}")
      end
    end
  end

  defp decode_block(spec, tag, raw) do
    key =
      case tag do
        "spec-requirements" -> "requirements"
        "spec-scenarios" -> "scenarios"
        "spec-verification" -> "verification"
        "spec-exceptions" -> "exceptions"
      end

    if seen_block?(spec, tag) do
      push_parse_error(spec, "#{tag} may only appear once per file")
    else
      spec = mark_block_seen(spec, tag)

      case decode_yaml(raw) do
        {:ok, items} when is_list(items) ->
          case SpecLedEx.Schema.validate_block(tag, items) do
            {:ok, validated} -> Map.put(spec, key, validated)
            {:error, message} -> push_parse_error(Map.put(spec, key, items), message)
          end

        {:ok, _invalid_shape} ->
          push_parse_error(spec, "#{tag} must decode to a list")

        {:error, message} ->
          push_parse_error(spec, "#{tag} decode failed: #{message}")
      end
    end
  end

  defp decode_yaml(raw) do
    case YamlElixir.read_from_string(raw) do
      {:ok, result} -> {:ok, result}
      {:error, %YamlElixir.ParsingError{message: message}} -> {:error, message}
      {:error, reason} -> {:error, inspect(reason)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp push_parse_error(spec, message) do
    Map.update!(spec, "parse_errors", &[message | &1])
  end

  defp seen_block?(spec, tag) do
    spec
    |> Map.get(@seen_blocks_key, MapSet.new())
    |> MapSet.member?(tag)
  end

  defp mark_block_seen(spec, tag) do
    Map.update(spec, @seen_blocks_key, MapSet.new([tag]), &MapSet.put(&1, tag))
  end
end
