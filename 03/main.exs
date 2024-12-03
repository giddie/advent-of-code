defmodule Main do
  @moduledoc false

  @type muls :: [{number(), number()}]

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec input() :: String.t()
  defp input() do
    line_stream()
    |> Enum.join()
  end

  @spec parse_muls(String.t()) :: muls()
  defp parse_muls(string) when is_binary(string) do
    ~r/mul\((\d+),(\d+)\)/
    |> Regex.scan(string)
    |> Enum.map(fn [_whole, left, right] ->
      {
        String.to_integer(left),
        String.to_integer(right)
      }
    end)
  end

  @spec parse_do(String.t()) :: {muls(), String.t()}
  defp parse_do(string) when is_binary(string) do
    ~r/(.*?)(?:don't\(\)(.*)|$)/
    |> Regex.run(string)
    |> then(fn
      [_match, enabled_substring] ->
        {
          parse_muls(enabled_substring),
          ""
        }

      [_match, enabled_substring, tail] ->
        {
          parse_muls(enabled_substring),
          tail
        }
    end)
  end

  @spec parse_dont(String.t()) :: String.t()
  defp parse_dont(string) when is_binary(string) do
    ~r/.*?do\(\)(.*)/
    |> Regex.run(string)
    |> then(fn
      nil -> ""
      [_match, tail] -> tail
    end)
  end

  @spec parse(String.t()) :: muls()
  defp parse(""), do: []

  defp parse(string) when is_binary(string) do
    {muls, tail} = parse_do(string)

    tail_muls =
      tail
      |> parse_dont()
      |> parse()

    muls ++ tail_muls
  end

  @spec reduce_muls(muls()) :: number()
  defp reduce_muls(muls) when is_list(muls) do
    muls
    |> Enum.map(fn {left, right} ->
      left * right
    end)
    |> Enum.sum()
  end

  @spec part_1() :: any()
  def part_1() do
    input()
    |> parse_muls()
    |> reduce_muls()
  end

  @spec part_2() :: any()
  def part_2() do
    input()
    |> parse()
    |> reduce_muls()
  end
end

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
