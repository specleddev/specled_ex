defmodule SpecLedEx.VerifierTest do
  use SpecLedEx.Case

  alias SpecLedEx.Verifier

  test "verify reports parse errors and missing meta fields", %{root: root} do
    report =
      Verifier.verify(
        %{
          "subjects" => [
            %{
              "file" => ".spec/specs/missing_meta.spec.md",
              "meta" => %{},
              "parse_errors" => ["spec-meta decode failed: broken yaml"]
            }
          ]
        },
        root,
        debug: true
      )

    assert report["status"] == "fail"
    assert report["summary"]["errors"] == 4

    assert finding_codes(report) ==
             MapSet.new([
               "missing_meta_field",
               "parse_error"
             ])

    assert check_codes(report) ==
             MapSet.new([
               "meta_field_missing",
               "parse_blocks",
               "duplicate_subject_id",
               "duplicate_requirement_id"
             ])
  end

  test "verify ignores malformed non-map items instead of crashing", %{root: root} do
    report =
      Verifier.verify(
        %{
          "subjects" => [
            %{
              "file" => ".spec/specs/malformed.spec.md",
              "meta" => %{"id" => "malformed.subject", "kind" => "module", "status" => "active"},
              "requirements" => ["bad requirement"],
              "scenarios" => ["bad scenario"],
              "verification" => ["bad verification"],
              "exceptions" => ["bad exception"],
              "parse_errors" => [
                "spec-requirements[0] validation failed: invalid type: expected map"
              ]
            }
          ]
        },
        root,
        debug: true
      )

    assert report["status"] == "fail"
    assert finding_codes(report) == MapSet.new(["parse_error"])

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "parse_blocks" and &1["status"] == "error")
           )
  end

  test "verify reports requirement and scenario structure issues", %{root: root} do
    report =
      Verifier.verify(
        %{
          "subjects" => [
            base_subject(%{
              "requirements" => [
                %{"statement" => "Missing id"},
                %{"id" => "covered.req", "statement" => "Covered"}
              ],
              "scenarios" => [
                %{
                  "id" => "scenario.bad",
                  "covers" => ["unknown.req"],
                  "given" => [],
                  "when" => [],
                  "then" => []
                },
                %{
                  "covers" => [],
                  "given" => ["g"],
                  "when" => ["w"],
                  "then" => ["t"]
                }
              ]
            })
          ]
        },
        root
      )

    assert report["summary"]["warnings"] == 5
    assert report["summary"]["errors"] == 2

    assert finding_codes(report) ==
             MapSet.new([
               "missing_requirement_id",
               "missing_scenario_id",
               "scenario_unknown_cover",
               "scenario_missing_given",
               "scenario_missing_when",
               "scenario_missing_then",
               "requirement_without_verification"
             ])
  end

  test "verify reports duplicate ids and invalid id formats", %{root: root} do
    duplicate_subject =
      base_subject(%{
        "meta" => %{"id" => "duplicate.subject", "kind" => "module", "status" => "active"},
        "requirements" => [%{"id" => "duplicate.requirement", "statement" => "One"}],
        "scenarios" => [
          %{
            "id" => "duplicate.scenario",
            "covers" => [],
            "given" => ["given"],
            "when" => ["when"],
            "then" => ["then"]
          }
        ],
        "exceptions" => [%{"id" => "duplicate.exception", "covers" => [], "reason" => "waived"}]
      })

    invalid_subject =
      base_subject(%{
        "file" => ".spec/specs/invalid.spec.md",
        "meta" => %{"id" => "Bad Subject", "kind" => "module", "status" => "active"},
        "requirements" => [%{"id" => "Bad Requirement", "statement" => "Bad"}],
        "scenarios" => [
          %{
            "id" => "Bad Scenario",
            "covers" => [],
            "given" => ["given"],
            "when" => ["when"],
            "then" => ["then"]
          }
        ],
        "exceptions" => [%{"id" => "Bad Exception", "covers" => [], "reason" => "waived"}]
      })

    report =
      Verifier.verify(
        %{"subjects" => [duplicate_subject, duplicate_subject, invalid_subject]},
        root,
        debug: true
      )

    assert finding_codes(report) ==
             MapSet.new([
               "duplicate_subject_id",
               "duplicate_requirement_id",
               "duplicate_scenario_id",
               "duplicate_exception_id",
               "invalid_id_format",
               "requirement_without_verification"
             ])

    assert Enum.count(report["findings"], &(&1["code"] == "invalid_id_format")) == 4

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "duplicate_subject_id" and &1["status"] == "error")
           )

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "duplicate_requirement_id" and &1["status"] == "error")
           )
  end

  test "verify evaluates file and command verifications with debug checks", %{root: root} do
    write_files(root, %{"present.txt" => "present"})

    report =
      Verifier.verify(
        %{
          "subjects" => [
            base_subject(%{
              "requirements" => [
                %{"id" => "req.1", "statement" => "Covered"},
                %{"id" => "req.2", "statement" => "Covered by exception"}
              ],
              "verification" => [
                %{"kind" => "source_file", "target" => "present.txt", "covers" => ["req.1"]},
                %{"kind" => "source_file", "target" => "missing.txt", "covers" => ["req.1"]},
                %{"kind" => "source_file", "target" => "", "covers" => []},
                %{
                  "kind" => "command",
                  "target" => "printf ok",
                  "covers" => ["req.1"],
                  "execute" => true
                },
                %{
                  "kind" => "command",
                  "target" => "printf boom && exit 2",
                  "covers" => ["req.1"],
                  "execute" => true
                },
                %{
                  "kind" => "command",
                  "target" => "printf skip",
                  "covers" => ["req.1"],
                  "execute" => false
                },
                %{"kind" => "command", "target" => "", "covers" => []},
                %{
                  "kind" => "command",
                  "target" => "printf noop",
                  "covers" => ["unknown.claim"],
                  "execute" => false
                }
              ],
              "exceptions" => [
                %{"id" => "exception.one", "covers" => ["req.2"], "reason" => "accepted"}
              ]
            })
          ]
        },
        root,
        debug: true,
        run_commands: true
      )

    assert report["status"] == "fail"

    assert finding_codes(report) ==
             MapSet.new([
               "verification_missing_target",
               "verification_target_missing",
               "verification_command_failed",
               "verification_missing_command",
               "verification_unknown_cover"
             ])

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_target_exists" and &1["status"] == "pass")
           )

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_command_passed" and &1["status"] == "pass")
           )

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_command_skipped" and &1["status"] == "pass")
           )

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_command_failed" and &1["status"] == "error")
           )

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_cover_valid" and &1["status"] == "pass")
           )

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_cover_unknown" and &1["status"] == "warning")
           )
  end

  test "verify reports unknown verification kinds and excludes them from coverage", %{root: root} do
    report =
      Verifier.verify(
        %{
          "subjects" => [
            base_subject(%{
              "requirements" => [%{"id" => "req.typo", "statement" => "Must be covered"}],
              "verification" => [
                %{"kind" => "typo_kind", "target" => "ignored", "covers" => ["req.typo"]}
              ]
            })
          ]
        },
        root,
        debug: true
      )

    assert report["status"] == "fail"
    assert report["summary"]["errors"] == 1
    assert report["summary"]["warnings"] == 1

    assert finding_codes(report) ==
             MapSet.new([
               "verification_unknown_kind",
               "requirement_without_verification"
             ])

    assert Enum.any?(
             report["checks"],
             &(&1["code"] == "verification_kind_invalid" and &1["status"] == "error")
           )
  end

  test "verify only executes command verifications once in debug mode", %{root: root} do
    report =
      Verifier.verify(
        %{
          "subjects" => [
            base_subject(%{
              "requirements" => [%{"id" => "req.run", "statement" => "Run exactly once"}],
              "verification" => [
                %{
                  "kind" => "command",
                  "target" => "printf run >> runs.txt",
                  "covers" => ["req.run"],
                  "execute" => true
                }
              ]
            })
          ]
        },
        root,
        debug: true,
        run_commands: true
      )

    assert report["status"] == "pass"
    assert File.read!(Path.join(root, "runs.txt")) == "run"
  end

  test "verify only fails warnings in strict mode", %{root: root} do
    index = %{
      "subjects" => [
        base_subject(%{"requirements" => [%{"id" => "req.only", "statement" => "Uncovered"}]})
      ]
    }

    non_strict = Verifier.verify(index, root)
    strict = Verifier.verify(index, root, strict: true)

    assert non_strict["status"] == "pass"
    assert strict["status"] == "fail"
    assert non_strict["summary"]["warnings"] == 1
    assert strict["summary"]["warnings"] == 1
  end

  test "verify emits pass-oriented debug checks for clean subjects", %{root: root} do
    report =
      Verifier.verify(
        %{
          "subjects" => [
            base_subject(%{
              "requirements" => [%{"id" => "req.clean", "statement" => "Covered"}],
              "scenarios" => [
                %{
                  "id" => "scenario.clean",
                  "covers" => ["req.clean"],
                  "given" => ["given"],
                  "when" => ["when"],
                  "then" => ["then"]
                }
              ],
              "verification" => [
                %{"kind" => "command", "target" => "mix test", "covers" => ["req.clean"]}
              ]
            })
          ]
        },
        root,
        debug: true
      )

    assert report["status"] == "pass"
    assert report["summary"]["warnings"] == 0

    assert check_codes(report) ==
             MapSet.new([
               "meta_field_present",
               "parse_blocks",
               "requirement_id_present",
               "scenario_id_present",
               "scenario_cover_valid",
               "verification_command_present",
               "verification_cover_valid",
               "requirement_has_verification",
               "duplicate_subject_id",
               "duplicate_requirement_id"
             ])
  end

  defp base_subject(overrides) do
    Map.merge(
      %{
        "file" => ".spec/specs/example.spec.md",
        "meta" => %{"id" => "example.subject", "kind" => "module", "status" => "active"},
        "requirements" => [],
        "scenarios" => [],
        "verification" => [],
        "exceptions" => [],
        "parse_errors" => []
      },
      overrides
    )
  end

  defp finding_codes(report) do
    report["findings"]
    |> Enum.map(& &1["code"])
    |> MapSet.new()
  end

  defp check_codes(report) do
    report["checks"]
    |> Enum.map(& &1["code"])
    |> MapSet.new()
  end
end
