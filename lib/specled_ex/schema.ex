defmodule SpecLedEx.Schema do
  @moduledoc false

  alias SpecLedEx.Schema.{Exception, Meta, Requirement, Scenario, Verification}

  @id_pattern ~r/^[a-z0-9][a-z0-9._-]*$/

  def id do
    Zoi.string()
    |> Zoi.regex(@id_pattern,
      error: "invalid id format: must match #{inspect(Regex.source(@id_pattern))}"
    )
  end

  def meta do
    Meta.schema()
  end

  def requirement do
    Requirement.schema()
  end

  def scenario do
    Scenario.schema()
  end

  def verification do
    Verification.schema()
  end

  def exception do
    Exception.schema()
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
