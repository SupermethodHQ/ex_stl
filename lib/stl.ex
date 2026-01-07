defmodule Stl do
  @moduledoc ~S"""
    A fast and reliable Elixir library for decomposing time series data using STL (Seasonal and Trend decomposition using Loess). This package provides Elixir bindings to the STL C++ library `https://github.com/ankane/stl-cpp` using Fine to handle implementing the NIF.

    It supports both Seasonal-trend and Multi Seasonal-trend decomposition using `decompose/2` and `decompose/3` respectively, with the ability to smooth outliers with `robust` decomposition. See the docs for `decompose/2` and `decompose/3` for more details.

    For a single seasonal trend, you can pass a list of values or a Date keyed map as the series.

    ```
    # Decompose a simple list with a weekly seasonal pattern
    series = [5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0, 8.0, 5.0, 8.0, 7.0, 8.0, 8.0, 0.0, 2.0, 5.0, 0.0, 5.0, 6.0, 7.0, 3.0, 6.0, 1.0, 4.0, 4.0, 4.0, 3.0, 7.0, 5.0, 8.0]

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
    The series must contain at least two full cycles of the largest period.

    ```
    # With 30 data points, we can use periods up to 15 (need 2x periods of data)
    Stl.decompose(series, [7, 14])
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

  STL separates a time series into three components:
  - **Seasonal**: The repeating pattern at the given period
  - **Trend**: The underlying long-term direction
  - **Remainder**: What's left after removing seasonal and trend (noise/anomalies)

  ## Parameters

  * `series` - A list of numbers, or a map with date/time keys and numeric values.
  * `period` - The seasonal period as an integer (must be >= 2), or a list of integers for MSTL.
  * `opts` - Optional keyword list (see Options below).

  ## STL Options

  * `:seasonal_length` - Length of the seasonal smoother (default: 7).
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
  * `:robust` - Enable robust fitting to reduce the impact of outliers (default: false).
  * `:include_weights` - Include robustness weights in the result (default: false).

  ## MSTL Options

  * `:iterations` - Number of iterations for MSTL.
  * `:lambda` - Lambda for Box-Cox transformation (between 0 and 1). Requires all positive values.
  * `:seasonal_lengths` - Lengths of the seasonal smoothers (one per period).

  ## Return Value

  Returns a map with:
  - `:seasonal` - List of seasonal component values (or list of lists for MSTL)
  - `:trend` - List of trend component values
  - `:remainder` - List of remainder values
  - `:weights` - List of robustness weights (only when `robust: true` or `include_weights: true`)

  ## Examples

  ### Basic decomposition with a list

  Pass a list of numeric values and specify the seasonal period:

      iex> series = [5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0, 8.0, 5.0, 8.0,
      ...>           7.0, 8.0, 8.0, 0.0, 2.0, 5.0, 0.0, 5.0, 6.0, 7.0,
      ...>           3.0, 6.0, 1.0, 4.0, 4.0, 4.0, 3.0, 7.0, 5.0, 8.0]
      iex> result = Stl.decompose(series, 7)
      iex> length(result.seasonal)
      30
      iex> length(result.trend)
      30
      iex> length(result.remainder)
      30

  The components sum back to the original series:

      iex> series = [5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0]
      iex> result = Stl.decompose(series, 2)
      iex> reconstructed = Enum.zip([result.seasonal, result.trend, result.remainder])
      ...> |> Enum.map(fn {s, t, r} -> s + t + r end)
      iex> Enum.zip(series, reconstructed) |> Enum.all?(fn {a, b} -> abs(a - b) < 0.0001 end)
      true

  ### Decomposition with a date-keyed map

  Maps are automatically sorted chronologically before decomposition:

      iex> today = ~D[2024-01-01]
      iex> series = %{
      ...>   Date.add(today, 0) => 5.0,
      ...>   Date.add(today, 1) => 9.0,
      ...>   Date.add(today, 2) => 2.0,
      ...>   Date.add(today, 3) => 9.0,
      ...>   Date.add(today, 4) => 0.0,
      ...>   Date.add(today, 5) => 6.0,
      ...>   Date.add(today, 6) => 3.0
      ...> }
      iex> result = Stl.decompose(series, 2)
      iex> length(result.seasonal)
      7

  ### Robust decomposition (handling outliers)

  Use `robust: true` to reduce the impact of outliers. This also returns weights indicating how much each point was downweighted (lower = more anomalous):

      iex> series = [5.0, 9.0, 2.0, 9.0, 100.0, 6.0, 3.0, 8.0, 5.0, 8.0]
      iex> result = Stl.decompose(series, 2, robust: true)
      iex> Map.has_key?(result, :weights)
      true
      iex> length(result.weights)
      10

  ### Multi-seasonal decomposition (MSTL)

  For data with multiple seasonal patterns, pass a list of periods. The result
  contains a list of seasonal components, one per period. The series must have
  at least two full cycles of the largest period.

  ```elixir
  # Generate sample data with two seasonal patterns (period 3 and period 7)
  series = for i <- 0..99 do
    3.0 * :math.sin(2 * :math.pi * i / 3) +    # period-3 pattern
    2.0 * :math.sin(2 * :math.pi * i / 7) +    # period-7 pattern
    0.1 * i +                                   # slight trend
    :rand.uniform()                             # noise
  end

  result = Stl.decompose(series, [3, 7])

  # Access individual seasonal components
  [seasonal_3, seasonal_7] = result.seasonal
  trend = result.trend
  remainder = result.remainder
  ```

  MSTL with additional options:

  ```elixir
  result = Stl.decompose(series, [3, 7],
    iterations: 3,
    seasonal_lengths: [5, 9]
  )
  ```

  Box-Cox transformation for variance stabilization (requires all positive values):

  ```elixir
  # Ensure all values are positive for Box-Cox
  positive_series = Enum.map(series, &(&1 + 10.0))

  result = Stl.decompose(positive_series, [3, 7], lambda: 0.5)
  ```
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

    result = %{seasonal: seasonal, trend: trend, remainder: remainder}

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

  defp extract_series_values(series) when is_list(series), do: series

  defp extract_series_values(series) when is_map(series) do
    series
    |> Enum.sort(&sort_series/2)
    |> Enum.map(fn {_, v} -> v end)
  end

  defp sort_series({%Date{} = left, _}, {%Date{} = right, _}), do: Date.compare(left, right) != :gt
  defp sort_series({%NaiveDateTime{} = left, _}, {%NaiveDateTime{} = right, _}), do: NaiveDateTime.compare(left, right) != :gt
  defp sort_series({%DateTime{} = left, _}, {%DateTime{} = right, _}), do: DateTime.compare(left, right) != :gt
  defp sort_series({left, _}, {right, _}), do: to_unix(left) <= to_unix(right)

  defp to_unix(%Date{} = d), do: d |> DateTime.new!(~T[00:00:00], "Etc/UTC") |> DateTime.to_unix()
  defp to_unix(%NaiveDateTime{} = dt), do: dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  defp to_unix(%DateTime{} = dt), do: DateTime.to_unix(dt)
  defp to_unix(x), do: x

  @doc """
  Calculate the seasonal strength from a decomposition result.

  Seasonal strength measures how much of the variation in the data is explained by the seasonal component versus random noise. It's calculated as:

      Fs = max(0, 1 - Var(remainder) / Var(seasonal + remainder))

  ## Return Value

  A float between 0.0 and 1.0:
  - **0.0**: No seasonality detected (variation is all noise)
  - **1.0**: Perfect seasonality (no noise)
  - **> 0.6**: Generally indicates meaningful seasonal pattern

  ## Parameters

  * `result` - A decomposition result map containing `:seasonal` and `:remainder` keys.

  ## Examples

  Strong seasonality (alternating high/low pattern):

      iex> result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], 2)
      iex> Stl.seasonal_strength(result)
      0.9422302715663797

  Comparing different seasonal periods to find the best fit:

      iex> data = [5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0, 8.0, 5.0, 8.0, 7.0, 8.0]
      iex> result_2 = Stl.decompose(data, 2)
      iex> result_3 = Stl.decompose(data, 3)
      iex> Stl.seasonal_strength(result_2) > Stl.seasonal_strength(result_3)
      true

  ### Practical usage: detecting if decomposition is meaningful

  ```elixir
  result = Stl.decompose(sales_data, 7)
  seasonal_strength = Stl.seasonal_strength(result)

  if seasonal_strength > 0.6 do
    IO.puts("Strong weekly pattern detected!")
    # Use seasonal component for forecasting
  else
    IO.puts("Weak or no weekly pattern")
    # Consider different period or non-seasonal model
  end
  ```
  """
  @spec seasonal_strength(t()) :: float()
  def seasonal_strength(%{seasonal: s, remainder: r}), do: Stl.NIF.seasonal_strength(s, r)

  @doc """
  Calculate the trend strength from a decomposition result.

  Trend strength measures how much of the variation in the data is explained by the trend component versus random noise. It's calculated as:

      Ft = max(0, 1 - Var(remainder) / Var(trend + remainder))

  ## Return Value

  A float between 0.0 and 1.0:
  - **0.0**: No trend detected (variation is all noise)
  - **1.0**: Perfect trend (no noise)
  - **> 0.6**: Generally indicates meaningful trend

  ## Parameters

  * `result` - A decomposition result map containing `:trend` and `:remainder` keys.

  ## Examples

  Strong trend:

      iex> result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], 2)
      iex> Stl.trend_strength(result)
      0.727898191447705

  Detecting an upward trend in data:

      iex> upward = [1.0, 2.1, 2.9, 4.2, 4.8, 6.1, 7.0, 7.9, 9.2, 10.0]
      iex> result = Stl.decompose(upward, 2)
      iex> strength = Stl.trend_strength(result)
      iex> strength > 0.9
      true

  ### Practical usage: combining trend and seasonal strength

  ```elixir
  result = Stl.decompose(sales_data, 7)

  seasonal = Stl.seasonal_strength(result)
  trend = Stl.trend_strength(result)

  cond do
    trend > 0.8 and seasonal > 0.6 ->
      IO.puts("Strong upward/downward trend with weekly pattern")

    trend > 0.8 ->
      IO.puts("Strong trend, weak seasonality - focus on trend for forecasting")

    seasonal > 0.6 ->
      IO.puts("Strong weekly pattern, weak trend - stable seasonal business")

    true ->
      IO.puts("Weak patterns - data may be mostly noise")
  end
  ```

  ### Visualizing the decomposition

  ```elixir
  result = Stl.decompose(data, 7)

  IO.puts("Seasonal strength: \#{Stl.seasonal_strength(result) |> Float.round(2)}")
  IO.puts("Trend strength: \#{Stl.trend_strength(result) |> Float.round(2)}")

  # Plot or export components
  %{seasonal: seasonal, trend: trend, remainder: remainder} = result
  ```
  """
  @spec trend_strength(t()) :: float()
  def trend_strength(%{trend: t, remainder: r}), do: Stl.NIF.trend_strength(t, r)

end
