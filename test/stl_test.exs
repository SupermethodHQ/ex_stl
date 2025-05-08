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
      |> Stl.decompose(period: 7)

    seasonal = [0.6489728689193726, -1.2769339084625244, 0.8864244222640991, -0.3901793956756592, 0.9958359599113464]
    trend = [4.488394260406494, 4.697135925292969, 4.905877590179443, 5.052756309509277, 5.1996355056762695]
    remainder = [-1.1373672485351562, 0.5797977447509766, -2.792302131652832, 2.337423324584961, -1.1954712867736816]

    assert_elements_in_delta(seasonal, Enum.take(result.seasonal, 5))
    assert_elements_in_delta(trend, Enum.take(result.trend, 5))
    assert_elements_in_delta(remainder, Enum.take(result.remainder, 5))
  end

  test "decomposes a list" do
    result = Stl.decompose(@series, period: 7)

    seasonal = [0.3692665100097656, 0.7565547227859497, -1.3324145078659058, 1.9553654193878174, -0.6044800877571106]
    trend = [4.804096698760986, 4.909707069396973, 5.015316963195801, 5.160449981689453, 5.305583477020264]
    remainder = [-0.17336320877075195, 3.333738327026367, -1.6829023361206055, 1.8841848373413086, -4.701103210449219]

    assert_elements_in_delta(seasonal, Enum.take(result.seasonal, 5))
    assert_elements_in_delta(trend, Enum.take(result.trend, 5))
    assert_elements_in_delta(remainder, Enum.take(result.remainder, 5))
  end

  test "works with robustness" do
    result = Stl.decompose(@series, period: 7, robust: true)

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
      |> Stl.decompose(period: 24)

    # The remainder should be approximately 0
    assert_all_elements_close_to_zero(result.remainder)

    # The trend should be approximately 11.5 (average of 0..23)
    assert_all_elements_close_to(result.trend, 11.5)
  end

  test "raises error for period = 1" do
    assert_raise ArgumentError, "period must be greater than 1", fn ->
      Stl.decompose(@series, period: 1)
    end
  end

  test "raises error for too few periods" do
    assert_raise ArgumentError, "series has less than two periods", fn ->
      Stl.decompose(@series, period: 16)
    end
  end

  test "raises error for invalid seasonal_degree" do
    assert_raise ArgumentError, "seasonal_degree must be 0 or 1", fn ->
      Stl.decompose(@series, period: 7, seasonal_degree: 2)
    end
  end

  test "calculates seasonal_strength" do
    result = Stl.decompose(@series, period: 7)

    assert_in_delta(0.28411169658385693, Stl.seasonal_strength(result), 0.001)
  end

  test "calculates seasonal_strength maximal value" do
    result =
      0..29
      |> Enum.map(&rem(&1, 7))
      |> Stl.decompose(period: 7)

    assert_in_delta(1.0, Stl.seasonal_strength(result), 0.001)
  end

  test "calculates trend_strength" do
    result = Stl.decompose(@series, period: 7)

    assert_in_delta(0.16384239106781462, Stl.trend_strength(result), 0.001)
  end

  test "calculates trend_strength maximal value" do
    result =
      0..29
      |> Enum.to_list()
      |> Stl.decompose(period: 7)

    assert_in_delta(1.0, Stl.trend_strength(result), 0.001)
  end

  test "works with small series" do
    result = Stl.decompose([5.0, 9.0, 2.0, 9.0, 0.0, 6.0, 3.0], period: 2)

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

end
