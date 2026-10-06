defmodule H3Geo do
  @moduledoc """
  H3Geo implements the H3 geospatial indexing system.

  It's a wrapper around the h3o Rust library, using `Rustler` to expose
  functions from the library in a manner that can be easily called from Elixir.

  Currently only a handful of functions are implemented, mostly to do with
  converting existing geometries into H3 cell indexes.
  """
  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :h3geo,
    crate: :h3geo,
    base_url: "https://github.com/breakroom/h3geo/releases/download/v#{version}",
    force_build: System.get_env("FORCE_H3GEO_BUILD") in ["1", "true"],
    targets:
      Enum.uniq(["aarch64-unknown-linux-musl" | RustlerPrecompiled.Config.default_targets()]),
    version: version,
    nif_versions: ["2.15"]

  @type index :: pos_integer()
  @type precision :: 0..15

  @doc """
  Takes a `Geo.Point` and an integer precision and returns an integer
  representing the H3 Cell.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.LatLng.html#method.to_cell).
  """
  @spec point_to_cell(Geo.Point.t(), precision()) ::
          {:ok, pos_integer()} | {:error, :invalid_lat_lng | :invalid_resolution}
  def point_to_cell(_point, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes `Geo.Polygon` and an integer precision and returns a list of integers
  representing the H3 cells that intersect with the polygon.

  Uses the
  [Covers](https://docs.rs/h3o/latest/h3o/geom/enum.ContainmentMode.html#variant.Covers)
  containment mode, so the cells returned fully cover the polygon.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/geom/trait.ToCells.html)
  """
  @spec polygon_to_cells(Geo.Polygon.t(), precision()) ::
          {:ok, list(index())} | {:error, :invalid_resolution | :invalid_geometry}
  def polygon_to_cells(_polygon, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes `Geo.MultiPolygon` and an integer precision and returns a list of
  integers representing the H3 cells that intersect with the multipolygon.

  Uses the
  [Covers](https://docs.rs/h3o/latest/h3o/geom/enum.ContainmentMode.html#variant.Covers)
  containment mode, so the cells returned fully cover the multipolygon.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/geom/trait.ToCells.html)
  """
  @spec multipolygon_to_cells(Geo.MultiPolygon.t(), precision()) ::
          {:ok, list(index())} | {:error, :invalid_resolution | :invalid_geometry}
  def multipolygon_to_cells(_multipolygon, _precision), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes a list of indexes and returns the compact indexes.

  The incoming list is filtered for unique values automatically.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.compact)
  """
  @spec compact(list(index())) ::
          {:ok, list(index())} | {:error, :invalid_cell_index | :compaction_error}
  def compact(_indexes), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Takes a list of indexes and returns the uncompacted indexes at the desired precision.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.uncompact)
  """
  @spec uncompact(list(index()), precision()) ::
          {:ok, list(index())} | {:error, :invalid_cell_index | :invalid_resolution}
  def uncompact(_indexes, _resolution), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns whether the integer is a valid H3 cell index.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#impl-TryFrom%3Cu64%3E-for-CellIndex)
  """
  @spec valid_cell?(integer()) :: boolean()
  def valid_cell?(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the resolution of the cell.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.resolution)
  """
  @spec resolution(index()) :: {:ok, precision()} | {:error, :invalid_cell_index}
  def resolution(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns whether the cell is one of the twelve pentagons at its resolution.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.is_pentagon)
  """
  @spec pentagon?(index()) :: {:ok, boolean()} | {:error, :invalid_cell_index}
  def pentagon?(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the number of the base (resolution 0) cell the cell belongs to,
  between 0 and 121.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.base_cell)
  """
  @spec base_cell(index()) :: {:ok, 0..121} | {:error, :invalid_cell_index}
  def base_cell(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the cell as a lowercase hexadecimal string, the standard textual
  representation of H3 cells.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#impl-Display-for-CellIndex)
  """
  @spec cell_to_string(index()) :: {:ok, String.t()} | {:error, :invalid_cell_index}
  def cell_to_string(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Parses a hexadecimal string (in either case) into a cell.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#impl-FromStr-for-CellIndex)
  """
  @spec string_to_cell(String.t()) :: {:ok, index()} | {:error, :invalid_cell_index}
  def string_to_cell(_string), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the parent of the cell at the given coarser (or equal) resolution.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.parent)
  """
  @spec parent(index(), precision()) ::
          {:ok, index()} | {:error, :invalid_cell_index | :invalid_resolution}
  def parent(_index, _resolution), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the children of the cell at the given finer (or equal) resolution.

  The number of children grows by a factor of 7 for each resolution, so asking
  for children many resolutions below the cell can return an enormous list.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.children)
  """
  @spec children(index(), precision()) ::
          {:ok, list(index())} | {:error, :invalid_cell_index | :invalid_resolution}
  def children(_index, _resolution), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the center child of the cell at the given finer (or equal)
  resolution.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.center_child)
  """
  @spec center_child(index(), precision()) ::
          {:ok, index()} | {:error, :invalid_cell_index | :invalid_resolution}
  def center_child(_index, _resolution), do: :erlang.nif_error(:nif_not_loaded)
end
