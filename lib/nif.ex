defmodule Stl.NIF do
  @moduledoc false
  @on_load :__on_load__

  def __on_load__ do
    path = :filename.join(:code.priv_dir(:stl), ~c"libstl_nif")

    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, reason} -> raise "failed to load NIF library, reason: #{inspect(reason)}"
    end
  end

  # NIF functions
  def stl_params, do: :erlang.nif_error(:nif_not_loaded)
  def set_seasonal_length(_params, _length), do: :erlang.nif_error(:nif_not_loaded)
  def set_trend_length(_params, _length), do: :erlang.nif_error(:nif_not_loaded)
  def set_low_pass_length(_params, _length), do: :erlang.nif_error(:nif_not_loaded)
  def set_seasonal_degree(_params, _degree), do: :erlang.nif_error(:nif_not_loaded)
  def set_trend_degree(_params, _degree), do: :erlang.nif_error(:nif_not_loaded)
  def set_low_pass_degree(_params, _degree), do: :erlang.nif_error(:nif_not_loaded)
  def set_seasonal_jump(_params, _jump), do: :erlang.nif_error(:nif_not_loaded)
  def set_trend_jump(_params, _jump), do: :erlang.nif_error(:nif_not_loaded)
  def set_low_pass_jump(_params, _jump), do: :erlang.nif_error(:nif_not_loaded)
  def set_inner_loops(_params, _loops), do: :erlang.nif_error(:nif_not_loaded)
  def set_outer_loops(_params, _loops), do: :erlang.nif_error(:nif_not_loaded)
  def set_robust(_params, _robust), do: :erlang.nif_error(:nif_not_loaded)
  def fit(_params, _series, _period, _include_weights), do: :erlang.nif_error(:nif_not_loaded)
  def decompose(_series, _period, _params, _include_weights), do: :erlang.nif_error(:nif_not_loaded)
  def seasonal_strength(_seasonal, _remainder), do: :erlang.nif_error(:nif_not_loaded)
  def trend_strength(_trend, _remainder), do: :erlang.nif_error(:nif_not_loaded)
end
