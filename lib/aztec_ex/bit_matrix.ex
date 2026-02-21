defmodule AztecEx.BitMatrix do
  @moduledoc """
  A 2D boolean matrix for representing Aztec barcode symbol grids.

  Each cell is either `true` (dark module) or `false` (light module).
  Backed by a MapSet for efficient sparse storage -- only set (true)
  positions are stored.
  """

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          bits: MapSet.t({non_neg_integer(), non_neg_integer()})
        }

  defstruct width: 0, height: 0, bits: MapSet.new()

  @doc """
  Creates a new empty matrix of the given dimensions.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) do
    %__MODULE__{width: width, height: height}
  end

  @doc """
  Creates a square matrix of the given side length.
  """
  @spec new(non_neg_integer()) :: t()
  def new(size) do
    new(size, size)
  end

  @doc """
  Gets the value at position `{x, y}`. Returns `false` for unset positions.
  """
  @spec get(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def get(%__MODULE__{bits: bits}, x, y) do
    MapSet.member?(bits, {x, y})
  end

  @doc """
  Sets the value at position `{x, y}`.
  """
  @spec set(t(), non_neg_integer(), non_neg_integer(), boolean()) :: t()
  def set(%__MODULE__{bits: bits} = matrix, x, y, true) do
    %{matrix | bits: MapSet.put(bits, {x, y})}
  end

  def set(%__MODULE__{bits: bits} = matrix, x, y, false) do
    %{matrix | bits: MapSet.delete(bits, {x, y})}
  end

  @doc """
  Sets the value at position `{x, y}` to `true`.
  """
  @spec set(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set(matrix, x, y) do
    set(matrix, x, y, true)
  end

  @doc """
  Flips (toggles) the value at position `{x, y}`.
  """
  @spec flip(t(), non_neg_integer(), non_neg_integer()) :: t()
  def flip(%__MODULE__{} = matrix, x, y) do
    set(matrix, x, y, not get(matrix, x, y))
  end

  @doc """
  Sets a rectangular region to the given value.
  """
  @spec set_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          boolean()
        ) :: t()
  def set_region(matrix, x, y, width, height, value \\ true) do
    Enum.reduce(y..(y + height - 1)//1, matrix, fn row, acc ->
      Enum.reduce(x..(x + width - 1)//1, acc, fn col, acc2 ->
        set(acc2, col, row, value)
      end)
    end)
  end

  @doc """
  Returns `{width, height}`.
  """
  @spec dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  def dimensions(%__MODULE__{width: w, height: h}), do: {w, h}

  @doc """
  Converts the matrix to a list of lists of booleans (row-major order).
  """
  @spec to_list(t()) :: [[boolean()]]
  def to_list(%__MODULE__{width: w, height: h} = matrix) do
    for y <- 0..(h - 1)//1 do
      for x <- 0..(w - 1)//1 do
        get(matrix, x, y)
      end
    end
  end

  @doc """
  Creates a BitMatrix from a list of lists of booleans (row-major order).
  """
  @spec from_list([[boolean()]]) :: t()
  def from_list([]) do
    new(0, 0)
  end

  def from_list(rows) do
    height = length(rows)
    width = rows |> hd() |> length()

    bits =
      rows
      |> Enum.with_index()
      |> Enum.reduce(MapSet.new(), fn {row, y}, acc ->
        row
        |> Enum.with_index()
        |> Enum.reduce(acc, fn
          {true, x}, inner_acc -> MapSet.put(inner_acc, {x, y})
          {false, _x}, inner_acc -> inner_acc
        end)
      end)

    %__MODULE__{width: width, height: height, bits: bits}
  end

  @doc """
  Returns the number of set (true) cells.
  """
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{bits: bits}), do: MapSet.size(bits)
end
