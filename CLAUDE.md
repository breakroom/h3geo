# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

H3Geo is an Elixir library (published to Hex as `h3geo`) that exposes a handful of functions from [h3o](https://docs.rs/h3o), a Rust implementation of the H3 hexagonal geospatial index, via a Rustler NIF. Inputs are `Geo` structs (`Geo.Point`, `Geo.Polygon`, `Geo.MultiPolygon`); H3 cells are represented as plain integers (`u64`).

## Commands

```sh
mix deps.get
FORCE_H3GEO_BUILD=1 mix test                          # run tests, compiling the NIF locally
FORCE_H3GEO_BUILD=1 mix test test/h3_geo_test.exs:42  # single test by line
mix format                                            # Elixir formatting
cargo fmt --manifest-path native/h3geo/Cargo.toml     # Rust formatting
FORCE_H3GEO_BUILD=1 mix run benchmark/benchmark.exs   # Benchee benchmarks
```

**Always set `FORCE_H3GEO_BUILD=1` when changing Rust code.** Without it, `RustlerPrecompiled` downloads the prebuilt NIF for the current `@version` from GitHub releases (and verifies it against `checksum-Elixir.H3Geo.exs`), so local Rust changes are silently ignored. Rust toolchain is pinned to 1.99.0 in `.tool-versions`.

## Architecture

There are only two source files, and they must be kept in sync:

- `lib/h3_geo.ex` — the public Elixir API. Each function is a stub (`:erlang.nif_error(:nif_not_loaded)`) carrying the `@doc` and `@spec`; the real implementation is replaced at load time by the NIF. `use RustlerPrecompiled` here configures the download URL, targets and NIF version (`2.15` only).
- `native/h3geo/src/lib.rs` — the NIF implementation. NIFs are registered automatically by `#[rustler::nif]` (`rustler::init!` only names the module), and each must have a matching stub with the same name/arity in `lib/h3_geo.ex`.

Key conventions in `lib.rs`:

- `Geo` Elixir structs are decoded directly via `#[derive(NifStruct)]` with `#[module = "Geo.Point"]` etc. Only the `coordinates` field is read (SRID is ignored); coordinates are `{x, y}` = `{lng, lat}` tuples (`NifTuple`), converted into `geo` crate types before being handed to h3o.
- NIFs return `Result<T, Atom>`, which Rustler encodes as `{:ok, value}` / `{:error, atom}`. Error atoms are declared in the `atoms` module and should match the error atoms in the Elixir `@spec`.
- Polygon-filling NIFs use `ContainmentMode::Covers` and deduplicate results with `itertools::unique`, and are scheduled on dirty CPU schedulers (`schedule = "DirtyCpu"`) because they can be long-running.

Tests use GeoJSON fixtures in `test/support/` decoded via `Jason` + `Geo.JSON` (Jason is available transitively through Rustler). The benchmark reuses the same fixtures.

## Releasing

Precompiled NIFs are built by `.github/workflows/release.yml` across a matrix of targets and attached to the GitHub release when a tag is pushed. The release flow is:

1. Bump `@version` in `mix.exs` (the workflow extracts the version from this line, so keep its format `  @version "x.y.z"`).
2. Commit, tag `vX.Y.Z` and push the tag; wait for the workflow to publish the artefacts.
3. Run `mix rustler_precompiled.download H3Geo --all --print` to regenerate `checksum-Elixir.H3Geo.exs`.
4. `mix hex.publish` (the checksum file is included in the package via `package.files`).

If you add a target to the `targets` list in `lib/h3_geo.ex`, it must also be added to the workflow matrix.
