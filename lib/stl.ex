defmodule Stl do
  @moduledoc """
  Seasonal-trend decomposition for Elixir using STL.cpp
  """

  @typedoc "Result of STL decomposition."
  @type t :: %{
    required(:seasonal) => [float()],
    required(:trend) => [float()],
    required(:remainder) => [float()],
    optional(:weights) => [float()]
  }

  @typedoc "Result of a robust STL decomposition."
  @type robust_stl :: %{
    required(:seasonal) => [float()],
    required(:trend) => [float()],
    required(:remainder) => [float()],
    required(:weights) => [float()]
  }

  @doc """
  Decompose a time series using STL (Seasonal and Trend decomposition using Loess).

  ## Parameters
  * `series` - A list of numbers or a map with keys (e.g., dates) and values.
  * `opts` - Options for the decomposition:
    * `:period` - REQUIRED: The period of the seasonal component (must be >= 2).
    * `:seasonal_length` - Length of the seasonal smoother.
    * `:trend_length` - Length of the trend smoother.
    * `:low_pass_length` - Length of the low-pass filter.
    * `:seasonal_degree` - Degree of locally-fitted polynomial in seasonal smoothing (0 or 1).
    * `:trend_degree` - Degree of locally-fitted polynomial in trend smoothing (0 or 1).
    * `:low_pass_degree` - Degree of locally-fitted polynomial in low-pass smoothing (0 or 1).
    * `:seasonal_jump` - Skipping value for seasonal smoothing.
    * `:trend_jump` - Skipping value for trend smoothing.
    * `:low_pass_jump` - Skipping value for low-pass smoothing.
    * `:inner_loops` - Number of loops for updating the seasonal and trend components.
    * `:outer_loops` - Number of iterations of robust fitting.
    * `:robust` - If robustness iterations are to be used (boolean).
    * `:include_weights` - Whether to include robustness weights in the result (boolean).
  """
  @spec decompose([number()] | map(), Stl.Params.t()) :: t()
  def decompose(series, opts) do
    period = Keyword.fetch!(opts, :period)

    if period < 2 do
      raise ArgumentError, "period must be greater than 1"
    end

    series_values = extract_series_values(series)
    include_weights = Keyword.get(opts, :include_weights, false) || Keyword.get(opts, :robust, false)
    params = struct(Stl.Params, opts)

    {seasonal, trend, remainder, weights} = Stl.NIF.decompose(series_values, period, params, include_weights)

    result = %{
      seasonal: seasonal,
      trend: trend,
      remainder: remainder
    }

    # Add weights if requested or if robust is true
    if include_weights && weights != [],
      do: Map.put(result, :weights, weights),
    else: result
  end

  @doc """
  Calculate the seasonal strength from a decomposition result.

  Returns a float value between 0 and 1 representing the seasonal strength to signify a detected seasonal trend.

  Values range from 0.0 to 1.0, where:
  - 0.0 means no strength
  - 1.0 means maximum strength

  ## Examples
      iex> result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], period: 2)
      iex> Stl.seasonal_strength(result)
      0.9422302715663797
  """
  @spec seasonal_strength(t()) :: float()
  def seasonal_strength(%{seasonal: s, remainder: r}), do: Stl.NIF.seasonal_strength(s, r)

  @doc """
  Calculate the trend strength from a decomposition result.

  Expects a decomposition map containing `:trend` and `:remainder` components.

  Returns a float value between 0 and 1 representing the trend strength.

  ## Examples

      iex> result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], period: 2)
      iex> Stl.trend_strength(result)
      0.727898191447705
  """
  @spec trend_strength(t()) :: float()
  def trend_strength(%{trend: t, remainder: r}), do: Stl.NIF.trend_strength(t, r)

  defp extract_series_values(series) when is_list(series), do: series

  defp extract_series_values(series) when is_map(series) do
    series
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map(fn {_, v} -> v end)
  end
end
