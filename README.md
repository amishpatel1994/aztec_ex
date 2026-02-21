# AztecEx

Pure Elixir library for encoding and decoding **Aztec 2D barcodes** per
[ISO/IEC 24778:2024](https://www.iso.org/standard/83498.html).

No external dependencies or NIFs -- works everywhere Elixir runs.

## Features

- **Encode** arbitrary binary data into an Aztec symbol (compact or full-range)
- **Decode** an Aztec symbol back to the original data
- **Reed-Solomon** error correction (encode and decode) over GF(2^p)
- **SVG** and **text/Unicode** renderers included
- Supports all 5 encoding modes (Upper, Lower, Mixed, Punctuation, Digit) with
  optimal mode switching via dynamic programming
- Configurable error correction level, symbol size, and render options

## Installation

Add `aztec_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aztec_ex, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Encode

```elixir
{:ok, code} = AztecEx.encode("Hello World")
# => %AztecEx.Code{compact: true, layers: 2, size: 19, ...}
```

### Decode

```elixir
{:ok, data} = AztecEx.decode(code.matrix)
# => "Hello World"
```

### Render as SVG

```elixir
svg = AztecEx.to_svg(code, module_size: 4, margin: 2)
File.write!("barcode.svg", svg)
```

### Render as text (terminal)

```elixir
IO.puts(AztecEx.to_text(code))
```

## Options

### Encoding

| Option              | Type      | Default | Description                                  |
|---------------------|-----------|---------|----------------------------------------------|
| `:error_correction` | `float`   | `0.23`  | Minimum error correction ratio               |
| `:min_layers`       | `integer` | —       | Minimum number of data layers                |
| `:compact`          | `boolean` | auto    | Force compact (`true`) or full-range (`false`)|

### SVG Rendering

| Option         | Type      | Default     | Description                     |
|----------------|-----------|-------------|---------------------------------|
| `:module_size` | `integer` | `4`         | Pixel size of each module       |
| `:margin`      | `integer` | `1`         | Quiet zone modules around symbol|
| `:dark_color`  | `string`  | `"#000000"` | Color for dark modules          |
| `:light_color` | `string`  | `"#FFFFFF"` | Color for light modules         |

### Text Rendering

| Option     | Type     | Default | Description                 |
|------------|----------|---------|-----------------------------|
| `:dark`    | `string` | `"██"`  | Character(s) for dark module|
| `:light`   | `string` | `"  "`  | Character(s) for light module|
| `:newline` | `string` | `"\n"`  | Line separator              |

## Architecture

```
AztecEx.encode/2
  ├── HighLevelEncoder   (data → optimal bitstream)
  ├── BitStuffing        (stuff + pad to codeword boundary)
  ├── ReedSolomon.Encoder (generate check codewords)
  └── Encoder            (symbol layout → BitMatrix)

AztecEx.decode/1
  ├── Decoder            (detect finder, read mode/data)
  ├── ReedSolomon.Decoder (error correction)
  ├── BitStuffing        (unstuff)
  └── HighLevelDecoder   (bitstream → bytes)
```

## License

GPL-3.0-only. See [LICENSE](LICENSE) for details.
