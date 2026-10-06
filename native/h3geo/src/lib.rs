use geo::{
    Coord as GeoCoord, LineString as GeoLineString, MultiPolygon as GeoMultiPolygon,
    Polygon as GeoPolygon,
};
use h3o::{
    self, CellIndex,
    error::LocalIjError,
    geom::{ContainmentMode, SolventBuilder, TilerBuilder},
};
use itertools::Itertools;
use rustler::{Atom, NifStruct, NifTuple, Term};
use std::collections::HashMap;
use std::convert::From;
use std::str::FromStr;

mod atoms {
    rustler::atoms! {
      ok,
      error,
      invalid_cell_index,
      invalid_lat_lng,
      invalid_resolution,
      invalid_geometry,
      compaction_error,
      resolution_mismatch,
      pentagon_distortion,
      cells_too_far_apart,
      unknown,
    }
}

#[derive(NifTuple)]
pub struct Coordinate {
    x: f64,
    y: f64,
}

impl From<GeoCoord> for Coordinate {
    fn from(value: GeoCoord) -> Self {
        Coordinate {
            x: value.x,
            y: value.y,
        }
    }
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

// H3 coordinates are always WGS84
const SRID: i32 = 4326;

// The structs below are only used to encode results. Unlike the decoding
// structs above, they declare every field of the Geo struct, so that the
// encoded map is a complete struct.

#[derive(NifStruct)]
#[module = "Geo.Point"]
pub struct PointOut {
    coordinates: Coordinate,
    srid: i32,
    properties: HashMap<String, String>,
}

impl From<GeoCoord> for PointOut {
    fn from(value: GeoCoord) -> Self {
        PointOut {
            coordinates: Coordinate::from(value),
            srid: SRID,
            properties: HashMap::new(),
        }
    }
}

#[derive(NifStruct)]
#[module = "Geo.Polygon"]
pub struct PolygonOut {
    coordinates: Vec<Vec<Coordinate>>,
    srid: i32,
    properties: HashMap<String, String>,
}

impl From<GeoPolygon> for PolygonOut {
    fn from(value: GeoPolygon) -> Self {
        PolygonOut {
            coordinates: polygon_to_coordinates(value),
            srid: SRID,
            properties: HashMap::new(),
        }
    }
}

#[derive(NifStruct)]
#[module = "Geo.MultiPolygon"]
pub struct MultiPolygonOut {
    coordinates: Vec<Vec<Vec<Coordinate>>>,
    srid: i32,
    properties: HashMap<String, String>,
}

impl From<GeoMultiPolygon> for MultiPolygonOut {
    fn from(value: GeoMultiPolygon) -> Self {
        MultiPolygonOut {
            coordinates: value.into_iter().map(polygon_to_coordinates).collect(),
            srid: SRID,
            properties: HashMap::new(),
        }
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

    let resolution = parse_resolution(resolution)?;

    let cell = coord.to_cell(resolution);
    return Ok(u64::from(cell));
}

#[rustler::nif(schedule = "DirtyCpu")]
fn polygon_to_cells(polygon: Polygon, resolution: u8) -> Result<Vec<u64>, Atom> {
    let resolution = parse_resolution(resolution)?;

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
    let resolution = parse_resolution(resolution)?;

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
    let mut indexes = parse_cells(cells.into_iter().unique())?;

    if let Err(_e) = CellIndex::compact(&mut indexes) {
        return Err(atoms::compaction_error());
    }

    return Ok(indexes.into_iter().map(|cell| u64::from(cell)).collect());
}

#[rustler::nif]
fn uncompact(cells: Vec<u64>, resolution: u8) -> Result<Vec<u64>, Atom> {
    let indexes = parse_cells(cells)?;

    let resolution = parse_resolution(resolution)?;

    let uncompacted_iter = CellIndex::uncompact(indexes, resolution);

    return Ok(uncompacted_iter.map(|cell| u64::from(cell)).collect());
}

#[rustler::nif(name = "valid_cell?")]
fn valid_cell(index: Term) -> bool {
    // Decode manually, so that integers outside the u64 range return false
    // rather than raising an ArgumentError
    match index.decode::<u64>() {
        Ok(index) => CellIndex::try_from(index).is_ok(),
        Err(_e) => false,
    }
}

#[rustler::nif]
fn resolution(cell: u64) -> Result<u8, Atom> {
    let cell = parse_cell(cell)?;

    return Ok(u8::from(cell.resolution()));
}

#[rustler::nif(name = "pentagon?")]
fn pentagon(cell: u64) -> Result<bool, Atom> {
    let cell = parse_cell(cell)?;

    return Ok(cell.is_pentagon());
}

#[rustler::nif]
fn base_cell(cell: u64) -> Result<u8, Atom> {
    let cell = parse_cell(cell)?;

    return Ok(u8::from(cell.base_cell()));
}

#[rustler::nif]
fn cell_to_string(cell: u64) -> Result<String, Atom> {
    let cell = parse_cell(cell)?;

    return Ok(cell.to_string());
}

#[rustler::nif]
fn string_to_cell(string: &str) -> Result<u64, Atom> {
    match CellIndex::from_str(string) {
        Ok(cell) => Ok(u64::from(cell)),
        Err(_e) => Err(atoms::invalid_cell_index()),
    }
}

#[rustler::nif]
fn parent(cell: u64, resolution: u8) -> Result<u64, Atom> {
    let cell = parse_cell(cell)?;
    let resolution = parse_resolution(resolution)?;

    match cell.parent(resolution) {
        Some(parent) => Ok(u64::from(parent)),
        None => Err(atoms::invalid_resolution()),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn children(cell: u64, resolution: u8) -> Result<Vec<u64>, Atom> {
    let cell = parse_cell(cell)?;
    let resolution = parse_resolution(resolution)?;

    // h3o returns no children for a coarser resolution, rather than an error
    if resolution < cell.resolution() {
        return Err(atoms::invalid_resolution());
    }

    return Ok(cell
        .children(resolution)
        .map(|child| u64::from(child))
        .collect());
}

#[rustler::nif]
fn center_child(cell: u64, resolution: u8) -> Result<u64, Atom> {
    let cell = parse_cell(cell)?;
    let resolution = parse_resolution(resolution)?;

    match cell.center_child(resolution) {
        Some(child) => Ok(u64::from(child)),
        None => Err(atoms::invalid_resolution()),
    }
}

#[rustler::nif]
fn cell_to_point(cell: u64) -> Result<PointOut, Atom> {
    let cell = parse_cell(cell)?;
    let lat_lng = h3o::LatLng::from(cell);

    return Ok(PointOut::from(GeoCoord::from(lat_lng)));
}

#[rustler::nif]
fn cell_to_polygon(cell: u64) -> Result<PolygonOut, Atom> {
    let cell = parse_cell(cell)?;

    // GeoPolygon::new closes the ring, which the boundary on its own isn't
    let exterior = GeoLineString::from(cell.boundary());
    let polygon = GeoPolygon::new(exterior, vec![]);

    return Ok(PolygonOut::from(polygon));
}

#[rustler::nif(schedule = "DirtyCpu")]
fn cells_to_multipolygon(cells: Vec<u64>) -> Result<MultiPolygonOut, Atom> {
    // Deduplicate first, as the solvent errors on duplicate cells
    let cells = parse_cells(cells.into_iter().unique())?;

    // With duplicates removed, the only possible error is mixed resolutions
    let solvent = SolventBuilder::new().build();
    match solvent.dissolve(cells) {
        Ok(multipolygon) => Ok(MultiPolygonOut::from(multipolygon)),
        Err(_e) => Err(atoms::resolution_mismatch()),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn grid_disk(cell: u64, k: u32) -> Result<Vec<u64>, Atom> {
    let cell = parse_cell(cell)?;

    let cells: Vec<CellIndex> = cell.grid_disk(k);
    return Ok(cells.into_iter().map(|cell| u64::from(cell)).collect());
}

#[rustler::nif(schedule = "DirtyCpu")]
fn grid_ring(cell: u64, k: u32) -> Result<Vec<u64>, Atom> {
    let cell = parse_cell(cell)?;

    let cells: Vec<CellIndex> = cell.grid_ring(k);
    return Ok(cells.into_iter().map(|cell| u64::from(cell)).collect());
}

#[rustler::nif]
fn grid_distance(origin: u64, destination: u64) -> Result<i32, Atom> {
    let origin = parse_cell(origin)?;
    let destination = parse_cell(destination)?;

    return origin.grid_distance(destination).map_err(local_ij_error);
}

#[rustler::nif(schedule = "DirtyCpu")]
fn grid_path_cells(origin: u64, destination: u64) -> Result<Vec<u64>, Atom> {
    let origin = parse_cell(origin)?;
    let destination = parse_cell(destination)?;

    return origin
        .grid_path_cells(destination)
        .map_err(local_ij_error)?
        .map(|cell| cell.map(u64::from).map_err(local_ij_error))
        .collect();
}

#[rustler::nif(name = "neighbors?")]
fn neighbors(a: u64, b: u64) -> Result<bool, Atom> {
    let a = parse_cell(a)?;
    let b = parse_cell(b)?;

    return a
        .is_neighbor_with(b)
        .map_err(|_e| atoms::resolution_mismatch());
}

fn local_ij_error(error: LocalIjError) -> Atom {
    match error {
        LocalIjError::ResolutionMismatch => atoms::resolution_mismatch(),
        LocalIjError::Pentagon => atoms::pentagon_distortion(),
        LocalIjError::HexGrid(_e) => atoms::cells_too_far_apart(),
        _ => atoms::unknown(),
    }
}

fn parse_resolution(resolution: u8) -> Result<h3o::Resolution, Atom> {
    h3o::Resolution::try_from(resolution).map_err(|_e| atoms::invalid_resolution())
}

fn parse_cell(cell: u64) -> Result<CellIndex, Atom> {
    CellIndex::try_from(cell).map_err(|_e| atoms::invalid_cell_index())
}

fn parse_cells(cells: impl IntoIterator<Item = u64>) -> Result<Vec<CellIndex>, Atom> {
    cells.into_iter().map(parse_cell).collect()
}

fn coordinates_to_line_string(coords: Vec<Coordinate>) -> GeoLineString {
    let geocoords = coords
        .into_iter()
        .map(|coord| GeoCoord::from(coord))
        .collect::<Vec<_>>();
    return GeoLineString::new(geocoords);
}

fn line_string_to_coordinates(line_string: GeoLineString) -> Vec<Coordinate> {
    line_string.into_iter().map(Coordinate::from).collect()
}

fn polygon_to_coordinates(polygon: GeoPolygon) -> Vec<Vec<Coordinate>> {
    let (exterior, interiors) = polygon.into_inner();

    std::iter::once(exterior)
        .chain(interiors)
        .map(line_string_to_coordinates)
        .collect()
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
