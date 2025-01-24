# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1         50.32       19.87 ms     ±6.73%       19.49 ms       24.17 ms
# part_2          1.66      601.86 ms     ±2.10%      598.66 ms      622.53 ms
#
# Comparison:
# part_1         50.32
# part_2          1.66 - 30.29x slower +581.99 ms
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1        15.11 MB
# part_2       193.87 MB - 12.83x memory usage +178.77 MB

defmodule Main do
  @moduledoc false

  @type point :: {integer(), integer()}
  @type grid :: %{point() => String.t()}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_grid([String.t()]) :: grid()
  defp parse_grid(lines) do
    lines = Enum.to_list(lines)

    grid = %{
      path_points: MapSet.new(),
      start: :none,
      end: :none,
      bounds: {
        Enum.count(lines) - 1,
        byte_size(Enum.at(lines, 0)) - 1
      }
    }

    for {line, y} <- Enum.with_index(lines),
        {char, x} <- Enum.with_index(:binary.bin_to_list(line)),
        reduce: grid do
      grid ->
        case char do
          ?# -> grid
          ?. -> %{grid | path_points: MapSet.put(grid.path_points, {y, x})}
          ?S -> %{grid | start: {y, x}}
          ?E -> %{grid | end: {y, x}}
        end
    end
  end

  @spec main_path(MapSet.t(), point(), [point()]) :: [point()]
  defp main_path(_path_points, target, [target | _] = path), do: path

  defp main_path(path_points, target, [{y, x} | path_tail] = path) do
    [{-1, 0}, {1, 0}, {0, -1}, {0, 1}]
    |> Enum.reduce_while(:none, fn {delta_y, delta_x}, :none ->
      neighbour = {y + delta_y, x + delta_x}
      prev_point = Enum.slice(path_tail, 0..0)

      if neighbour not in prev_point and neighbour in path_points do
        {:halt, {:some, neighbour}}
      else
        {:cont, :none}
      end
    end)
    |> then(fn
      {:some, neighbour} -> main_path(path_points, target, [neighbour | path])
      :none -> [target | path]
    end)
  end

  @spec manhattan_distance_diamond(non_neg_integer()) :: [point()]
  defp manhattan_distance_diamond(distance) do
    top_and_bottom =
      Stream.unfold({distance, 0}, fn {line_y, left_x} ->
        Enum.flat_map(-left_x..left_x, fn x ->
          [
            {line_y, x},
            {-line_y, x}
          ]
        end)
        |> then(&{&1, {line_y - 1, left_x + 1}})
      end)
      |> Enum.take(distance)
      |> Enum.concat()

    middle =
      [-distance..-1, 1..distance]
      |> Stream.concat()
      |> Enum.map(&{0, &1})

    top_and_bottom ++ middle
  end

  @spec count_cheats([point()], non_neg_integer()) :: non_neg_integer()
  defp count_cheats(main_path, max_length) do
    manhattan_distance_diamond = manhattan_distance_diamond(max_length)
    main_path_with_index = Enum.with_index(main_path)

    main_path_distances =
      for {point, distance} <- main_path_with_index, reduce: %{} do
        acc -> Map.put(acc, point, distance)
      end

    Enum.sum_by(main_path_with_index, fn {{base_y, base_x}, base_distance} ->
      for {delta_y, delta_x} <- manhattan_distance_diamond,
          point = {base_y + delta_y, base_x + delta_x},
          point_distance = Map.get(main_path_distances, point, base_distance),
          manhattan_distance = abs(delta_y) + abs(delta_x),
          score = point_distance - base_distance - manhattan_distance,
          score >= 100,
          reduce: 0 do
        acc -> acc + 1
      end
    end)
  end

  @spec part_1() :: any()
  def part_1() do
    grid =
      line_stream()
      |> parse_grid()

    main_path(grid.path_points, grid.end, [grid.start])
    |> count_cheats(2)
  end

  @spec part_2() :: any()
  def part_2() do
    grid =
      line_stream()
      |> parse_grid()

    main_path(grid.path_points, grid.end, [grid.start])
    |> count_cheats(20)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
