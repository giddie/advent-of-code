# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1        773.23        1.29 ms   ±136.33%        1.20 ms        2.12 ms
# part_2        868.88        1.15 ms   ±150.91%        1.07 ms        1.71 ms
#
# Comparison:
# part_1        773.23 - 1.12x slower +0.142 ms
# part_2        868.88
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1         1.09 MB - 1.56x memory usage +0.39 MB
# part_2         0.70 MB

defmodule Main do
  @moduledoc false

  @spec line_stream() :: Stream.t()
  def line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_line(String.t()) :: {number(), number()}
  def parse_line(line) when is_binary(line) do
    line
    |> String.split(" ", trim: true)
    |> Enum.map(&String.to_integer/1)
    |> then(fn [left, right] ->
      {left, right}
    end)
  end

  @spec lists() :: {list(), list()}
  def lists() do
    line_stream()
    |> Enum.to_list()
    |> Enum.map(&parse_line/1)
    |> Enum.unzip()
  end

  @spec part_1() :: any()
  def part_1() do
    {left, right} = lists()

    [
      Enum.sort(left),
      Enum.sort(right)
    ]
    |> Enum.zip()
    |> Enum.map(fn {left, right} ->
      abs(right - left)
    end)
    |> Enum.sum()
  end

  @spec part_2() :: any()
  def part_2() do
    {left, right} = lists()
    frequencies = Enum.frequencies(right)

    left
    |> Enum.map(& &1 * Map.get(frequencies, &1, 0))
    |> Enum.sum()
  end
end

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
