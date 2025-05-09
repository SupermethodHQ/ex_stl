defmodule Stl.NIF do
  @moduledoc false
  @on_load :__on_load__

  def __on_load__ do
    path = :filename.join(:code.priv_dir(:ex_stl), ~c"libstl_nif")

    case :erlang.load_nif(path, 0) do
      :ok -> :ok
      {:error, reason} -> raise "failed to load NIF library, reason: #{inspect(reason)}"
    end
  end

  def decompose(_series, _period, _params, _include_weights), do: :erlang.nif_error(:nif_not_loaded)
  def decompose_multi(_series, _periods, _params), do: :erlang.nif_error(:nif_not_loaded)
  def seasonal_strength(_seasonal, _remainder), do: :erlang.nif_error(:nif_not_loaded)
  def trend_strength(_trend, _remainder), do: :erlang.nif_error(:nif_not_loaded)
end
