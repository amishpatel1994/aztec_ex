defmodule AztecEx.GaloisField do
  @moduledoc """
  Finite field arithmetic over GF(2^p) using precomputed log/antilog tables.

  Aztec codes use Reed-Solomon error correction over these fields:

    * GF(16) -- 4-bit, for mode messages
    * GF(64) -- 6-bit, for 1-2 layer data
    * GF(256) -- 8-bit, for 3-8 layer data
    * GF(1024) -- 10-bit, for 9-22 layer data
    * GF(4096) -- 12-bit, for 23-32 layer data

  Each field is identified by its bit size (4, 6, 8, 10, or 12).
  """

  import Bitwise

  @type field_size :: 4 | 6 | 8 | 10 | 12

  @primitive_polynomials %{
    4 => 0b10011,
    6 => 0b1000011,
    8 => 0b100101101,
    10 => 0b10000001001,
    12 => 0b1000001101001
  }

  @fields Map.keys(@primitive_polynomials)

  for size <- @fields do
    poly = @primitive_polynomials[size]
    order = 1 <<< size
    max = order - 1

    {exp_table, log_table} =
      Enum.reduce(0..(max - 1), {%{}, %{}}, fn i, {exp_acc, log_acc} ->
        x =
          if i == 0 do
            1
          else
            prev = Map.fetch!(exp_acc, i - 1)
            val = prev <<< 1

            if (val &&& order) != 0 do
              bxor(val, poly) &&& max
            else
              val
            end
          end

        {Map.put(exp_acc, i, x), Map.put(log_acc, x, i)}
      end)

    @doc false
    def exp_table(unquote(size), i) when i >= 0 do
      unquote(Macro.escape(exp_table))[rem(i, unquote(max))]
    end

    @doc false
    def log_table(unquote(size), 0), do: raise(ArgumentError, "log(0) is undefined in GF")

    def log_table(unquote(size), x) when x > 0 and x < unquote(order) do
      unquote(Macro.escape(log_table))[x]
    end

    @doc false
    def order(unquote(size)), do: unquote(order)

    @doc false
    def max_value(unquote(size)), do: unquote(max)
  end

  @doc """
  Addition in GF(2^p) is XOR.
  """
  @spec add(field_size(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def add(_size, a, b), do: bxor(a, b)

  @doc """
  Subtraction in GF(2^p) is the same as addition (XOR).
  """
  @spec subtract(field_size(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def subtract(size, a, b), do: add(size, a, b)

  @doc """
  Multiplies two elements in GF(2^p).
  """
  @spec multiply(field_size(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def multiply(_size, 0, _b), do: 0
  def multiply(_size, _a, 0), do: 0

  def multiply(size, a, b) do
    exp_table(size, log_table(size, a) + log_table(size, b))
  end

  @doc """
  Divides `a` by `b` in GF(2^p). Raises on division by zero.
  """
  @spec divide(field_size(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def divide(_size, _a, 0), do: raise(ArgumentError, "division by zero in GF")
  def divide(_size, 0, _b), do: 0

  def divide(size, a, b) do
    max = max_value(size)
    exp_table(size, rem(log_table(size, a) - log_table(size, b) + max, max))
  end

  @doc """
  Computes the multiplicative inverse of `a` in GF(2^p).
  """
  @spec inverse(field_size(), non_neg_integer()) :: non_neg_integer()
  def inverse(_size, 0), do: raise(ArgumentError, "inverse of 0 is undefined in GF")

  def inverse(size, a) do
    max = max_value(size)
    exp_table(size, max - log_table(size, a))
  end

  @doc """
  Raises `a` to the power `n` in GF(2^p).
  """
  @spec power(field_size(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def power(_size, _a, 0), do: 1
  def power(_size, 0, _n), do: 0

  def power(size, a, n) do
    exp_table(size, rem(log_table(size, a) * n, max_value(size)))
  end

  @doc """
  Returns `2^n` in GF(2^p), i.e. the generator raised to power n.
  """
  @spec exp(field_size(), non_neg_integer()) :: non_neg_integer()
  def exp(size, n), do: exp_table(size, n)

  @doc """
  Returns the list of valid field sizes.
  """
  @spec field_sizes() :: [field_size()]
  def field_sizes, do: unquote(@fields)
end
