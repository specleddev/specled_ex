defmodule SpecLedEx.Schema do
  @moduledoc false

  @id_pattern ~r/^[a-z0-9][a-z0-9._-]*$/

  def id do
    Zoi.string()
    |> Zoi.regex(@id_pattern,
      error: "invalid id format: must match #{inspect(Regex.source(@id_pattern))}"
    )
  end

  def meta do
    Zoi.map(
      %{
        "id" => id(),
        "kind" => Zoi.string(),
        "status" => Zoi.string()
      },
      unrecognized_keys: :preserve
    )
  end

  def requirement do
    Zoi.map(
      %{
        "id" => id(),
        "statement" => Zoi.string()
      },
      unrecognized_keys: :preserve
    )
  end

  def scenario do
    Zoi.map(
      %{
        "id" => id(),
        "covers" => Zoi.list(Zoi.string()),
        "given" => Zoi.list(Zoi.string()),
        "when" => Zoi.list(Zoi.string()),
        "then" => Zoi.list(Zoi.string())
      },
      unrecognized_keys: :preserve
    )
  end

  def verification do
    Zoi.map(
      %{
        "kind" => Zoi.string(),
        "target" => Zoi.string(),
        "covers" => Zoi.list(Zoi.string())
      },
      unrecognized_keys: :preserve
    )
  end

  def exception do
    Zoi.map(
      %{
        "id" => id(),
        "covers" => Zoi.list(Zoi.string()),
        "reason" => Zoi.string()
      },
      unrecognized_keys: :preserve
    )
  end

  @doc """
  Validates a parsed block list against its schema.
  Returns `{:ok, items}` or `{:error, message}`.
  """
  def validate_block("spec-meta", data) do
    case Zoi.parse(meta(), data) do
      {:ok, result} -> {:ok, result}
      {:error, errors} -> {:error, format_errors("spec-meta", errors)}
    end
  end

  def validate_block(tag, items) when is_list(items) do
    schema =
      case tag do
        "spec-requirements" -> requirement()
        "spec-scenarios" -> scenario()
        "spec-verification" -> verification()
        "spec-exceptions" -> exception()
      end

    items
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {item, idx}, {valid, errs} ->
      case Zoi.parse(schema, item) do
        {:ok, result} -> {[result | valid], errs}
        {:error, errors} -> {valid, [format_item_errors(tag, idx, errors) | errs]}
      end
    end)
    |> case do
      {valid, []} -> {:ok, Enum.reverse(valid)}
      {_valid, errs} -> {:error, errs |> Enum.reverse() |> Enum.join("; ")}
    end
  end

  defp format_errors(tag, errors) do
    msgs = Enum.map(errors, & &1.message)
    "#{tag} validation failed: #{Enum.join(msgs, ", ")}"
  end

  defp format_item_errors(tag, idx, errors) do
    msgs = Enum.map(errors, & &1.message)
    "#{tag}[#{idx}] validation failed: #{Enum.join(msgs, ", ")}"
  end
end
