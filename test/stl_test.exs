defmodule StlTest do
  use ExUnit.Case
  doctest Stl

  @series [
    5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0, 8.0, 5.0, 8.0,
    7.0, 8.0, 8.0, 0.0, 2.0, 5.0, 0.0, 5.0, 6.0, 7.0,
    3.0, 6.0, 1.0, 4.0, 4.0, 4.0, 3.0, 7.0, 5.0, 8.0
  ]

  test "decomposes a map with dates" do
    today = Date.utc_today()
    result =
      @series
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {value, index}, acc ->
            Map.put(acc, Date.add(today, index), value)
          end)
      |> Stl.decompose(7)

    seasonal = [0.10646757483482361, 0.704910397529602, -1.1810311079025269, 0.9291385412216187, -0.43146127462387085]
    trend = [3.912654161453247, 4.210334300994873, 4.50801420211792, 4.752384662628174, 4.996755123138428]
    remainder = [-0.019121646881103516, -0.9152445793151855, 0.6730170249938965, -2.681523323059082, 2.434706211090088]

    assert_elements_in_delta(seasonal, Enum.take(result.seasonal, 5))
    assert_elements_in_delta(trend, Enum.take(result.trend, 5))
    assert_elements_in_delta(remainder, Enum.take(result.remainder, 5))
  end

  test "decomposes a list" do
    result = Stl.decompose(@series, 7)

    seasonal = [0.3692665100097656, 0.7565547227859497, -1.3324145078659058, 1.9553654193878174, -0.6044800877571106]
    trend = [4.804096698760986, 4.909707069396973, 5.015316963195801, 5.160449981689453, 5.305583477020264]
    remainder = [-0.17336320877075195, 3.333738327026367, -1.6829023361206055, 1.8841848373413086, -4.701103210449219]

    assert_elements_in_delta(seasonal, Enum.take(result.seasonal, 5))
    assert_elements_in_delta(trend, Enum.take(result.trend, 5))
    assert_elements_in_delta(remainder, Enum.take(result.remainder, 5))
  end

  test "works with robustness" do
    result = Stl.decompose(@series, 7, robust: true)

    seasonal = [0.1492234170436859, 0.47939032316207886, -1.8332310914993286, 1.741138219833374, 0.8200711011886597]
    trend = [5.397364139556885, 5.474542617797852, 5.551721572875977, 5.649918079376221, 5.748114585876465]
    remainder = [-0.5465874671936035, 3.046067237854004, -1.7184906005859375, 1.6089434623718262, -6.568185806274414]
    weights = [0.9937492609024048, 0.8129377961158752, 0.9385949969291687, 0.945803701877594, 0.2974221408367157]

    assert_elements_in_delta(seasonal, Enum.take(result.seasonal, 5))
    assert_elements_in_delta(trend, Enum.take(result.trend, 5))
    assert_elements_in_delta(remainder, Enum.take(result.remainder, 5))
    assert Map.has_key?(result, :weights)
    assert_elements_in_delta(weights, Enum.take(result.weights, 5))
  end

  test "handles repeating patterns" do
    result =
      0..23
      |> Enum.shuffle()
      |> List.duplicate(8)
      |> List.flatten()
      |> Stl.decompose(24)

    # The remainder should be approximately 0
    assert_all_elements_close_to_zero(result.remainder)

    # The trend should be approximately 11.5 (average of 0..23)
    assert_all_elements_close_to(result.trend, 11.5)
  end

  test "raises error for period = 1" do
    assert_raise ArgumentError, "period must be greater than 1", fn ->
      Stl.decompose(@series, 1)
    end
  end

  test "raises error for too few periods" do
    assert_raise ArgumentError, "series has less than two periods", fn ->
      Stl.decompose(@series, 16)
    end
  end

  test "raises error for invalid seasonal_degree" do
    assert_raise ArgumentError, "seasonal_degree must be 0 or 1", fn ->
      Stl.decompose(@series, 7, seasonal_degree: 2)
    end
  end

  test "calculates seasonal_strength" do
    result = Stl.decompose(@series, 7)

    assert_in_delta(0.28411169658385693, Stl.seasonal_strength(result), 0.001)
  end

  test "calculates seasonal_strength maximal value" do
    result =
      0..29
      |> Enum.map(&rem(&1, 7))
      |> Stl.decompose(7)

    assert_in_delta(1.0, Stl.seasonal_strength(result), 0.001)
  end

  test "calculates trend_strength" do
    result = Stl.decompose(@series, 7)

    assert_in_delta(0.16384239106781462, Stl.trend_strength(result), 0.001)
  end

  test "calculates trend_strength maximal value" do
    result =
      0..29
      |> Enum.to_list()
      |> Stl.decompose(7)

    assert_in_delta(1.0, Stl.trend_strength(result), 0.001)
  end

  test "works with small series" do
    result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], 2)

    assert_in_delta(0.9422302715663797, Stl.seasonal_strength(result), 0.001)
    assert_in_delta(0.727898191447705, Stl.trend_strength(result), 0.001)
  end

  # Helper functions for assertions
  defp assert_elements_in_delta(expected, actual, delta \\ 0.001) do
    expected
    |> Enum.zip(actual)
    |> Enum.each(fn {e, a} -> assert_in_delta(e, a, delta) end)
  end

  defp assert_all_elements_close_to_zero(values, delta \\ 0.001) do
    Enum.each(values, &assert_in_delta(0.0, &1 , delta))
  end

  defp assert_all_elements_close_to(values, target, delta \\ 0.1) do
    Enum.each(values, &assert_in_delta(target, &1, delta))
  end

  # MSTL tests
  describe "mstl (multi-seasonal decomposition)" do
    test "basic mstl decomposition with multiple periods" do
      series = @series  # Using the same test series defined at the top of the file
      result = Stl.decompose(series, [6, 10])

      # Check that we have the right keys
      assert Map.has_key?(result, :seasonal)
      assert Map.has_key?(result, :trend)
      assert Map.has_key?(result, :remainder)

      # Check that seasonal is a list of seasonal components (one per period)
      assert is_list(result.seasonal)
      assert length(result.seasonal) == 2

      # Each seasonal component should have the same length as the original series
      assert length(Enum.at(result.seasonal, 0)) == length(series)
      assert length(Enum.at(result.seasonal, 1)) == length(series)

      # Check that trend and remainder have the same length as the original series
      assert length(result.trend) == length(series)
      assert length(result.remainder) == length(series)

      # First seasonal component (period 6)
      assert_elements_in_delta(
        [0.28318232, 0.70529824, -1.980384, 2.1643379, -2.3356874],
        Enum.take(Enum.at(result.seasonal, 0), 5)
      )

      # Second seasonal component (period 10)
      assert_elements_in_delta(
        [1.4130436, 1.6048906, 0.050958008, -1.8706754, -1.7704514],
        Enum.take(Enum.at(result.seasonal, 1), 5)
      )

      # Trend component
      assert_elements_in_delta(
        [5.139485, 5.223691, 5.3078976, 5.387292, 5.4666862],
        Enum.take(result.trend, 5)
      )

      # Remainder component
      assert_elements_in_delta(
        [-1.835711, 1.4661198, -1.3784716, 3.319045, -1.3605475],
        Enum.take(result.remainder, 5)
      )
    end

    test "mstl with iterations parameter" do
      # Test with iterations=2 vs iterations=5
      result1 = Stl.decompose(@series, [6, 10], iterations: 2)
      result2 = Stl.decompose(@series, [6, 10], iterations: 5)

      # Results should be different with different iteration counts
      refute Enum.at(result1.seasonal, 0) == Enum.at(result2.seasonal, 0)
      refute Enum.at(result1.seasonal, 1) == Enum.at(result2.seasonal, 1)
    end

    test "mstl with lambda parameter" do
      # Test with Box-Cox transformation (lambda=0.5)
      result = Stl.decompose(@series, [6, 10], lambda: 0.5)

      # Values should match the expected results with lambda=0.5
      assert_elements_in_delta(
        [0.43371448, 0.10503793, -0.7178911, 1.2356076, -1.8253292],
        Enum.take(Enum.at(result.seasonal, 0), 5)
      )
    end

    test "mstl with seasonal_lengths parameter" do
      # Test with custom seasonal lengths
      result = Stl.decompose(@series, [6, 10], seasonal_lengths: [9, 19])

      # Results should be valid (we can't easily predict exact values)
      assert length(Enum.at(result.seasonal, 0)) == length(@series)
      assert length(Enum.at(result.seasonal, 1)) == length(@series)
    end

    test "mstl with multiple STL parameters" do
      # Test with a mix of regular STL and MSTL parameters
      result = Stl.decompose(@series, [6, 10],
        iterations: 3,
        lambda: 0.5,
        seasonal_lengths: [9, 19],
        seasonal_degree: 1,
        trend_degree: 0,
        robust: true
      )

      # Results should be valid
      assert length(Enum.at(result.seasonal, 0)) == length(@series)
      assert length(Enum.at(result.seasonal, 1)) == length(@series)
      assert length(result.trend) == length(@series)
      assert length(result.remainder) == length(@series)
    end

    test "mstl with periods in different order" do
      # Test with periods in different orders
      result1 = Stl.decompose(@series, [6, 10])
      result2 = Stl.decompose(@series, [10, 6])

      # Get the seasonal components
      first_seasonal_result1 = Enum.at(result1.seasonal, 0)  # Should be for period 6
      second_seasonal_result1 = Enum.at(result1.seasonal, 1) # Should be for period 10
      first_seasonal_result2 = Enum.at(result2.seasonal, 0)  # Should be for period 10
      second_seasonal_result2 = Enum.at(result2.seasonal, 1) # Should be for period 6

      # The first seasonal component of result1 should correspond to the second of result2
      # and vice versa, since the periods are specified in reverse order
      assert_elements_in_delta(first_seasonal_result1, second_seasonal_result2, 0.5)
      assert_elements_in_delta(second_seasonal_result1, first_seasonal_result2, 0.5)

      # They should NOT be equal (previous test assertion was incorrect)
      refute first_seasonal_result1 == first_seasonal_result2

      # The trend and remainder should be similar, though not necessarily identical
      assert_elements_in_delta(result1.trend, result2.trend, 0.5)
      assert_elements_in_delta(result1.remainder, result2.remainder, 0.5)
    end

    test "mstl error handling - empty periods list" do
      assert_raise ArgumentError, "periods must not be empty", fn ->
        Stl.decompose(@series, [])
      end
    end

    test "mstl error handling - invalid period" do
      assert_raise ArgumentError, "periods must be at least 2", fn ->
        Stl.decompose(@series, [1, 7])
      end
    end

    test "mstl error handling - series too short" do
      # Generate a short series with only 10 points
      short_series = Enum.take(@series, 10)

      assert_raise ArgumentError, "series has less than two periods", fn ->
        # Try with a period of 6, which requires at least 12 points
        Stl.decompose(short_series, [6])
      end
    end
  end

end
