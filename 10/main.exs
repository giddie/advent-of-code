# Benchmarks
#
# Name                    ips        average  deviation         median         99th %
# parts_1_and_2        174.84        5.72 ms    ±13.28%        5.61 ms        8.88 ms
#
# Memory usage statistics:
#
# Name             Memory usage
# parts_1_and_2         7.73 MB

defmodule Main do
  @moduledoc false

  @type point :: {non_neg_integer(), non_neg_integer()}
  @type grid :: tuple()

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_grid(Enumerable.t(String.t())) :: grid()
  defp parse_grid(lines) do
    for line <- lines do
      line
      |> :binary.bin_to_list()
      |> Enum.map(&(&1 - ?0))
      |> List.to_tuple()
    end
    |> List.to_tuple()
  end

  @spec grid_bounds(grid()) :: {height, width} when height: integer(), width: integer()
  defp grid_bounds(grid) do
    height = tuple_size(grid)
    width = tuple_size(elem(grid, 0))
    {height, width}
  end

  # @spec print_grid_points(grid(), (point() -> boolean())) :: grid()
  # defp print_grid_points(grid, filter_func) when is_function(filter_func, 1) do
  #   {width, height} = grid_bounds(grid)
  #
  #   for y <- 0..(height - 1) do
  #     for x <- 0..(width - 1), into: "" do
  #       point = {y, x}
  #
  #       if filter_func.(point) do
  #         grid |> elem(y) |> elem(x) |> to_string()
  #       else
  #         "."
  #       end
  #     end
  #   end
  #   |> Enum.join("\n")
  #   |> IO.puts()
  #
  #   IO.puts("")
  #   grid
  # end

  @spec reduce_grid(grid(), acc, (point(), acc -> acc)) :: acc when acc: any()
  defp reduce_grid(grid, acc, func) when is_function(func, 2) do
    {height, width} = grid_bounds(grid)

    for y <- 0..(height - 1) do
      for x <- 0..(width - 1), reduce: acc do
        acc -> func.({y, x}, acc)
      end
    end
    |> Enum.concat()
  end

  @spec find_all(grid(), integer()) :: [point()]
  defp find_all(grid, search_value) do
    reduce_grid(grid, [], fn {y, x} = point, acc ->
      value = grid |> elem(y) |> elem(x)

      if value == search_value do
        [point | acc]
      else
        acc
      end
    end)
  end

  @spec bfs_paths_ending_with_value(grid(), integer(), [point()], [point()]) :: [[point()]]
  defp bfs_paths_ending_with_value(_grid, _target_value, [], final_paths), do: final_paths

  defp bfs_paths_ending_with_value(grid, target_value, active_paths, final_paths) do
    {height, width} = grid_bounds(grid)

    for [{y, x} | _] = path <- active_paths,
        {neighbour_y, neighbour_x} = neighbour <- [
          {y - 1, x},
          {y + 1, x},
          {y, x - 1},
          {y, x + 1}
        ],
        neighbour_y in 0..(width - 1),
        neighbour_x in 0..(height - 1) do
      point_value = grid |> elem(y) |> elem(x)
      neighbour_value = grid |> elem(neighbour_y) |> elem(neighbour_x)

      if neighbour_value == point_value + 1 do
        if neighbour_value == target_value do
          [target: [neighbour | path]]
        else
          [continue: [neighbour | path]]
        end
      else
        []
      end
    end
    |> Enum.concat()
    |> Enum.reduce({[], final_paths}, fn step, {next_active_paths, next_final_paths} ->
      case step do
        {:target, path} -> {next_active_paths, [path | next_final_paths]}
        {:continue, path} -> {[path | next_active_paths], next_final_paths}
      end
    end)
    |> then(fn {next_active_paths, next_final_paths} ->
      bfs_paths_ending_with_value(grid, target_value, next_active_paths, next_final_paths)
    end)
  end

  @spec parts_1_and_2() :: any()
  def parts_1_and_2() do
    grid =
      line_stream()
      |> parse_grid()

    paths_by_trailhead =
      find_all(grid, 0)
      |> Enum.map(fn point ->
        bfs_paths_ending_with_value(grid, 9, [[point]], [])
      end)

    part_1 =
      Enum.map(paths_by_trailhead, fn paths ->
        paths
        |> Stream.map(&hd/1)
        |> Enum.uniq()
        |> Enum.count()
      end)
      |> Enum.sum()

    part_2 = Enum.sum_by(paths_by_trailhead, &Enum.count/1)

    {part_1, part_2}
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

{part_1, part_2} = Main.parts_1_and_2()
IO.puts("Part 1: #{part_1}")
IO.puts("Part 2: #{part_2}")
