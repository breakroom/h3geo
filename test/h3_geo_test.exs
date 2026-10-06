defmodule H3GeoTest do
  use ExUnit.Case

  # Resolution 6 hexagon, from the point_to_cell/2 test
  @cell 0x86195985FFFFFFF
  # Resolution 0 pentagon (base cell 4)
  @pentagon 0x8009FFFFFFFFFFF
  # Not a valid cell (the reserved bits are set)
  @invalid_cell 0x86195985FFFFFFF + 1

  describe "point_to_cell/2" do
    test "it returns the correct cell" do
      point = %Geo.Point{coordinates: {-1.0, 51.0}, srid: 4326}

      assert {:ok, 0x86195985FFFFFFF} == H3Geo.point_to_cell(point, 6)
    end
  end

  describe "polygon_to_cells/2" do
    test "it returns the correct cells" do
      polygon =
        File.read!(Path.join(__DIR__, "support/polygon.geojson"))
        |> Jason.decode!()
        |> Geo.JSON.decode!()

      assert {:ok,
              [
                0x86195DADFFFFFFF,
                0x86195D377FFFFFF,
                0x86195D367FFFFFF,
                0x86195DACFFFFFFF,
                0x86195D347FFFFFF,
                0x86195D36FFFFFFF,
                0x86194AD97FFFFFF,
                0x86194AD9FFFFFFF
              ]} ==
               H3Geo.polygon_to_cells(polygon, 6)
    end

    test "it returns any covering cells for a small polygon" do
      polygon =
        File.read!(Path.join(__DIR__, "support/small_polygon.geojson"))
        |> Jason.decode!()
        |> Geo.JSON.decode!()

      assert {:ok,
              [
                0x86194E59FFFFFFF,
                0x86194E597FFFFFF,
                0x86195D96FFFFFFF
              ]} ==
               H3Geo.polygon_to_cells(polygon, 6)
    end

    test "it errors with an empty line string" do
      polygon = %Geo.Polygon{coordinates: [[]]}

      assert {:error, :invalid_geometry} == H3Geo.polygon_to_cells(polygon, 6)
    end
  end

  describe "multipolygon_to_cells/2" do
    test "it returns the correct cells" do
      multipolygon =
        File.read!(Path.join(__DIR__, "support/multipolygon.geojson"))
        |> Jason.decode!()
        |> Geo.JSON.decode!()

      expected_cells = [
        0x8409A4DFFFFFFFF,
        0x8409A41FFFFFFFF,
        0x8409A45FFFFFFFF,
        0x84192CBFFFFFFFF,
        0x8409A47FFFFFFFF,
        0x8409A43FFFFFFFF,
        0x8409A09FFFFFFFF,
        0x8409A6BFFFFFFFF,
        0x8409A69FFFFFFFF,
        0x8409A55FFFFFFFF
      ]

      assert {:ok, returned_cells} = H3Geo.multipolygon_to_cells(multipolygon, 4)
      assert Enum.sort(expected_cells) == Enum.sort(returned_cells)
    end

    test "it errors with an empty line string" do
      polygon = %Geo.MultiPolygon{coordinates: [[[]]]}

      assert {:error, :invalid_geometry} == H3Geo.multipolygon_to_cells(polygon, 6)
    end
  end

  describe "compact/1 and uncompact/2" do
    test "works forward and back" do
      cells =
        [
          0x86195DADFFFFFFF,
          0x86195D377FFFFFF,
          0x86195D367FFFFFF,
          0x86195DACFFFFFFF,
          0x86195D347FFFFFF,
          0x86195D36FFFFFFF,
          0x86194AD97FFFFFF,
          0x86194AD9FFFFFFF
        ]
        |> Enum.sort()

      assert {:ok, compacted} = H3Geo.compact(cells)
      assert {:ok, ^cells} = H3Geo.uncompact(compacted, 6)
    end
  end

  describe "valid_cell?/1" do
    test "it returns true for a valid cell" do
      assert H3Geo.valid_cell?(@cell)
      assert H3Geo.valid_cell?(@pentagon)
    end

    test "it returns false for an invalid cell" do
      refute H3Geo.valid_cell?(@invalid_cell)
      refute H3Geo.valid_cell?(0)
      refute H3Geo.valid_cell?(-1)
      refute H3Geo.valid_cell?(2 ** 64)
    end
  end

  describe "resolution/1" do
    test "it returns the resolution" do
      assert {:ok, 6} == H3Geo.resolution(@cell)
      assert {:ok, 0} == H3Geo.resolution(@pentagon)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.resolution(@invalid_cell)
    end
  end

  describe "pentagon?/1" do
    test "it returns whether the cell is a pentagon" do
      assert {:ok, true} == H3Geo.pentagon?(@pentagon)
      assert {:ok, false} == H3Geo.pentagon?(@cell)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.pentagon?(@invalid_cell)
    end
  end

  describe "base_cell/1" do
    test "it returns the base cell number" do
      assert {:ok, 4} == H3Geo.base_cell(@pentagon)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.base_cell(@invalid_cell)
    end
  end

  describe "cell_to_string/1 and string_to_cell/1" do
    test "it returns the lowercase hex string" do
      assert {:ok, "86195985fffffff"} == H3Geo.cell_to_string(@cell)
    end

    test "it parses a hex string" do
      assert {:ok, @cell} == H3Geo.string_to_cell("86195985fffffff")
      assert {:ok, @cell} == H3Geo.string_to_cell("86195985FFFFFFF")
    end

    test "it round trips" do
      assert {:ok, string} = H3Geo.cell_to_string(@pentagon)
      assert {:ok, @pentagon} == H3Geo.string_to_cell(string)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.cell_to_string(@invalid_cell)
      assert {:error, :invalid_cell_index} == H3Geo.string_to_cell("zz")
      assert {:error, :invalid_cell_index} == H3Geo.string_to_cell("")

      assert {:error, :invalid_cell_index} ==
               H3Geo.string_to_cell(Integer.to_string(@invalid_cell, 16))
    end
  end

  describe "parent/2" do
    test "it returns the parent at a coarser resolution" do
      assert {:ok, parent} = H3Geo.parent(@cell, 5)
      assert {:ok, 5} == H3Geo.resolution(parent)
      assert {:ok, children} = H3Geo.children(parent, 6)
      assert @cell in children
    end

    test "it returns the cell itself at the same resolution" do
      assert {:ok, @cell} == H3Geo.parent(@cell, 6)
    end

    test "it errors with a finer resolution" do
      assert {:error, :invalid_resolution} == H3Geo.parent(@cell, 7)
      assert {:error, :invalid_resolution} == H3Geo.parent(@cell, 16)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.parent(@invalid_cell, 5)
    end
  end

  describe "children/2" do
    test "it returns the children of a hexagon" do
      assert {:ok, children} = H3Geo.children(@cell, 7)
      assert length(children) == 7
      assert Enum.all?(children, &(H3Geo.parent(&1, 6) == {:ok, @cell}))
    end

    test "it returns the children of a pentagon" do
      assert {:ok, children} = H3Geo.children(@pentagon, 1)
      assert length(children) == 6
      assert Enum.all?(children, &(H3Geo.parent(&1, 0) == {:ok, @pentagon}))
    end

    test "it returns the children several resolutions down" do
      assert {:ok, children} = H3Geo.children(@cell, 8)
      assert length(children) == 49
    end

    test "it returns the cell itself at the same resolution" do
      assert {:ok, [@cell]} == H3Geo.children(@cell, 6)
    end

    test "it errors with a coarser resolution" do
      assert {:error, :invalid_resolution} == H3Geo.children(@cell, 5)
      assert {:error, :invalid_resolution} == H3Geo.children(@cell, 16)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.children(@invalid_cell, 7)
    end
  end

  describe "center_child/2" do
    test "it returns the center child" do
      assert {:ok, center} = H3Geo.center_child(@cell, 8)
      assert {:ok, 8} == H3Geo.resolution(center)
      assert {:ok, @cell} == H3Geo.parent(center, 6)
      assert {:ok, children} = H3Geo.children(@cell, 8)
      assert center in children
    end

    test "it returns the cell itself at the same resolution" do
      assert {:ok, @cell} == H3Geo.center_child(@cell, 6)
    end

    test "it errors with a coarser resolution" do
      assert {:error, :invalid_resolution} == H3Geo.center_child(@cell, 5)
      assert {:error, :invalid_resolution} == H3Geo.center_child(@cell, 16)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.center_child(@invalid_cell, 7)
    end
  end

  describe "cell_to_point/1" do
    test "it returns the center of the cell" do
      assert {:ok, point} = H3Geo.cell_to_point(@cell)
      assert_valid_geo(point, Geo.Point)
      assert {lng, lat} = point.coordinates
      assert_in_delta lng, -1.0, 0.05
      assert_in_delta lat, 51.0, 0.05
      assert {:ok, @cell} == H3Geo.point_to_cell(point, 6)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.cell_to_point(@invalid_cell)
    end
  end

  describe "cell_to_polygon/1" do
    test "it returns the boundary of a hexagon" do
      assert {:ok, polygon} = H3Geo.cell_to_polygon(@cell)
      assert_valid_geo(polygon, Geo.Polygon)
      assert [ring] = polygon.coordinates
      assert length(ring) == 7
      assert List.first(ring) == List.last(ring)
      assert {:ok, cells} = H3Geo.polygon_to_cells(polygon, 6)
      assert @cell in cells
    end

    test "it returns the boundary of a pentagon" do
      assert {:ok, polygon} = H3Geo.cell_to_polygon(@pentagon)
      assert [ring] = polygon.coordinates
      assert length(ring) == 6
      assert List.first(ring) == List.last(ring)
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} == H3Geo.cell_to_polygon(@invalid_cell)
    end
  end

  describe "cells_to_multipolygon/1" do
    test "it returns a single outline for contiguous cells" do
      assert {:ok, center} = H3Geo.center_child(@cell, 7)
      assert {:ok, children} = H3Geo.children(@cell, 7)
      assert {:ok, multipolygon} = H3Geo.cells_to_multipolygon(children)
      assert_valid_geo(multipolygon, Geo.MultiPolygon)
      assert [[ring]] = multipolygon.coordinates
      assert List.first(ring) == List.last(ring)

      # The center child is fully inside the outline, so is covered by it
      assert {:ok, cells} = H3Geo.multipolygon_to_cells(multipolygon, 7)
      assert center in cells
    end

    test "it returns separate polygons for separate cells" do
      assert {:ok, london} = H3Geo.point_to_cell(%Geo.Point{coordinates: {-0.1, 51.5}}, 6)
      assert {:ok, paris} = H3Geo.point_to_cell(%Geo.Point{coordinates: {2.35, 48.85}}, 6)
      assert {:ok, multipolygon} = H3Geo.cells_to_multipolygon([london, paris])
      assert [[_], [_]] = multipolygon.coordinates
    end

    test "it returns the same outline as cell_to_polygon/1 for a single cell" do
      assert {:ok, polygon} = H3Geo.cell_to_polygon(@cell)
      assert {:ok, multipolygon} = H3Geo.cells_to_multipolygon([@cell])
      assert [[ring]] = multipolygon.coordinates
      assert [expected_ring] = polygon.coordinates
      assert length(ring) == length(expected_ring)

      # The rings may start at different vertices, so compare them without
      # their closing coordinate
      assert ring_vertices(ring) == ring_vertices(expected_ring)
    end

    test "it round trips with polygon_to_cells/2" do
      polygon =
        File.read!(Path.join(__DIR__, "support/polygon.geojson"))
        |> Jason.decode!()
        |> Geo.JSON.decode!()

      assert {:ok, cells} = H3Geo.polygon_to_cells(polygon, 6)
      assert {:ok, multipolygon} = H3Geo.cells_to_multipolygon(cells)
      assert {:ok, returned_cells} = H3Geo.multipolygon_to_cells(multipolygon, 6)
      assert MapSet.subset?(MapSet.new(cells), MapSet.new(returned_cells))
    end

    test "it returns an empty multipolygon for no cells" do
      assert {:ok, %Geo.MultiPolygon{coordinates: []}} = H3Geo.cells_to_multipolygon([])
    end

    test "it ignores duplicate cells" do
      assert {:ok, multipolygon} = H3Geo.cells_to_multipolygon([@cell, @cell])
      assert [[_]] = multipolygon.coordinates
    end

    test "it errors with cells of different resolutions" do
      assert {:ok, parent} = H3Geo.parent(@cell, 5)

      assert {:error, :resolution_mismatch} ==
               H3Geo.cells_to_multipolygon([@cell, parent])
    end

    test "it errors with an invalid cell" do
      assert {:error, :invalid_cell_index} ==
               H3Geo.cells_to_multipolygon([@cell, @invalid_cell])
    end
  end

  # Asserts the value is a complete struct of the given module (with every
  # key present) that can be encoded as GeoJSON
  defp assert_valid_geo(value, module) do
    assert %{__struct__: ^module, srid: 4326, properties: %{}} = value
    assert Enum.sort(Map.keys(value)) == Enum.sort(Map.keys(struct(module)))
    assert %{"type" => _} = Geo.JSON.encode!(value)
  end

  defp ring_vertices(ring) do
    ring
    |> Enum.drop(-1)
    |> Enum.map(fn {x, y} -> {Float.round(x, 9), Float.round(y, 9)} end)
    |> Enum.sort()
  end
end
