# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1          0.73         1.37 s     ±0.80%         1.36 s         1.38 s
# part_2          0.73         1.38 s     ±0.94%         1.38 s         1.39 s
#
# Comparison:
# part_1          0.73
# part_2          0.73 - 1.01x slower +0.00876 s
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1         1.67 GB
# part_2         1.67 GB - 1.00x memory usage +0 GB

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

  @spec count_cheats([point()], non_neg_integer()) :: non_neg_integer()
  defp count_cheats(main_path, max_length) do
    Stream.unfold({main_path, []}, fn
      {[], _closer_points} ->
        nil

      {[point | path_tail], closer_points} ->
        {
          {point, closer_points},
          {path_tail, [point | closer_points]}
        }
    end)
    |> Enum.sum_by(
      fn {{y, x}, closer_points} ->
        for {{closer_y, closer_x}, closer_distance} <- Enum.with_index(closer_points),
            manhattan_distance = abs(closer_y - y) + abs(closer_x - x),
            manhattan_distance <= max_length,
            score = closer_distance - manhattan_distance + 1,
            score >= 100,
            reduce: 0 do
          acc -> acc + 1
        end
      end
    )
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
