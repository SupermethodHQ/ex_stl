defmodule Stl.Params do
  @moduledoc false

  @type t :: [
    seasonal_length: pos_integer() | nil,
    trend_length: pos_integer() | nil,
    low_pass_length: pos_integer() | nil,
    seasonal_degree: 0 | 1 | nil,
    trend_degree: 0 | 1 | nil,
    low_pass_degree: 0 | 1 | nil,
    seasonal_jump: pos_integer() | nil,
    trend_jump: pos_integer() | nil,
    low_pass_jump: pos_integer() | nil,
    inner_loops: non_neg_integer() | nil,
    outer_loops: non_neg_integer() | nil,
    robust: boolean() | nil,
    iterations: pos_integer() | nil,
    lambda: float() | nil,
    seasonal_lengths: [pos_integer()] | nil
  ]

  defstruct [
    :seasonal_length,
    :trend_length,
    :low_pass_length,
    :seasonal_degree,
    :trend_degree,
    :low_pass_degree,
    :seasonal_jump,
    :trend_jump,
    :low_pass_jump,
    :inner_loops,
    :outer_loops,
    :robust,
    :iterations,
    :lambda,
    :seasonal_lengths
  ]
end
