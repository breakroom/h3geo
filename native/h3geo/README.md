# NIF for Elixir.H3Geo

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule H3Geo do
  use Rustler, otp_app: :h3geo, crate: "h3geo"

  # When your NIF is loaded, it will override this function.
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
