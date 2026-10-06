defmodule H3Geo do
  @moduledoc """
  H3Geo implements the H3 geospatial indexing system.

  It's a wrapper around the h3o Rust library, using `Rustler` to expose
  functions from the library in a manner that can be easily called from Elixir.

  Cells are represented as integers. Geometries are `Geo` structs with
  `{longitude, latitude}` coordinates; structs returned by this library have an
  SRID of 4326, as H3 always uses WGS84.

  Functions that take cells return `{:error, :invalid_cell_index}` if passed an
  integer that isn't a valid cell, which can be checked with `valid_cell?/1`.
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

  @doc """
  Returns the center of the cell as a `Geo.Point`, with an SRID of 4326.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.LatLng.html#impl-From%3CCellIndex%3E-for-LatLng)
  """
  @spec cell_to_point(index()) :: {:ok, Geo.Point.t()} | {:error, :invalid_cell_index}
  def cell_to_point(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the boundary of the cell as a `Geo.Polygon` with a single closed
  ring, with an SRID of 4326.

  Cells crossing the antimeridian are not split, so their longitudes jump
  between -180 and 180.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.boundary)
  """
  @spec cell_to_polygon(index()) :: {:ok, Geo.Polygon.t()} | {:error, :invalid_cell_index}
  def cell_to_polygon(_index), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Merges a list of cells into a `Geo.MultiPolygon` outlining them, with an
  SRID of 4326. This is the inverse of `polygon_to_cells/2` and
  `multipolygon_to_cells/2`.

  All cells must have the same resolution, so compacted cells must be
  uncompacted first. Duplicate cells are ignored.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/geom/struct.Solvent.html#method.dissolve)
  """
  @spec cells_to_multipolygon(list(index())) ::
          {:ok, Geo.MultiPolygon.t()} | {:error, :invalid_cell_index | :resolution_mismatch}
  def cells_to_multipolygon(_indexes), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the cells within `k` grid steps of the cell, including the cell
  itself, in no particular order.

  A disk contains `3k(k + 1) + 1` cells (fewer if it includes a pentagon), so
  large values of `k` can return an enormous list.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.grid_disk)
  """
  @spec grid_disk(index(), non_neg_integer()) ::
          {:ok, list(index())} | {:error, :invalid_cell_index}
  def grid_disk(_index, _k), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the cells exactly `k` grid steps from the cell, in no particular
  order.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.grid_ring)
  """
  @spec grid_ring(index(), non_neg_integer()) ::
          {:ok, list(index())} | {:error, :invalid_cell_index}
  def grid_ring(_index, _k), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the number of grid steps between two cells of the same resolution.

  This can fail for cells that are far apart (`:cells_too_far_apart`), or
  on opposite sides of a pentagon (`:pentagon_distortion`).

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.grid_distance)
  """
  @spec grid_distance(index(), index()) ::
          {:ok, non_neg_integer()}
          | {:error,
             :invalid_cell_index
             | :resolution_mismatch
             | :pentagon_distortion
             | :cells_too_far_apart}
  def grid_distance(_origin, _destination), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the line of cells between two cells of the same resolution,
  including both of them.

  Fails in the same circumstances as `grid_distance/2`.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.grid_path_cells)
  """
  @spec grid_path_cells(index(), index()) ::
          {:ok, list(index())}
          | {:error,
             :invalid_cell_index
             | :resolution_mismatch
             | :pentagon_distortion
             | :cells_too_far_apart}
  def grid_path_cells(_origin, _destination), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns whether two cells of the same resolution share an edge. A cell is
  not a neighbor of itself.

  [Rust documentation](https://docs.rs/h3o/latest/h3o/struct.CellIndex.html#method.is_neighbor_with)
  """
  @spec neighbors?(index(), index()) ::
          {:ok, boolean()} | {:error, :invalid_cell_index | :resolution_mismatch}
  def neighbors?(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
