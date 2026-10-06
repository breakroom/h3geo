# H3Geo

[![Hex pm](http://img.shields.io/hexpm/v/h3geo.svg?style=flat)](https://hex.pm/packages/h3geo)
[![HexDocs](https://img.shields.io/badge/HexDocs-Yes-blue)](https://hexdocs.pm/h3geo)

Implements H3, the hexagonal hierarchical geospatial indexing system, in Elixir. Behind the scenes it uses h3o, a Rust implementation of H3.

This library exposes a subset of h3o: converting `Geo` geometries to cells and back, inspecting and validating cells, moving between resolutions, and finding neighbouring cells.

## Installation

```elixir
def deps do
  [
    {:h3geo, "~> 0.2.0"}
  ]
end
```

The NIF is provided as a precompiled bundle, so you won't need to install Rust to use it.

## Example

```elixir
point = %Geo.Point{coordinates: {-0.14234062595533195, 51.50107677017966}}
{:ok, cell} = H3Geo.point_to_cell(point, 6)
H3Geo.cell_to_string(cell)
# {:ok, "86194ad17ffffff"}

# The cell and its six neighbours
{:ok, nearby} = H3Geo.grid_disk(cell, 1)

# Their combined outline, as a %Geo.MultiPolygon{}
{:ok, outline} = H3Geo.cells_to_multipolygon(nearby)

# The containing cell at a coarser resolution
{:ok, parent} = H3Geo.parent(cell, 4)
H3Geo.cell_to_string(parent)
# {:ok, "84194adffffffff"}
```

See the [documentation](https://hexdocs.pm/h3geo) for the full list of functions.
