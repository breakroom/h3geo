defmodule Mix.Tasks.Benchmark do
  use Mix.Task

  def run(_) do
    point = %Geo.Point{coordinates: {-1.0, 51.0}, srid: 4326}
    small_polygon = read_geojson("small_polygon.geojson")
    complex_multipolygon = read_geojson("multipolygon.geojson")

    {:ok, complex_cells} = H3Geo.multipolygon_to_cells(complex_multipolygon, 6)
    {:ok, compacted_complex_cells} = H3Geo.compact(complex_cells)

    Benchee.run(%{
      "point_to_cell" => fn ->
        {:ok, _cell} = H3Geo.point_to_cell(point, 6)
      end,
      "small_polygon" => fn ->
        {:ok, _cells} = H3Geo.polygon_to_cells(small_polygon, 6)
      end,
      "complex_multipolygon" => fn ->
        {:ok, _cells} = H3Geo.multipolygon_to_cells(complex_multipolygon, 6)
      end,
      "compact" => fn ->
        {:ok, _} = H3Geo.compact(complex_cells)
      end,
      "uncompact" => fn ->
        {:ok, _} = H3Geo.uncompact(compacted_complex_cells, 6)
      end
    })
  end

  defp read_geojson(filename) do
    __DIR__
    |> Path.join("../../../test/support")
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
    |> Geo.JSON.decode!()
  end
end
