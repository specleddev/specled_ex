defmodule Mix.Tasks.SpecNextTaskTest do
  use SpecLedEx.Case

  test "spec.next guides a covered local change", %{root: root} do
    init_git_repo(root)

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\nend\n"
    })

    write_subject_spec(
      root,
      "example",
      meta: %{
        "id" => "example.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/example.ex"]
      }
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\n  def run, do: :ok\nend\n"
    })

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD"])
    messages = drain_shell_messages()

    assert message_contains?(messages, "classification=covered local change")
    assert message_contains?(messages, "reconciliation=needs subject updates")
    assert message_contains?(messages, "example.subject (.spec/specs/example.spec.md)")

    assert message_contains?(
             messages,
             "Update .spec/specs/example.spec.md if the change affects current truth."
           )

    assert message_contains?(messages, "mix spec.check --base HEAD")
  end

  test "spec.next guides a covered cross-cutting change", %{root: root} do
    init_git_repo(root)

    write_files(root, %{
      "lib/a.ex" => "defmodule A do\nend\n",
      "lib/b.ex" => "defmodule B do\nend\n"
    })

    write_subject_spec(
      root,
      "a",
      meta: %{
        "id" => "a.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/a.ex"]
      }
    )

    write_subject_spec(
      root,
      "b",
      meta: %{
        "id" => "b.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/b.ex"]
      }
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/a.ex" => "defmodule A do\n  def run, do: :ok\nend\n",
      "lib/b.ex" => "defmodule B do\n  def run, do: :ok\nend\n"
    })

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD"])
    messages = drain_shell_messages()

    assert message_contains?(messages, "classification=covered cross-cutting change")
    assert message_contains?(messages, "reconciliation=needs subject updates")
    assert message_contains?(messages, "a.subject (.spec/specs/a.spec.md)")
    assert message_contains?(messages, "b.subject (.spec/specs/b.spec.md)")
    assert message_contains?(messages, "add or revise an ADR")
  end

  test "spec.next guides uncovered frontier changes without failing", %{root: root} do
    init_git_repo(root)
    File.mkdir_p!(Path.join(root, ".spec/specs"))

    write_files(root, %{"README.md" => "# Example\n"})
    commit_all(root, "initial")

    write_files(root, %{
      "lib/uncovered.ex" => "defmodule Uncovered do\nend\n"
    })

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD"])
    messages = drain_shell_messages()

    assert message_contains?(messages, "classification=uncovered frontier change")
    assert message_contains?(messages, "reconciliation=needs new subject")
    assert message_contains?(messages, "lib/uncovered.ex")
    assert message_contains?(messages, "Create or expand one subject in `.spec/specs/`")
  end

  test "spec.next --bugfix teaches the regression-first local loop", %{root: root} do
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
        }
      ]
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/example.ex" =>
        "defmodule Example do\n  def run(nil), do: {:error, :invalid}\n  def run(input), do: {:ok, input}\nend\n",
      "test/example_test.exs" => "# bug.example.response\n# regression\n"
    })

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD", "--bugfix"])
    messages = drain_shell_messages()

    assert message_contains?(messages, "classification=covered local change")
    assert message_contains?(messages, "reconciliation=needs subject updates")
    assert message_contains?(messages, "regression test")
    assert message_contains?(messages, "Review .spec/specs/example.spec.md")
    assert message_contains?(messages, "mix spec.check --base HEAD")
  end

  test "spec.next --since scopes guidance to changes after a checkpoint", %{root: root} do
    init_git_repo(root)

    write_files(root, %{
      "lib/a.ex" => "defmodule A do\nend\n",
      "lib/b.ex" => "defmodule B do\nend\n"
    })

    write_subject_spec(
      root,
      "a",
      meta: %{
        "id" => "a.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/a.ex"]
      }
    )

    write_subject_spec(
      root,
      "b",
      meta: %{
        "id" => "b.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/b.ex"]
      }
    )

    commit_all(root, "initial")
    git!(root, ["checkout", "-b", "feature/workset"])

    write_files(root, %{
      "lib/a.ex" => "defmodule A do\n  def run, do: :ok\nend\n"
    })

    File.write!(
      Path.join(root, ".spec/specs/a.spec.md"),
      File.read!(Path.join(root, ".spec/specs/a.spec.md")) <> "\n"
    )

    commit_all(root, "complete first ticket")
    checkpoint = root |> git!(["rev-parse", "HEAD"]) |> String.trim()

    write_files(root, %{
      "lib/b.ex" => "defmodule B do\n  def run, do: :ok\nend\n"
    })

    commit_all(root, "start second ticket")

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "main", "--since", checkpoint])
    messages = drain_shell_messages()

    assert message_contains?(messages, "guidance_scope=since #{checkpoint}")
    assert message_contains?(messages, "check_scope=full branch vs main")
    assert message_contains?(messages, "classification=covered local change")
    assert message_contains?(messages, "reconciliation=needs subject updates")
    assert message_contains?(messages, "b.subject (.spec/specs/b.spec.md)")
    refute message_contains?(messages, "a.subject (.spec/specs/a.spec.md)")
    assert message_contains?(messages, "mix spec.check --base main")
  end

  test "spec.next keeps default output compact and expands file lists with --verbose", %{
    root: root
  } do
    init_git_repo(root)

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\nend\n"
    })

    write_subject_spec(
      root,
      "example",
      meta: %{
        "id" => "example.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/example.ex"]
      }
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\n  def run, do: :ok\nend\n"
    })

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD"])
    compact_messages = drain_shell_messages()

    assert message_contains?(compact_messages, "classification=covered local change")
    refute message_contains?(compact_messages, "changed_files:")
    refute message_contains?(compact_messages, "policy_files:")

    reenable_tasks(["spec.next"])

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD", "--verbose"])
    verbose_messages = drain_shell_messages()

    assert message_contains?(verbose_messages, "changed_files:")
    assert message_contains?(verbose_messages, "- lib/example.ex")
    assert message_contains?(verbose_messages, "policy_files:")
  end

  test "spec.next supports json output", %{root: root} do
    init_git_repo(root)

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\nend\n"
    })

    write_subject_spec(
      root,
      "example",
      meta: %{
        "id" => "example.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/example.ex"]
      }
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/example.ex" => "defmodule Example do\n  def run, do: :ok\nend\n"
    })

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD", "--since", "HEAD", "--json"])
    [json] = drain_shell_messages()
    report = Jason.decode!(json)

    assert report["base"] == "HEAD"
    assert report["since"] == "HEAD"
    assert report["guidance_scope"] == "since HEAD"
    assert report["classification"] == "covered_local_change"
    assert report["reconciliation"] == "needs_subject_updates"
    assert report["changed_files"] == ["lib/example.ex"]

    assert report["subject_refs"] == [
             %{"file" => ".spec/specs/example.spec.md", "id" => "example.subject"}
           ]
  end

  test "spec.next says ready for check when current truth and ADR updates are already present", %{
    root: root
  } do
    init_git_repo(root)

    write_files(root, %{
      "lib/a.ex" => "defmodule A do\nend\n",
      "lib/b.ex" => "defmodule B do\nend\n"
    })

    write_subject_spec(
      root,
      "a",
      meta: %{
        "id" => "a.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/a.ex"]
      }
    )

    write_subject_spec(
      root,
      "b",
      meta: %{
        "id" => "b.subject",
        "kind" => "module",
        "status" => "active",
        "surface" => ["lib/b.ex"]
      }
    )

    write_decision(
      root,
      "policy",
      """
      ---
      id: repo.policy
      status: accepted
      date: 2026-03-11
      affects:
        - repo.governance
        - a.subject
        - b.subject
      ---

      # Repo Policy

      ## Context

      Context.

      ## Decision

      Decision.

      ## Consequences

      Consequences.
      """
    )

    commit_all(root, "initial")

    write_files(root, %{
      "lib/a.ex" => "defmodule A do\n  def run, do: :ok\nend\n",
      "lib/b.ex" => "defmodule B do\n  def run, do: :ok\nend\n"
    })

    File.write!(
      Path.join(root, ".spec/specs/a.spec.md"),
      File.read!(Path.join(root, ".spec/specs/a.spec.md")) <> "\n"
    )

    File.write!(
      Path.join(root, ".spec/specs/b.spec.md"),
      File.read!(Path.join(root, ".spec/specs/b.spec.md")) <> "\n"
    )

    File.write!(
      Path.join(root, ".spec/decisions/policy.md"),
      File.read!(Path.join(root, ".spec/decisions/policy.md")) <> "\n"
    )

    Mix.Tasks.Spec.Next.run(["--root", root, "--base", "HEAD"])
    messages = drain_shell_messages()

    assert message_contains?(messages, "classification=covered cross-cutting change")
    assert message_contains?(messages, "reconciliation=ready for check")
    assert message_contains?(messages, "Current truth is already updated across")
    assert message_contains?(messages, "ADR update is already in the change set")
  end
end
