defmodule H3Geo do
  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :h3geo,
    crate: :h3geo,
    base_url: "https://github.com/breakroom/h3geo/releases/download/v#{version}",
    force_build: System.get_env("H3GEO_BUILD") in ["1", "true"],
    targets:
      Enum.uniq(["aarch64-unknown-linux-musl" | RustlerPrecompiled.Config.default_targets()]),
    version: version

  @type index :: pos_integer()
  @type precision :: pos_integer()

  @doc """
  Takes a `Geo.Point` and an `Integer` precision and returns an integer
  representing the H3 Cell.
  """
  @spec point_to_cell(Geo.Point.t(), precision()) ::
          {:ok, pos_integer()} | {:error, :invalid_lat_lng | :invalid_resolution}
  def point_to_cell(_point, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes `Geo.Polygon` and an integer precision and returns a list of integers
  representing the H3 cells that intersect with the polygon.

  Use containment mode, so the cells returned fully cover the polygon.
  """
  @spec polygon_to_cells(Geo.Polygon.t(), precision()) ::
          {:ok, list(index())} | {:error, :invalid_resolution | :invalid_geometry}
  def polygon_to_cells(_polygon, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes `Geo.MultiPolygon` and an integer precision and returns a list of
  integers representing the H3 cells that intersect with the multipolygon.

  Use containment mode, so the cells returned fully cover the multipolygon.
  """
  @spec multipolygon_to_cells(Geo.MultiPolygon.t(), precision()) ::
          {:ok, list(index())} | {:error, :invalid_resolution | :invalid_geometry}
  def multipolygon_to_cells(_multipolygon, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes a list of indexes and returns the compact indexes.

  The incoming list is filtered for unique values automatically.
  """
  @spec compact(list(index())) ::
          {:ok, list(index())} | {:error, :invalid_cell_index | :compaction_error}
  def compact(_indexes), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes a list of indexes and returns the uncompacted indexes at the desired precision.
  """
  @spec uncompact(list(index()), precision()) ::
          {:ok, list(index())} | {:error, :invalid_cell_index | :invalid_resolution}
  def uncompact(_indexes, _resolution), do: :erlang.nif_error(:nif_not_loaded)
end
