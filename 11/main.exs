# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1        493.29        2.03 ms   ±106.40%        2.05 ms        2.70 ms
# part_2         10.93       91.48 ms    ±11.40%       93.48 ms      145.03 ms
#
# Comparison:
# part_1        493.29
# part_2         10.93 - 45.13x slower +89.45 ms
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1         1.76 MB
# part_2        88.87 MB - 50.48x memory usage +87.11 MB

defmodule Main do
  @moduledoc false

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_input() :: [integer()]
  defp parse_input() do
    line_stream()
    |> Enum.at(0)
    |> String.split()
    |> Enum.map(&String.to_integer/1)
  end

  @spec step_stone(integer()) :: [integer()]
  defp step_stone(0), do: [1]

  defp step_stone(stone) do
    num_digits = floor(:math.log10(stone)) + 1

    if Integer.mod(num_digits, 2) == 0 do
      divisor = 10 ** div(num_digits, 2)
      left = div(stone, divisor)
      right = rem(stone, divisor)
      [left, right]
    else
      [stone * 2024]
    end
  end

  @spec num_stones_after_steps([integer()], non_neg_integer(), map()) ::
          {non_neg_integer(), map()}
  defp num_stones_after_steps(stones, 0, memory), do: {Enum.count(stones), memory}

  defp num_stones_after_steps(stones, num_steps, memory) do
    for stone <- stones, reduce: {0, memory} do
      {sum, memory} ->
        case Map.fetch(memory, {stone, num_steps}) do
          {:ok, count} ->
            {sum + count, memory}

          :error ->
            stone
            |> step_stone()
            |> num_stones_after_steps(num_steps - 1, memory)
            |> then(fn {count, memory} ->
              {
                sum + count,
                Map.put(memory, {stone, num_steps}, count)
              }
            end)
        end
    end
  end

  @spec part_1() :: any()
  def part_1() do
    parse_input()
    |> num_stones_after_steps(25, %{})
    |> elem(0)
  end

  @spec part_2() :: any()
  def part_2() do
    parse_input()
    |> num_stones_after_steps(75, %{})
    |> elem(0)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
