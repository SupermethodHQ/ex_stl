# STL

A fast and reliable Elixir library for decomposing time series data using STL (Seasonal and Trend decomposition using Loess). This package provides Elixir bindings to the [STL C++ library](https://github.com/ankane/stl-cpp) using [Fine](https://github.com/elixir-nx/fine) to handle implementing the NIF.

## What is STL?

STL (Seasonal and Trend decomposition using Loess) is a versatile and robust method for decomposing time series data into three components:

- _Seasonal component_: Repeating patterns at fixed periods (e.g., daily, weekly, monthly cycles)
- _Trend component_: Long-term progression of the series (increasing, decreasing, or stable)
- _Remainder component_: Residual variation after removing seasonal and trend components

STL has several advantages over other decomposition methods:

Handles any type of seasonality (not just monthly or quarterly)
Allows the seasonal component to change over time
Supports robust decomposition that's resistant to outliers
Can handle missing values
Works efficiently with large datasets

## Use Cases

STL decomposition is useful for:

- _Forecasting_: Isolating seasonal patterns to better predict future values
- _Anomaly detection_: Identifying unusual observations that don't fit expected patterns
- _Seasonal adjustment_: Removing seasonal effects to focus on the trend
- _Data visualization_: Understanding underlying patterns in complex time series
- _Feature engineering_: Creating better inputs for machine learning models

## Installation

Add STL to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_stl, "~> 0.1.0"}
  ]
end
```

## Getting Started

### Basic Usage

```elixir
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

### Working with Dates

It's important to understand how periods, time series, and seasonality relate to each other. A time series is a sequence of data points measured over time, which can contain various patterns. Seasonality refers to regular, predictable patterns that repeat at fixed intervals. The period parameter specifies exactly how many data points make up one complete seasonal cycle.

For example, with daily data, a weekly seasonality would have a period of 7, monthly patterns would have a period of ~30, and yearly patterns would have a period of 365. STL requires at least two complete seasonal cycles (periods) in your data to accurately identify and separate the components.

If you're analyzing weekly patterns e.g. `decompose(series, 7)`, your time series must contain at least 14 data points. This minimum data requirement ensures the algorithm can distinguish between true seasonal patterns and random fluctuations. When selecting your period, consider the dominant cyclical pattern in your data and ensure your series is long enough to cover multiple complete cycles of that pattern.

```elixir
# Create a time series with dates
today = Date.utc_today()
date_series = %{
  Date.add(today, -6) => 100,
  Date.add(today, -5) => 150,
  Date.add(today, -4) => 136,
  Date.add(today, -3) => 120,
  Date.add(today, -2) => 110,
  Date.add(today, -1) => 125,
  today => 145
}

# The keys are automatically sorted by date before decomposition
result = Stl.decompose(date_series, 3)
# %{remainder: [-4.0567626953125, 4.250129699707031, 2.4298858642578125, -1.2078704833984375, -3.82452392578125, -4.5297393798828125, 5.8429718017578125], seasonal: [-23.82843589782715, 18.479854583740234, 6.906088352203369, -4.961262226104736, -12.621232032775879, 2.7985377311706543, 11.959086418151855], trend: [127.88520050048828, 127.27001190185547, 126.66403198242188, 126.16913604736328, 126.44575500488281, 126.731201171875, 127.19793701171875]}
```

### Robust Decomposition

Time series data often contains outliers (values that deviate significantly from the normal pattern) which can distort decomposition results and lead to misleading interpretations. STL addresses this challenge through with a robust decomposition option, which applies an iterative reweighting process that progressively reduces the influence of outliers.

When you enable robust decomposition with `robust: true`, the algorithm first performs a standard decomposition, then assigns weights to each data point based on its residual value. Points with large residuals (potential outliers) receive lower weights, while points that fit the pattern well receive weights closer to 1.0. The decomposition is then repeated using these weights, producing components that better reflect the underlying patterns without being unduly influenced by extreme values. This process may iterate multiple times, gradually refining the decomposition. The resulting weights field in the output provides valuable diagnostic information, helping you identify potential anomalies in your data. Robust decomposition is particularly valuable for real-world applications where data quality issues, measurement errors, or genuine but rare events might otherwise compromise your analysis

```elixir
# Enable robust decomposition
robust_result = Stl.decompose(series, 7, robust: true)

# Access the robustness weights
weights = robust_result.weights
# [0.9937492609024048, 0.8129377961158752, 0.9385949969291687, 0.945803701877594, 0.2974221408367157, 0.9562582969665527, 0.9998335838317871, 0.9263716340065002, 0.962205708026886, 0.7038362622261047, 0.9984459280967712, 0.9431878924369812, 0.9647709727287292, 0.8959962725639343, 0.8513858318328857, 0.9819113612174988, 0.8404646515846252, 0.9999964237213135, 0.9855114221572876, 0.957801342010498, 0.9971754550933838, 0.9446253776550293, 0.7950285077095032, 0.9813642501831055, 0.9678231477737427, 0.936883807182312, 0.7937986254692078, 0.8297039866447449, 0.9902045726776123, 0.906792163848877]
```

