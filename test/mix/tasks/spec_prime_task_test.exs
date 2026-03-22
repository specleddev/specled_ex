defmodule Mix.Tasks.SpecPrimeTaskTest do
  use SpecLedEx.Case

  test "spec.prime stays read-only and skips command execution by default", %{root: root} do
    write_subject_spec(
      root,
      "prime_context",
      meta: %{"id" => "prime.context", "kind" => "module", "status" => "active"},
      requirements: [
        %{"id" => "prime.context.requirement", "statement" => "Covered by command"}
      ],
      verification: [
        %{
          "kind" => "command",
          "target" => "printf primed >> prime.txt",
          "covers" => ["prime.context.requirement"],
          "execute" => true
        }
      ]
    )

    Mix.Tasks.Spec.Prime.run(["--root", root])
    messages = drain_shell_messages()

    refute File.exists?(Path.join(root, "prime.txt"))
    refute File.exists?(Path.join(root, ".spec/state.json"))
    assert message_contains?(messages, "Spec Led Prime")
    assert message_contains?(messages, "purpose=session-start context")
    assert message_contains?(messages, "Status")
    assert message_contains?(messages, "Next")
    assert message_contains?(messages, "Read `.spec/README.md` and `.spec/decisions/README.md`")
    assert message_contains?(messages, "run_commands=false")
  end

  test "spec.prime forwards branch options and supports json output", %{root: root} do
    init_git_repo(root)

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\n  def run(input), do: {:ok, input}\nend\n",
      "test/example_test.exs" => "# bug.example.response\n"
    })

    write_subject_spec(
      root,
      "example",
      meta: %{
        "id" => "example.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/example.ex"]
      },
      requirements: [
        %{"id" => "bug.example.response", "statement" => "Example returns a tagged ok tuple"}
      ],
      verification: [
        %{
          "kind" => "test_file",
          "target" => "test/example_test.exs",
          "covers" => ["bug.example.response"]
        },
        %{
          "kind" => "command",
          "target" => "printf primed >> prime.txt",
          "covers" => ["bug.example.response"],
          "execute" => true
        }
      ]
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/example.ex" =>
        "defmodule Example do\n  def run(nil), do: {:error, :invalid}\n  def run(input), do: {:ok, input}\nend\n",
      "test/example_test.exs" => "# bug.example.response\n# regression\n"
    })

    Mix.Tasks.Spec.Prime.run([
      "--root",
      root,
      "--base",
      "HEAD",
      "--bugfix",
      "--run-commands",
      "--json"
    ])

    [json] = drain_shell_messages()
    report = Jason.decode!(json)

    assert File.read!(Path.join(root, "prime.txt")) == "primed"
    assert report["summary"]["run_commands"] == true
    assert report["summary"]["bugfix"] == true
    assert report["next"]["base"] == "HEAD"
    assert report["next"]["bugfix"] == true
    assert report["next"]["classification"] == "covered_local_change"
    assert report["next"]["reconciliation"] == "needs_subject_updates"

    assert report["loop"]["steps"] |> Enum.any?(&String.contains?(&1, "mix spec.next --bugfix"))

    assert report["loop"]["steps"]
           |> Enum.any?(&String.contains?(&1, "mix spec.check --base HEAD"))
  end
end
