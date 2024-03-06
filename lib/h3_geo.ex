defmodule H3Geo do
  use Rustler,
    otp_app: :h3geo,
    crate: :h3geo

  @doc """
  Takes a `Geo.Point` and an `Integer` precision and returns an integer
  representing the H3 Cell.
  """
  def point_to_cell(_point, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes `Geo.Polygon` and an integer precision and returns a list of integers
  representing the H3 cells that intersect with the polygon.

  Use containment mode, so the cells returned fully cover the polygon.
  """
  def polygon_to_cells(_polygon, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes `Geo.MultiPolygon` and an integer precision and returns a list of
  integers representing the H3 cells that intersect with the multipolygon.

  Use containment mode, so the cells returned fully cover the multipolygon.
  """
  def multipolygon_to_cells(_multipolygon, _precision), do: :erlang.nif_error(:nif_not_loaded)

  def compact(_indexes), do: :erlang.nif_error(:nif_not_loaded)
  def uncompact(_indexes, _resolution), do: :erlang.nif_error(:nif_not_loaded)
end
