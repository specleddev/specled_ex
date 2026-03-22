defmodule SpecLedEx.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false

      import SpecLedEx.Case
    end
  end

  setup _context do
    Mix.shell(Mix.Shell.Process)
    Mix.Shell.Process.flush()

    root =
      System.tmp_dir!()
      |> Path.join("specled_ex_#{unique_temp_suffix()}")

    File.rm_rf(root)
    File.mkdir_p!(root)

    on_exit(fn -> File.rm_rf(root) end)

    reenable_tasks()

    {:ok, root: root}
  end

  def write_files(root, files) do
    Enum.each(files, fn {path, content} ->
      full_path = Path.join(root, path)
      File.mkdir_p!(Path.dirname(full_path))
      File.write!(full_path, content)
    end)
  end

  def write_spec(root, name, content) do
    relative_path = ".spec/specs/#{name}.spec.md"
    write_files(root, %{relative_path => content})
    Path.join(root, relative_path)
  end

  def write_decision(root, name, content) do
    relative_path = ".spec/decisions/#{name}.md"
    write_files(root, %{relative_path => content})
    Path.join(root, relative_path)
  end

  def write_subject_spec(root, name, opts \\ []) do
    title = Keyword.get(opts, :title, default_spec_title(name))

    meta =
      Keyword.get(opts, :meta, %{
        "id" => "#{name}.subject",
        "kind" => "module",
        "status" => "active"
      })

    content =
      build_spec_document(
        title,
        [
          {"spec-meta", meta},
          {"spec-requirements", Keyword.get(opts, :requirements)},
          {"spec-scenarios", Keyword.get(opts, :scenarios)},
          {"spec-verification", Keyword.get(opts, :verification)},
          {"spec-exceptions", Keyword.get(opts, :exceptions)}
        ]
      )

    write_spec(root, name, content)
  end

  def read_state(root, output_path \\ ".spec/state.json") do
    SpecLedEx.read_state(root, output_path)
  end

  def render_spec_init_template(relative_path) do
    :spec_led_ex
    |> :code.priv_dir()
    |> List.to_string()
    |> Path.join("spec_init")
    |> Path.join(relative_path)
    |> EEx.eval_file([])
  end

  def answer_shell_yes(response, times \\ 1) when is_boolean(response) and times >= 1 do
    Enum.each(1..times, fn _ ->
      send(self(), {:mix_shell_input, :yes?, response})
    end)
  end

  def reenable_tasks(
        tasks \\ ~w(spec.init spec.index spec.validate spec.check spec.decision.new spec.status spec.next spec.prime)
      ) do
    Enum.each(tasks, &Mix.Task.reenable/1)
  end

  def init_git_repo(root) do
    git!(root, ["init", "-b", "main"])
    git!(root, ["config", "user.name", "Spec Led Test"])
    git!(root, ["config", "user.email", "specled@example.com"])
  end

  def commit_all(root, message) do
    git!(root, ["add", "."])
    git!(root, ["commit", "-m", message])
  end

  def git!(root, args) do
    {output, exit_code} = System.cmd("git", ["-C", root | args], stderr_to_stdout: true)

    if exit_code == 0 do
      output
    else
      raise "git #{Enum.join(args, " ")} failed: #{String.trim(output)}"
    end
  end

  def message_contains?(messages, expected) do
    Enum.any?(messages, &String.contains?(&1, expected))
  end

  def drain_shell_messages(messages \\ []) do
    receive do
      {:mix_shell, _level, payload} ->
        message =
          case payload do
            [value] -> value
            value -> inspect(value)
          end

        drain_shell_messages([message | messages])
    after
      0 -> Enum.reverse(messages)
    end
  end

  defp build_spec_document(title, sections) do
    body =
      sections
      |> Enum.flat_map(fn
        {_tag, nil} ->
          []

        {tag, data} ->
          [
            "```#{tag}",
            encode_block(data),
            "```"
          ]
      end)
      |> Enum.join("\n\n")

    "# #{title}\n\n#{body}\n"
  end

  defp encode_block(data) do
    data
    |> Jason.encode_to_iodata!(pretty: true)
    |> IO.iodata_to_binary()
  end

  defp default_spec_title(name) do
    name
    |> String.replace(~r/[-_]+/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp unique_temp_suffix do
    [
      System.system_time(:nanosecond),
      System.unique_integer([:positive, :monotonic]),
      Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
    ]
    |> Enum.join("_")
  end
end
