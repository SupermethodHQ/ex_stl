defmodule Stl.Utils do
  @moduledoc """
  Utility functions for working with STL decompositions.
  """

  @doc """
  Calculate the variance of a list of numbers.

  ## Parameters

  * `series` - A list of numbers.

  ## Returns

  The variance of the series.
  """
  def var(series) do
    mean = Enum.sum(series) / length(series)

    sum_squared_diffs =
      series
      |> Enum.map(&:math.pow(&1 - mean, 2))
      |> Enum.sum()

    sum_squared_diffs / (length(series) - 1)
  end

  @doc """
  Formats date or datetime value to ISO8601 string.

  ## Parameters

  * `value` - A Date or DateTime value.

  ## Returns

  An ISO8601 formatted string.
  """
  def iso8601(%Date{} = date), do: Date.to_iso8601(date)
  def iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  def iso8601(other), do: other
end
