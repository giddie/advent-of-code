# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1         38.12       26.23 ms    ±11.12%       25.98 ms       32.77 ms
# part_2          1.43      700.43 ms     ±0.94%      701.90 ms      710.00 ms
#
# Comparison:
# part_1         38.12
# part_2          1.43 - 26.70x slower +674.20 ms
#
# Memory usage statistics:
#
# Name           average  deviation         median         99th %
# part_1         2.16 MB
# part_2         2.51 MB - 1.16x memory usage +0.35 MB

defmodule Main do
  @moduledoc false

  @type equation :: {non_neg_integer(), [non_neg_integer()]}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_line(String.t()) :: equation()
  defp parse_line(line) do
    [target, rest] = String.split(line, ": ")
    numbers = String.split(rest)

    {
      String.to_integer(target),
      Enum.map(numbers, &String.to_integer/1)
    }
  end

  @spec permutations([non_neg_integer()], non_neg_integer(), [atom()]) :: [non_neg_integer()]
  defp permutations([number], _target, _operators), do: [number]

  defp permutations([number | _tail], target, _operators) when number > target, do: [number]

  defp permutations([left, right | tail], target, operators) do
    Enum.map(operators, fn
      :+ -> permutations([left * right | tail], target, operators)
      :* -> permutations([left + right | tail], target, operators)
      :|| -> permutations([String.to_integer("#{left}#{right}") | tail], target, operators)
    end)
    |> Enum.concat()
  end

  @spec solvable?(equation(), [atom()]) :: boolean()
  defp solvable?({target, numbers}, operators) do
    permutations(numbers, target, operators)
    |> Enum.any?(&(&1 == target))
  end

  @spec count_solvable([atom()]) :: non_neg_integer()
  defp count_solvable(operators) do
    line_stream()
    |> Stream.map(&parse_line/1)
    |> Task.async_stream(&{&1, solvable?(&1, operators)})
    |> Stream.flat_map(fn
      {:ok, {{target, _numbers}, true}} -> [target]
      {:ok, _} -> []
    end)
    |> Enum.sum()
  end

  @spec part_1() :: any()
  def part_1() do
    count_solvable([:+, :*])
  end

  @spec part_2() :: any()
  def part_2() do
    count_solvable([:+, :*, :||])
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
