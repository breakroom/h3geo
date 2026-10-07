# CHANGELOG

## 0.3.0

- Add `cell_to_point/1`, `cell_to_polygon/1` and `cells_to_multipolygon/1` to convert cells back into `Geo` structs
- Add `grid_disk/2`, `grid_ring/2`, `grid_distance/2`, `grid_path_cells/2` and `neighbors?/2`
- Add `parent/2`, `children/2` and `center_child/2`
- Add `valid_cell?/1`, `resolution/1`, `pentagon?/1`, `base_cell/1`, `cell_to_string/1` and `string_to_cell/1`

## 0.2.0

- Upgrade to h3o 0.11, Rustler 0.38 and Rust 1.99
- Support Geo 4.x as well as 3.6
- `multipolygon_to_cells/2` may return cells in a different order than before

## 0.1.0

- Initial release
