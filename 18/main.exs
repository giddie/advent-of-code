# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1        146.04        6.85 ms    ±39.77%        6.27 ms       11.88 ms
# part_2          4.56      219.41 ms    ±11.04%      218.06 ms      278.05 ms
#
# Comparison:
# part_1        146.04
# part_2          4.56 - 32.04x slower +212.56 ms
#
# Memory usage statistics:
#
# Name           average  deviation         median         99th %
# part_1         4.64 MB
# part_2       137.83 MB - 29.71x memory usage +133.19 MB

defmodule Main do
  @moduledoc false

  # @input %{
  #   file: "example",
  #   bounds: {6, 6},
  #   num_bytes: 12
  # }

  @input %{
    file: "input",
    bounds: {70, 70},
    num_bytes: 1024
  }

  @bounds_x elem(@input.bounds, 0)
  @bounds_y elem(@input.bounds, 1)

  @type point :: {non_neg_integer(), non_neg_integer()}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!(@input.file)
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  # @spec path_to_string(MapSet.t(point()), point()) :: String.t()
  # defp path_to_string(path, byte_points) do
  #   for y <- 0..@bounds_y do
  #     for x <- 0..@bounds_x, into: "" do
  #       point = {x, y}
  #
  #       cond do
  #         point in byte_points -> "#"
  #         point in path -> "O"
  #         true -> "."
  #       end
  #     end
  #   end
  #   |> Enum.join("\n")
  # end

  @spec path_to(MapSet.t(point()), point(), map(), MapSet.t()) :: :none | {:some, [point()]}
  defp path_to(byte_points, target, priority_queue, visited) do
    Enum.flat_map_reduce(
      priority_queue,
      {:not_found, visited},
      fn [{x, y} = point | _] = path, {:not_found, visited} ->
        cond do
          point == target ->
            {:halt, {:found, path}}

          point in visited ->
            {[], {:not_found, visited}}

          true ->
            visited = MapSet.put(visited, point)

            priority_queue =
              for {x_delta, y_delta} <- [{-1, 0}, {1, 0}, {0, -1}, {0, 1}],
                  {neighbour_x, neighbour_y} = neighbour = {x + x_delta, y + y_delta},
                  neighbour_x in 0..@bounds_x,
                  neighbour_y in 0..@bounds_y,
                  neighbour not in visited,
                  neighbour not in byte_points do
                [neighbour | path]
              end

            {priority_queue, {:not_found, visited}}
        end
      end
    )
    |> then(fn
      {[], {:not_found, _visited}} ->
        :none

      {priority_queue, {:not_found, visited}} ->
        path_to(byte_points, target, priority_queue, visited)

      {_priority_queue, {:found, path}} ->
        {:some, path}
    end)
  end

  @spec final_block_point(MapSet.t(point()), [point()], block_point) :: block_point
        when block_point: :none | {:some, point()}
  defp final_block_point(fallen_byte_points, remaining_byte_points, current_block_point \\ :none) do
    case path_to(fallen_byte_points, @input.bounds, [[{0, 0}]], MapSet.new()) do
      :none ->
        current_block_point

      {:some, path} ->
        case Enum.split_while(remaining_byte_points, &(&1 not in path)) do
          {_left, []} ->
            current_block_point

          {left, [point | right]} ->
            for byte_point <- [point | left], reduce: fallen_byte_points do
              acc -> MapSet.put(acc, byte_point)
            end
            |> final_block_point(right, {:some, point})
        end
    end
  end

  @spec part_1() :: any()
  def part_1() do
    byte_points =
      line_stream()
      |> Stream.map(fn line ->
        String.split(line, ",")
        |> Enum.map(&String.to_integer/1)
        |> List.to_tuple()
      end)
      |> Enum.take(@input.num_bytes)
      |> Enum.reduce(MapSet.new(), fn byte_point, acc ->
        MapSet.put(acc, byte_point)
      end)

    byte_points
    |> path_to(@input.bounds, [[{0, 0}]], MapSet.new())
    |> then(fn {:some, path} ->
      Enum.count(path) - 1
    end)
  end

  @spec part_2() :: any()
  def part_2() do
    byte_points =
      line_stream()
      |> Enum.map(fn line ->
        String.split(line, ",")
        |> Enum.map(&String.to_integer/1)
        |> List.to_tuple()
      end)

    {left, right} = Enum.split(byte_points, @input.num_bytes)

    for byte_point <- left, reduce: MapSet.new() do
      acc -> MapSet.put(acc, byte_point)
    end
    |> final_block_point(right)
    |> then(fn {:some, point} ->
      Tuple.to_list(point) |> Enum.join(",")
    end)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
