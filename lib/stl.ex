defmodule Stl do
  @moduledoc ~S"""
    A fast and reliable Elixir library for decomposing time series data using STL (Seasonal and Trend decomposition using Loess). This package provides Elixir bindings to the STL C++ library `https://github.com/ankane/stl-cpp` using Fine to handle implementing the NIF.

    It supports both Seasonal-trend and Multi Seasonal-trend decomposition using `decompose/2` and `decompose/3` respectively, with the ability to smooth outliers with `robust` decomposition. See the docs for `decompose/2` and `decompose/3` for more details.

    For a single seasonal trend, you can pass a list of values or a Date keyed map as the series.

    ```
    # Decompose a simple list with a weekly seasonal pattern
    series = [5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0, 8.0, 5.0, 8.0,
              7.0, 8.0, 8.0, 0.0, 2.0, 5.0, 0.0, 5.0, 6.0, 7.0,
              3.0, 6.0, 1.0, 4.0, 4.0, 4.0, 3.0, 7.0, 5.0, 8.0]

    result = Stl.decompose(series, 7)

    # Access the components
    seasonal = result.seasonal
    trend = result.trend
    remainder = result.remainder

    # Calculate strength measures
    seasonal_strength = Stl.seasonal_strength(result)
    trend_strength = Stl.trend_strength(result)

    IO.puts("Seasonal strength: #{seasonal_strength}")
    # Seasonal strength: 0.28411169658385693
    IO.puts("Trend strength: #{trend_strength}")
    # Trend strength: 0.16384239106781462
    ```

    For multi seasonal trends, the second param should be an integer list of periods.

    ```
    Stl.decompose(series, [7, 30])
    ```
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
  * `:period` - REQUIRED: The period of the seasonal component (must be >= 2).
  * `opts` - Options for the decomposition:
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
    * For MSTL (when period is a list):
    * `:iterations` - Number of iterations for MSTL.
    * `:lambda` - Lambda for Box-Cox transformation (between 0 and 1).
    * `:seasonal_lengths` - Lengths of the seasonal smoothers.

    ## Examples

    ### Standard STL decomposition (single period):
        # Decompose with weekly seasonality
        result = Stl.decompose(series, 7)

        # Access components
        seasonal = result.seasonal
        trend = result.trend
        remainder = result.remainder

        # With robustness
        result = Stl.decompose(series, 7, robust: true)
        weights = result.weights

    ### MSTL decomposition (multiple periods):
        # Decompose with both weekly and yearly seasonality
        result = Stl.decompose(series, [7, 365])

        # Access seasonal components
        weekly_seasonal = Enum.at(result.seasonal, 0)
        yearly_seasonal = Enum.at(result.seasonal, 1)

        # With additional MSTL options
        result = Stl.decompose(series, [7, 365],
          iterations: 2,
          lambda: 0.5,
          seasonal_lengths: [11, 731]
        )
  """
  @spec decompose([number()] | map(), pos_integer() | [pos_integer()], Stl.Params.t()) :: t()
  def decompose(series, period, opts \\ [])

  def decompose(_series, period, _opts) when period < 2 do
    raise ArgumentError, "period must be greater than 1"
  end

  def decompose(_series, [], _opts) do
    raise ArgumentError, "periods must not be empty"
  end

  def decompose(series, period, opts) when is_integer(period) do
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

  def decompose(series, periods, opts) when is_list(periods) do
    series_values = extract_series_values(series)
    params = struct(Stl.Params, opts)

    {seasonal, trend, remainder, _} = Stl.NIF.decompose_multi(series_values, periods, params)

    %{
      seasonal: seasonal,
      trend: trend,
      remainder: remainder
    }
  end

  @doc """
  Calculate the seasonal strength from a decomposition result.

  Returns a float value between 0 and 1 representing the seasonal strength to signify a detected seasonal trend.

  Values range from 0.0 to 1.0, where:
  - 0.0 means no strength
  - 1.0 means maximum strength

  ## Examples
      iex> result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], 2)
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

      iex> result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], 2)
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
