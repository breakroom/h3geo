# H3Geo

[![Hex pm](http://img.shields.io/hexpm/v/h3geo.svg?style=flat)](https://hex.pm/packages/h3geo)
[![HexDocs](https://img.shields.io/badge/HexDocs-Yes-blue)](https://hexdocs.pm/h3geo)

Implements H3, the hexagonal hierarchical geospatial indexing system, in Elixir. Behind the scenes it uses h3o, a Rust implementation of H3.

This library is in early stages of development and currently only exposes a handful of functions from h3o for converting different geometries to cells.

## Installation

```elixir
def deps do
  [
    {:h3geo, "~> 0.1.0"}
  ]
end
```

The NIF is provided as a precompiled bundle, so you won't need to install Rust to use it.

## Example

```elixir
point = %Geo.Point{coordinates: {-0.14234062595533195, 51.50107677017966}}
precision = 6
{:ok, cell} = H3Geo.point_to_cell(point, precision)
Integer.to_string(cell, 16)
# "86194AD17FFFFFF"
```
