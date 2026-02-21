defmodule AztecEx.ReedSolomon.Decoder do
  @moduledoc """
  Reed-Solomon decoder that detects and corrects errors.

  Uses syndrome computation, the Berlekamp-Massey algorithm to find
  the error locator polynomial, Chien search to find error positions,
  and the Forney algorithm to compute error magnitudes.

  Compatible with Aztec's RS convention: generator roots are
  a^1, a^2, ..., a^(2t) where a = 2.
  """

  alias AztecEx.GaloisField, as: GF

  @doc """
  Attempts to decode (error-correct) a received message.

  `received` is the full codeword (data + check symbols) in high-to-low
  degree order. `num_check` is the number of check symbols.
  `field_size` is the GF bit width (4, 6, 8, 10, or 12).

  Returns `{:ok, corrected}` where `corrected` is the full corrected
  codeword, or `{:error, reason}` if too many errors to correct.
  """
  @spec decode(GF.field_size(), [non_neg_integer()], pos_integer()) ::
          {:ok, [non_neg_integer()]} | {:error, String.t()}
  def decode(field_size, received, num_check) do
    syndromes = compute_syndromes(field_size, received, num_check)

    if Enum.all?(syndromes, &(&1 == 0)) do
      {:ok, received}
    else
      case berlekamp_massey(field_size, syndromes, num_check) do
        {:ok, error_locator} ->
          case chien_search(field_size, error_locator, length(received)) do
            {:ok, error_positions} ->
              error_magnitudes =
                forney(field_size, syndromes, error_locator, error_positions)

              corrected =
                apply_corrections(field_size, received, error_positions, error_magnitudes)

              {:ok, corrected}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc false
  def compute_syndromes(field_size, received, num_check) do
    for i <- 1..num_check do
      root = GF.exp(field_size, i)
      eval_poly_desc(field_size, received, root)
    end
  end

  # Evaluates a polynomial with coefficients in DESCENDING degree order
  # [a_n, a_{n-1}, ..., a_0] -> a_n*x^n + ... + a_0
  defp eval_poly_desc(field_size, coefficients, x) do
    Enum.reduce(coefficients, 0, fn coeff, acc ->
      GF.add(field_size, GF.multiply(field_size, acc, x), coeff)
    end)
  end

  # Evaluates a polynomial with coefficients in ASCENDING degree order
  # [a_0, a_1, ..., a_n] -> a_0 + a_1*x + ... + a_n*x^n
  defp eval_poly_asc(field_size, coefficients, x) do
    eval_poly_desc(field_size, Enum.reverse(coefficients), x)
  end

  @doc false
  def berlekamp_massey(field_size, syndromes, num_check) do
    n = length(syndromes)
    max_errors = div(num_check, 2)

    # sigma is in ascending order: [1, sigma_1, sigma_2, ...]
    # representing sigma(x) = 1 + sigma_1*x + sigma_2*x^2 + ...
    {sigma, _b, _l, _delta_n} =
      Enum.reduce(0..(n - 1), {[1], [1], 0, 1}, fn i, {sigma, b, l, _delta_n} ->
        delta = compute_delta(field_size, sigma, syndromes, i)

        if delta == 0 do
          {sigma, [0 | b], l, 1}
        else
          t = add_polys(field_size, sigma, scale_poly(field_size, [0 | b], delta))

          if 2 * l <= i do
            new_b = scale_poly(field_size, sigma, GF.inverse(field_size, delta))
            {t, new_b, i + 1 - l, delta}
          else
            {t, [0 | b], l, delta}
          end
        end
      end)

    num_errors = length(sigma) - 1

    if num_errors > max_errors do
      {:error, "too many errors to correct (#{num_errors} > #{max_errors})"}
    else
      {:ok, sigma}
    end
  end

  defp compute_delta(field_size, sigma, syndromes, i) do
    sigma
    |> Enum.with_index()
    |> Enum.reduce(0, fn {coeff, j}, acc ->
      GF.add(field_size, acc, GF.multiply(field_size, coeff, Enum.at(syndromes, i - j)))
    end)
  end

  defp add_polys(field_size, a, b) do
    len = max(length(a), length(b))
    a_padded = a ++ List.duplicate(0, len - length(a))
    b_padded = b ++ List.duplicate(0, len - length(b))

    Enum.zip(a_padded, b_padded)
    |> Enum.map(fn {x, y} -> GF.add(field_size, x, y) end)
  end

  defp scale_poly(field_size, poly, scalar) do
    Enum.map(poly, &GF.multiply(field_size, &1, scalar))
  end

  @doc false
  def chien_search(field_size, error_locator, n) do
    num_errors = length(error_locator) - 1
    max_val = GF.max_value(field_size)

    positions =
      for i <- 0..(n - 1),
          inv = GF.exp(field_size, rem(max_val - i, max_val)),
          eval_poly_asc(field_size, error_locator, inv) == 0 do
        i
      end

    if length(positions) == num_errors do
      {:ok, positions}
    else
      {:error, "Chien search found #{length(positions)} roots but expected #{num_errors}"}
    end
  end

  @doc false
  def forney(field_size, syndromes, error_locator, error_positions) do
    omega = compute_error_evaluator(field_size, syndromes, error_locator)
    sigma_prime = formal_derivative(field_size, error_locator)
    max_val = GF.max_value(field_size)

    Enum.map(error_positions, fn pos ->
      x_inv = GF.exp(field_size, rem(max_val - pos, max_val))

      omega_val = eval_poly_asc(field_size, omega, x_inv)
      sigma_prime_val = eval_poly_asc(field_size, sigma_prime, x_inv)

      if sigma_prime_val == 0 do
        0
      else
        GF.divide(field_size, omega_val, sigma_prime_val)
      end
    end)
  end

  # Omega(x) = S(x) * sigma(x) mod x^{num_check}
  # where S(x) = S_1 + S_2*x + ... (ascending order, syndromes are 1-indexed)
  # Both S and sigma are in ascending order, product is truncated.
  defp compute_error_evaluator(field_size, syndromes, error_locator) do
    product = multiply_polys_asc(field_size, syndromes, error_locator)
    Enum.take(product, length(error_locator))
  end

  # Multiplies two polynomials both in ascending order, returns ascending order
  defp multiply_polys_asc(field_size, a, b) do
    len_a = length(a)
    len_b = length(b)
    result_len = len_a + len_b - 1

    Enum.map(0..(result_len - 1), fn i ->
      Enum.reduce(0..min(i, len_a - 1), 0, fn j, acc ->
        k = i - j

        if k < len_b do
          term = GF.multiply(field_size, Enum.at(a, j), Enum.at(b, k))
          GF.add(field_size, acc, term)
        else
          acc
        end
      end)
    end)
  end

  # Formal derivative of polynomial in ascending order.
  # d/dx (a_0 + a_1*x + a_2*x^2 + ...) = a_1 + 2*a_2*x + 3*a_3*x^2 + ...
  # In GF(2^p), coefficients with even index in the original vanish
  # because n*a = 0 when n is even (characteristic 2).
  # So derivative = a_1 + a_3*x^2 + a_5*x^4 + ...
  # In ascending order: [a_1, 0, a_3, 0, a_5, ...]
  defp formal_derivative(_field_size, poly) do
    poly
    |> Enum.with_index()
    |> Enum.drop(1)
    |> Enum.map(fn {coeff, i} ->
      if rem(i, 2) == 1, do: coeff, else: 0
    end)
    |> trim_trailing_zeros()
  end

  defp trim_trailing_zeros([]), do: [0]

  defp trim_trailing_zeros(poly) do
    poly
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == 0))
    |> Enum.reverse()
    |> case do
      [] -> [0]
      trimmed -> trimmed
    end
  end

  defp apply_corrections(field_size, received, positions, magnitudes) do
    n = length(received)

    Enum.zip(positions, magnitudes)
    |> Enum.reduce(received, fn {pos, mag}, acc ->
      idx = n - 1 - pos
      old_val = Enum.at(acc, idx)
      List.replace_at(acc, idx, GF.add(field_size, old_val, mag))
    end)
  end
end
