# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1         36.75       27.21 ms    ±12.69%       26.08 ms       43.63 ms
# part_2         29.54       33.85 ms     ±5.23%       34.09 ms       41.94 ms
#
# Comparison:
# part_1         36.75
# part_2         29.54 - 1.24x slower +6.64 ms
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1        37.50 MB
# part_2        42.86 MB - 1.14x memory usage +5.36 MB

defmodule Main do
  @moduledoc false

  @type prefix_tree_node ::
          {:leaf, MapSet.t(String.t())}
          | {:node | :leaf_node, %{char() => prefix_tree_node()}}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_input() :: {prefix_tree_node(), [String.t()]}
  defp parse_input() do
    [towel_line, "" | patterns] =
      line_stream()
      |> Enum.to_list()

    towels =
      towel_line
      |> String.split(", ")
      |> Enum.reduce({:node, %{}}, &prefix_tree_put(&2, &1))

    {towels, patterns}
  end

  @spec prefix_tree_put(prefix_tree_node, String.t()) :: prefix_tree_node()
  defp prefix_tree_put({:leaf, values}, "") do
    {:leaf, MapSet.put(values, "")}
  end

  defp prefix_tree_put({:leaf, values}, <<char, _::bitstring>> = path) do
    if Enum.any?(values, &match?(<<^char, _::bitstring>>, &1)) do
      Stream.concat([path], values)
      |> Enum.reduce({:node, %{}}, &prefix_tree_put(&2, &1))
    else
      {:leaf, MapSet.put(values, path)}
    end
  end

  defp prefix_tree_put({type, sub_nodes}, <<>>) when type in [:node, :leaf_node] do
    {:leaf_node, sub_nodes}
  end

  defp prefix_tree_put({type, sub_nodes}, <<char, rest::bitstring>>)
       when type in [:node, :leaf_node] do
    {type, Map.update(sub_nodes, char, {:leaf, MapSet.new([rest])}, &prefix_tree_put(&1, rest))}
  end

  @spec pattern_splits(prefix_tree_node(), String.t(), String.t()) ::
          Enumerable.t({String.t(), String.t()})
  defp pattern_splits(prefix_tree, string, path \\ "")

  defp pattern_splits(_prefix_tree, <<>>, _path), do: []

  defp pattern_splits({type, sub_nodes}, <<char, rest::bitstring>>, path)
       when type in [:node, :leaf_node] do
    case Map.fetch(sub_nodes, char) do
      {:ok, {:leaf, values}} ->
        Enum.flat_map(values, fn value ->
          case rest do
            ^value <> right -> [{String.reverse(<<char, path::bitstring>>) <> value, right}]
            _ -> []
          end
        end)

      {:ok, {:leaf_node, _sub_nodes} = next_node} ->
        next_path = <<char, path::bitstring>>

        [
          {String.reverse(next_path), rest}
          | pattern_splits(next_node, rest, next_path)
        ]

      {:ok, {:node, _sub_nodes} = next_node} ->
        pattern_splits(next_node, rest, <<char, path::bitstring>>)

      :error ->
        []
    end
  end

  @spec pattern_viability(prefix_tree_node(), String.t(), known) :: {result, known}
        when known: %{String.t() => result},
             result: :possible | :impossible
  defp pattern_viability(_prefix_tree, "", known), do: {:possible, known}

  defp pattern_viability(prefix_tree, pattern, known) do
    case Map.fetch(known, pattern) do
      {:ok, result} ->
        {result, known}

      :error ->
        pattern_splits(prefix_tree, pattern)
        |> Enum.reduce_while(
          {:impossible, known},
          fn {_left, right}, {:impossible, known} ->
            {result, known} = pattern_viability(prefix_tree, right, known)
            known = Map.put(known, right, result)

            case result do
              :possible -> {:halt, {:possible, known}}
              :impossible -> {:cont, {:impossible, known}}
            end
          end
        )
    end
  end

  @spec count_arrangements(prefix_tree_node(), String.t(), known) :: {result, known}
        when known: %{String.t() => result},
             result: non_neg_integer()
  defp count_arrangements(_prefix_tree, "", known), do: {1, known}

  defp count_arrangements(prefix_tree, pattern, known) do
    case Map.fetch(known, pattern) do
      {:ok, result} ->
        {result, known}

      :error ->
        pattern_splits(prefix_tree, pattern)
        |> Enum.reduce(
          {0, known},
          fn {_left, right}, {acc, known} ->
            {result, known} = count_arrangements(prefix_tree, right, known)

            {
              acc + result,
              Map.put(known, right, result)
            }
          end
        )
    end
  end

  @spec part_1() :: any()
  def part_1() do
    {towels, patterns} = parse_input()

    Stream.transform(patterns, %{}, fn pattern, known ->
      case pattern_viability(towels, pattern, known) do
        {:possible, known} -> {[pattern], known}
        {:impossible, known} -> {[], known}
      end
    end)
    |> Enum.count()
  end

  @spec part_2() :: any()
  def part_2() do
    {towels, patterns} = parse_input()

    for pattern <- patterns, reduce: {0, %{}} do
      {sum, known} ->
        {count, known} = count_arrangements(towels, pattern, known)
        {sum + count, known}
    end
    |> then(fn {sum, _known} -> sum end)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
