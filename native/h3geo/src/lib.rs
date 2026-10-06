use geo::{
    Coord as GeoCoord, LineString as GeoLineString, MultiPolygon as GeoMultiPolygon,
    Polygon as GeoPolygon,
};
use h3o::{
    self, CellIndex,
    geom::{ContainmentMode, TilerBuilder},
};
use itertools::Itertools;
use rustler::{Atom, NifStruct, NifTuple};
use std::convert::From;

mod atoms {
    rustler::atoms! {
      ok,
      error,
      invalid_cell_index,
      invalid_lat_lng,
      invalid_resolution,
      invalid_geometry,
      compaction_error,
      unknown,
    }
}

#[derive(NifTuple)]
pub struct Coordinate {
    x: f64,
    y: f64,
}

impl From<Coordinate> for GeoCoord {
    fn from(value: Coordinate) -> Self {
        GeoCoord {
            x: value.x,
            y: value.y,
        }
    }
}

#[derive(NifStruct)]
#[module = "Geo.Point"]
pub struct Point {
    coordinates: Coordinate,
}

#[derive(NifStruct)]
#[module = "Geo.Polygon"]
pub struct Polygon {
    coordinates: Vec<Vec<Coordinate>>,
}

impl From<Polygon> for GeoPolygon {
    fn from(value: Polygon) -> Self {
        let line_strings: Vec<GeoLineString> = value
            .coordinates
            .into_iter()
            .map(|coords| coordinates_to_line_string(coords))
            .collect();

        return line_strings_to_polygon(line_strings);
    }
}

#[derive(NifStruct)]
#[module = "Geo.MultiPolygon"]
pub struct MultiPolygon {
    coordinates: Vec<Vec<Vec<Coordinate>>>,
}

impl From<MultiPolygon> for GeoMultiPolygon {
    fn from(value: MultiPolygon) -> Self {
        let polygons = value
            .coordinates
            .into_iter()
            .map(|vec| {
                let line_strings = vec
                    .into_iter()
                    .map(|coords| coordinates_to_line_string(coords))
                    .collect();

                return line_strings_to_polygon(line_strings);
            })
            .collect();

        return GeoMultiPolygon::new(polygons);
    }
}

#[rustler::nif]
fn point_to_cell(point: Point, resolution: u8) -> Result<u64, Atom> {
    let latitude = point.coordinates.y;
    let longitude = point.coordinates.x;

    let coord = match h3o::LatLng::new(latitude, longitude) {
        Ok(coord) => coord,
        Err(_e) => return Err(atoms::invalid_lat_lng()),
    };

    let resolution = match h3o::Resolution::try_from(resolution) {
        Ok(resolution) => resolution,
        Err(_e) => return Err(atoms::invalid_resolution()),
    };

    let cell = coord.to_cell(resolution);
    return Ok(u64::from(cell));
}

#[rustler::nif(schedule = "DirtyCpu")]
fn polygon_to_cells(polygon: Polygon, resolution: u8) -> Result<Vec<u64>, Atom> {
    let resolution = match h3o::Resolution::try_from(resolution) {
        Ok(resolution) => resolution,
        Err(_e) => return Err(atoms::invalid_resolution()),
    };

    // Use h3o to get the cells that cover the polygon
    let geo_polygon = GeoPolygon::from(polygon);
    let mut tiler = TilerBuilder::new(resolution)
        .containment_mode(ContainmentMode::Covers)
        .build();
    if let Err(_e) = tiler.add(geo_polygon) {
        return Err(atoms::invalid_geometry());
    }
    let cells = tiler.into_coverage();

    // Convert the cells into Vec<u64>
    return Ok(cells.map(|cell| u64::from(cell)).unique().collect());
}

#[rustler::nif(schedule = "DirtyCpu")]
fn multipolygon_to_cells(multipolygon: MultiPolygon, resolution: u8) -> Result<Vec<u64>, Atom> {
    let resolution = match h3o::Resolution::try_from(resolution) {
        Ok(resolution) => resolution,
        Err(_e) => return Err(atoms::invalid_resolution()),
    };

    let geo_mp = GeoMultiPolygon::from(multipolygon);
    let mut tiler = TilerBuilder::new(resolution)
        .containment_mode(ContainmentMode::Covers)
        .build();
    if let Err(_e) = tiler.add_batch(geo_mp) {
        return Err(atoms::invalid_geometry());
    }
    let cells = tiler.into_coverage();

    // Convert the cells into Vec<u64>
    return Ok(cells.map(|cell| u64::from(cell)).unique().collect());
}

#[rustler::nif]
fn compact(cells: Vec<u64>) -> Result<Vec<u64>, Atom> {
    let mut indexes = match cells
        .into_iter()
        .unique()
        .map(|cell| CellIndex::try_from(cell))
        .collect::<Result<Vec<_>, _>>()
    {
        Ok(indexes) => indexes,
        Err(_e) => return Err(atoms::invalid_cell_index()),
    };

    if let Err(_e) = CellIndex::compact(&mut indexes) {
        return Err(atoms::compaction_error());
    }

    return Ok(indexes.into_iter().map(|cell| u64::from(cell)).collect());
}

#[rustler::nif]
fn uncompact(cells: Vec<u64>, resolution: u8) -> Result<Vec<u64>, Atom> {
    let indexes = match cells
        .into_iter()
        .map(|cell| CellIndex::try_from(cell))
        .collect::<Result<Vec<_>, _>>()
    {
        Ok(indexes) => indexes,
        Err(_e) => return Err(atoms::invalid_cell_index()),
    };

    let resolution = match h3o::Resolution::try_from(resolution) {
        Ok(resolution) => resolution,
        Err(_e) => return Err(atoms::invalid_resolution()),
    };

    let uncompacted_iter = CellIndex::uncompact(indexes, resolution);

    return Ok(uncompacted_iter.map(|cell| u64::from(cell)).collect());
}

fn coordinates_to_line_string(coords: Vec<Coordinate>) -> GeoLineString {
    let geocoords = coords
        .into_iter()
        .map(|coord| GeoCoord::from(coord))
        .collect::<Vec<_>>();
    return GeoLineString::new(geocoords);
}

fn line_strings_to_polygon(line_strings: Vec<GeoLineString>) -> GeoPolygon {
    let mut line_strings_iter = line_strings.into_iter();

    let outer = line_strings_iter
        .nth(0)
        .expect("expected outer line string");
    let inners = line_strings_iter.collect();

    return GeoPolygon::new(outer, inners);
}

rustler::init!("Elixir.H3Geo");
