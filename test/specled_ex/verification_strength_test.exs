defmodule SpecLedEx.VerificationStrengthTest do
  use ExUnit.Case

  alias SpecLedEx.VerificationStrength

  test "levels and default remain stable" do
    assert VerificationStrength.levels() == ~w(claimed linked executed)
    assert VerificationStrength.default() == "claimed"
    assert VerificationStrength.valid?("linked")
    refute VerificationStrength.valid?("strongest")
  end

  test "normalize and compare enforce the proof ordering" do
    assert VerificationStrength.normalize("executed") == {:ok, "executed"}
    assert VerificationStrength.normalize(nil) == {:ok, nil}
    assert {:error, message} = VerificationStrength.normalize("strongest")
    assert message =~ "claimed, linked, executed"

    assert VerificationStrength.compare("claimed", "linked") == :lt
    assert VerificationStrength.compare("linked", "claimed") == :gt
    assert VerificationStrength.compare("executed", "executed") == :eq

    assert VerificationStrength.meets_minimum?("executed", "linked")
    assert VerificationStrength.meets_minimum?("linked", "linked")
    refute VerificationStrength.meets_minimum?("claimed", "linked")
  end
end
