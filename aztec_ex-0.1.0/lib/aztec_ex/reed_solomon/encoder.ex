defmodule AztecEx.ReedSolomon.Encoder do
  @moduledoc """
  Reed-Solomon encoder that generates check codewords.

  Given a list of data codewords and the desired number of check codewords,
  computes the check codewords such that the complete message polynomial
  is divisible by the generator polynomial g(x) = (x - a^1)(x - a^2)...(x - a^K)
  where a = 2 is the primitive element and K is the number of check codewords.

  Note: Aztec uses generator roots starting at a^1 = 2, not a^0 = 1.
  """

  alias AztecEx.GaloisField, as: GF

  @doc """
  Computes the generator polynomial for `num_check` check codewords.

  Returns coefficients in descending degree order: [1, g_{K-1}, ..., g_1, g_0]
  where g(x) = x^K + g_{K-1}*x^{K-1} + ... + g_0.
  """
  @spec generator_poly(GF.field_size(), pos_integer()) :: [non_neg_integer()]
  def generator_poly(field_size, num_check) do
    Enum.reduce(1..num_check, [1], fn i, poly ->
      root = GF.exp(field_size, i)
      multiply_by_binomial(field_size, poly, root)
    end)
  end

  defp multiply_by_binomial(field_size, poly, root) do
    len = length(poly)

    Enum.map(0..len, fn j ->
      from_x = if j < len, do: Enum.at(poly, j), else: 0
      from_root = if j > 0, do: GF.multiply(field_size, Enum.at(poly, j - 1), root), else: 0
      GF.add(field_size, from_x, from_root)
    end)
  end

  @doc """
  Encodes data codewords by computing and returning the check codewords.

  The `data` is a list of integer codewords. `num_check` is the number
  of check codewords to generate. `field_size` is the GF bit width.

  Returns a list of `num_check` check codewords.
  """
  @spec encode(GF.field_size(), [non_neg_integer()], pos_integer()) :: [non_neg_integer()]
  def encode(field_size, data, num_check) do
    gen = generator_poly(field_size, num_check)

    remainder = polynomial_mod(field_size, data ++ List.duplicate(0, num_check), gen)

    pad_len = num_check - length(remainder)

    if pad_len > 0 do
      List.duplicate(0, pad_len) ++ remainder
    else
      remainder
    end
  end

  defp polynomial_mod(field_size, dividend, divisor) do
    divisor_lead = hd(divisor)
    divisor_len = length(divisor)
    dividend_len = length(dividend)

    if dividend_len < divisor_len do
      dividend
    else
      Enum.reduce(0..(dividend_len - divisor_len), dividend, fn _i, current ->
        if hd(current) == 0 do
          tl(current)
        else
          factor = GF.divide(field_size, hd(current), divisor_lead)

          rest =
            current
            |> Enum.zip(divisor ++ List.duplicate(0, length(current) - divisor_len))
            |> Enum.map(fn {a, b} ->
              GF.add(field_size, a, GF.multiply(field_size, b, factor))
            end)

          tl(rest)
        end
      end)
    end
  end
end
