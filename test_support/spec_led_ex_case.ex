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
    drain_shell_messages()

    root =
      System.tmp_dir!()
      |> Path.join("spec_led_ex_#{System.unique_integer([:positive])}")

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

  def read_state(root, output_path \\ ".spec/state.json") do
    SpecLedEx.read_state(root, output_path)
  end

  def reenable_tasks(tasks \\ ~w(spec.init spec.plan spec.verify spec.check)) do
    Enum.each(tasks, &Mix.Task.reenable/1)
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
end