### Advanced Options

STL supports a lot of parameters to customise and tune the decomposition:

```elixir
result = Stl.decompose(series, 7,
  seasonal_length: 7,     # Length of the seasonal smoother
  trend_length: 15,       # Length of the trend smoother
  low_pass_length: 7,     # Length of the low-pass filter
  seasonal_degree: 0,     # Degree of locally-fitted polynomial in seasonal smoothing
  trend_degree: 1,        # Degree of locally-fitted polynomial in trend smoothing
  low_pass_degree: 1,     # Degree of locally-fitted polynomial in low-pass smoothing
  seasonal_jump: 1,       # Skipping value for seasonal smoothing
  trend_jump: 2,          # Skipping value for trend smoothing
  low_pass_jump: 1,       # Skipping value for low-pass smoothing
  inner_loops: 2,         # Number of loops for updating the seasonal and trend components
  outer_loops: 0,         # Number of iterations of robust fitting
  robust: false           # If robustness iterations are to be used
)
```

### Multiple Seasonal Patterns with MSTL

Many real-world time series exhibit multiple seasonal patterns simultaneously—for example, both daily and weekly cycles in hourly data, or both weekly and yearly patterns in daily data. For these complex cases, STL provides MSTL (Multiple Seasonal-Trend decomposition using Loess) support.

MSTL extends the standard STL algorithm to handle multiple seasonal components by decomposing the time series multiple times, each focusing on a different seasonal period. This allows you to extract distinct seasonal patterns at different frequencies from your data.

```elixir
# Decompose a time series with both weekly and monthly seasonal patterns
# You need at least two full cycles of each period
result = Stl.decompose(series, [7, 30])

# Access individual seasonal components (one per period)
weekly_seasonal = Enum.at(result.seasonal, 0)  # First element is period 7
monthly_seasonal = Enum.at(result.seasonal, 1) # Second element is period 30

# The trend and remainder components work the same as in standard STL
trend = result.trend
remainder = result.remainder
```

MSTL supports all the same parameters as standard STL, plus a few additional ones specific to multi-seasonal decomposition:

```elixir
result = Stl.decompose(series, [7, 30],
  # MSTL-specific parameters
  iterations: 2,                  # Number of iterations for MSTL process
  lambda: 0.5,                    # Lambda for Box-Cox transformation (0 to 1)
  seasonal_lengths: [11, 31],     # Custom lengths for the seasonal smoothers

  # Standard STL parameters are also supported
  trend_length: 15,
  robust: true
)
```

The order of periods matters in MSTL decomposition. The seasonal components in the result will have the same order as the periods specified in the input:

```elixir
# Different order of periods
result1 = Stl.decompose(series, [7, 30])
result2 = Stl.decompose(series, [30, 7])

# The seasonal components match the period order
weekly_from_result1 = Enum.at(result1.seasonal, 0)  # Period 7
monthly_from_result1 = Enum.at(result1.seasonal, 1) # Period 30

weekly_from_result2 = Enum.at(result2.seasonal, 1)  # Period 7
monthly_from_result2 = Enum.at(result2.seasonal, 0) # Period 30
```

MSTL is particularly useful for:

- Complex time series with multiple inherent cycles
- Data with nested seasonality (e.g., hourly data with daily, weekly, and yearly patterns)
- Forecasting applications where accounting for multiple seasonal patterns improves accuracy
- Isolating and analyzing different cyclical components separately

## Acknowledgements

This library is an Elixir binding to the [STL C++ library](https://github.com/ankane/stl-cpp), which is a port of the original [Fortran implementation](https://www.netlib.org/a/stl). All credit goes to [Andrew Kane](https://github.com/ankane) for doing the heavy lifting in the C++ port.

## References

- [STL: A Seasonal-Trend Decomposition Procedure Based on Loess](https://www.scb.se/contentassets/ca21efb41fee47d293bbee5bf7be7fb3/stl-a-seasonal-trend-decomposition-procedure-based-on-loess.pdf)
- [MSTL: A Seasonal-Trend Decomposition Algorithm for Time Series with Multiple Seasonal Patterns](https://arxiv.org/pdf/2107.13462.pdf)
- [Measuring strength of trend and seasonality](https://otexts.com/fpp2/seasonal-strength.html)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/supermethodhq/ex_stl/issues)
- Fix bugs and [submit pull requests](https://github.com/ex_stl/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

## License

This project is licensed under the MIT License - see the LICENSE file for details.
