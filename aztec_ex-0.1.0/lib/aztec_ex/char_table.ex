defmodule AztecEx.CharTable do
  @moduledoc """
  Aztec barcode character encoding tables per ISO/IEC 24778.

  Aztec uses 5 encoding modes (Upper, Lower, Mixed, Punctuation, Digit)
  each mapping characters to 4- or 5-bit codes. Mode transitions use
  latch (permanent) and shift (one-character) codes.
  """

  @type mode :: :upper | :lower | :mixed | :punct | :digit

  @upper_chars %{
    ?\s => 1,
    ?A => 2,
    ?B => 3,
    ?C => 4,
    ?D => 5,
    ?E => 6,
    ?F => 7,
    ?G => 8,
    ?H => 9,
    ?I => 10,
    ?J => 11,
    ?K => 12,
    ?L => 13,
    ?M => 14,
    ?N => 15,
    ?O => 16,
    ?P => 17,
    ?Q => 18,
    ?R => 19,
    ?S => 20,
    ?T => 21,
    ?U => 22,
    ?V => 23,
    ?W => 24,
    ?X => 25,
    ?Y => 26,
    ?Z => 27
  }

  @lower_chars %{
    ?\s => 1,
    ?a => 2,
    ?b => 3,
    ?c => 4,
    ?d => 5,
    ?e => 6,
    ?f => 7,
    ?g => 8,
    ?h => 9,
    ?i => 10,
    ?j => 11,
    ?k => 12,
    ?l => 13,
    ?m => 14,
    ?n => 15,
    ?o => 16,
    ?p => 17,
    ?q => 18,
    ?r => 19,
    ?s => 20,
    ?t => 21,
    ?u => 22,
    ?v => 23,
    ?w => 24,
    ?x => 25,
    ?y => 26,
    ?z => 27
  }

  @mixed_chars %{
    ?\s => 1,
    1 => 2,
    2 => 3,
    3 => 4,
    4 => 5,
    5 => 6,
    6 => 7,
    7 => 8,
    8 => 9,
    9 => 10,
    10 => 11,
    11 => 12,
    12 => 13,
    13 => 14,
    27 => 15,
    28 => 16,
    29 => 17,
    30 => 18,
    31 => 19,
    ?@ => 20,
    ?\\ => 21,
    ?^ => 22,
    ?_ => 23,
    ?` => 24,
    ?| => 25,
    ?~ => 26,
    127 => 27
  }

  @punct_chars %{
    ?\r => 1,
    {?\r, ?\n} => 2,
    {?., ?\s} => 3,
    {?,, ?\s} => 4,
    {?:, ?\s} => 5,
    ?! => 6,
    ?" => 7,
    ?# => 8,
    ?$ => 9,
    ?% => 10,
    ?& => 11,
    ?' => 12,
    ?( => 13,
    ?) => 14,
    ?* => 15,
    ?+ => 16,
    ?, => 17,
    ?- => 18,
    ?. => 19,
    ?/ => 20,
    ?: => 21,
    ?; => 22,
    ?< => 23,
    ?= => 24,
    ?> => 25,
    ?? => 26,
    ?[ => 27,
    ?] => 28,
    ?{ => 29,
    ?} => 30
  }

  @digit_chars %{
    ?\s => 1,
    ?0 => 2,
    ?1 => 3,
    ?2 => 4,
    ?3 => 5,
    ?4 => 6,
    ?5 => 7,
    ?6 => 8,
    ?7 => 9,
    ?8 => 10,
    ?9 => 11,
    ?, => 12,
    ?. => 13
  }

  @latch_codes %{
    {:upper, :lower} => {28, 5},
    {:upper, :mixed} => {29, 5},
    {:upper, :digit} => {30, 5},
    {:lower, :mixed} => {29, 5},
    {:lower, :digit} => {30, 5},
    {:mixed, :lower} => {28, 5},
    {:mixed, :upper} => {29, 5},
    {:mixed, :punct} => {30, 5},
    {:digit, :upper} => {14, 4},
    {:punct, :upper} => {31, 5}
  }

  @shift_codes %{
    {:upper, :punct} => {0, 5},
    {:lower, :punct} => {0, 5},
    {:lower, :upper} => {28, 5},
    {:mixed, :punct} => {0, 5},
    {:digit, :punct} => {0, 4},
    {:digit, :upper} => {15, 4}
  }

  @doc """
  Returns the code value for a byte in the given mode, or nil if not available.
  """
  @spec char_code(mode(), non_neg_integer()) :: non_neg_integer() | nil
  def char_code(:upper, byte), do: Map.get(@upper_chars, byte)
  def char_code(:lower, byte), do: Map.get(@lower_chars, byte)
  def char_code(:mixed, byte), do: Map.get(@mixed_chars, byte)
  def char_code(:punct, byte), do: Map.get(@punct_chars, byte)
  def char_code(:digit, byte), do: Map.get(@digit_chars, byte)

  @doc """
  Returns the code value for a two-byte punctuation pair, or nil.
  """
  @spec pair_code(non_neg_integer(), non_neg_integer()) :: non_neg_integer() | nil
  def pair_code(b1, b2), do: Map.get(@punct_chars, {b1, b2})

  @doc """
  Returns the bit width for codes in the given mode.
  """
  @spec bit_width(mode()) :: 4 | 5
  def bit_width(:digit), do: 4
  def bit_width(_mode), do: 5

  @doc """
  Returns the latch code and bit width to transition from one mode to another.
  Returns `nil` if no direct latch exists.
  """
  @spec latch(mode(), mode()) :: {non_neg_integer(), pos_integer()} | nil
  def latch(from, to) when from != to, do: Map.get(@latch_codes, {from, to})
  def latch(_from, _to), do: nil

  @doc """
  Returns the shift code and bit width to temporarily shift to another mode.
  Returns `nil` if no direct shift exists.
  """
  @spec shift(mode(), mode()) :: {non_neg_integer(), pos_integer()} | nil
  def shift(from, to) when from != to, do: Map.get(@shift_codes, {from, to})
  def shift(_from, _to), do: nil

  @doc """
  Returns all modes that can encode the given byte.
  """
  @spec modes_for_byte(non_neg_integer()) :: [mode()]
  def modes_for_byte(byte) do
    [:upper, :lower, :mixed, :punct, :digit]
    |> Enum.filter(&(char_code(&1, byte) != nil))
  end

  @doc """
  Returns the list of all modes.
  """
  @spec modes() :: [mode()]
  def modes, do: [:upper, :lower, :mixed, :punct, :digit]

  @doc """
  Returns the reverse mapping: code value -> byte for a given mode.
  Used by the decoder.
  """
  @spec code_to_char(mode(), non_neg_integer()) ::
          non_neg_integer() | {non_neg_integer(), non_neg_integer()} | nil
  def code_to_char(:upper, code), do: reverse_lookup(@upper_chars, code)
  def code_to_char(:lower, code), do: reverse_lookup(@lower_chars, code)
  def code_to_char(:mixed, code), do: reverse_lookup(@mixed_chars, code)
  def code_to_char(:punct, code), do: reverse_lookup(@punct_chars, code)
  def code_to_char(:digit, code), do: reverse_lookup(@digit_chars, code)

  defp reverse_lookup(map, code) do
    Enum.find_value(map, fn {k, v} -> if v == code, do: k end)
  end

  @doc """
  Binary shift code value (same in Upper, Lower, Mixed: 31; Digit: not available directly).
  """
  @spec binary_shift_code(mode()) :: {non_neg_integer(), pos_integer()} | nil
  def binary_shift_code(:upper), do: {31, 5}
  def binary_shift_code(:lower), do: {31, 5}
  def binary_shift_code(:mixed), do: {31, 5}
  def binary_shift_code(:punct), do: {31, 5}
  def binary_shift_code(:digit), do: nil

  @doc """
  FLG(n) code in punctuation mode (code 0).
  """
  @spec flg_code() :: {non_neg_integer(), pos_integer()}
  def flg_code, do: {0, 5}
end
