defmodule Mix.Tasks.Spec.Check do
  use Mix.Task

  @shortdoc "Runs spec.plan and strict spec.verify"

  @impl true
  def run(args) do
    Mix.Task.run("spec.plan", args)
    Mix.Task.run("spec.verify", ["--strict" | args])
  end
end
