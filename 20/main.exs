# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1         60.32       16.58 ms     ±9.46%       16.21 ms       22.77 ms
# part_2         35.13       28.47 ms     ±5.00%       28.07 ms       35.97 ms
#
# Comparison:
# part_1         60.32
# part_2         35.13 - 1.72x slower +11.89 ms

Mix.install([:nx, :exla])

Application.put_env(:exla, :default_client, :host)
Nx.global_default_backend(EXLA.Backend)
Nx.Defn.global_default_options(compiler: EXLA)

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

defmodule Main do
  @moduledoc false

  import Nx.Defn

  @spec read_lines() :: Nx.Tensor.t()
  defp read_lines() do
    binary_lines = File.read!("input")

    width =
      Stream.unfold(binary_lines, fn <<c, tail::bitstring>> -> {c, tail} end)
      |> Stream.take_while(&(&1 != ?\n))
      |> Enum.count()
      |> then(&(&1 + 1))

    lines = Nx.from_binary(binary_lines, :u8)
    height = div(Nx.size(lines), width)

    shape_grid(lines, width: width, height: height)
  end

  defnp shape_grid(lines, opts \\ []) do
    assert_keys(opts, [:width, :height])
    width = opts[:width]
    height = opts[:height]

    lines
    |> Nx.reshape({height, width})
    |> Nx.vectorize(:lines)
    |> Nx.slice([0], [width - 1])
    |> Nx.devectorize()
  end

  defnp find_coords_of_value(lines, coords, point_value) do
    Nx.equal(lines, point_value)
    |> Nx.vectorize([:y, :x])
    |> Nx.broadcast({2})
    |> Nx.devectorize()
    |> Nx.select(coords, 0)
    |> Nx.flatten(axes: [:y, :x])
    |> Nx.transpose()
    |> Nx.vectorize(:axes)
    |> Nx.sum()
    |> Nx.devectorize()
  end

  @spec parse_grid(Nx.Tensor.t()) :: Nx.Tensor.t()
  defnp parse_grid(lines) do
    {height, width} = Nx.shape(lines)

    y_coords =
      Nx.iota({height})
      |> Nx.new_axis(-1)
      |> Nx.broadcast({height, width})

    x_coords =
      Nx.iota({width})
      |> Nx.new_axis(0)
      |> Nx.broadcast({height, width})

    coords = Nx.stack([y_coords, x_coords], axis: -1)

    start_point = find_coords_of_value(lines, coords, ?S)
    end_point = find_coords_of_value(lines, coords, ?E)

    path_points =
      Nx.equal(lines, ?.)
      |> Nx.indexed_put(
        Nx.stack([start_point, end_point]),
        Nx.broadcast(1, {2})
      )

    {coords, path_points, start_point, end_point}
  end

  defnp path_distances(path_points, start_point, end_point) do
    while {
            distance = 0,
            point = end_point,
            path_distances = Nx.broadcast(-1, path_points),
            path_points,
            start_point
          },
          not Nx.all(point == start_point) do
      neighbours = point + Nx.tensor([[-1, 0], [1, 0], [0, -1], [0, 1]])

      next_point =
        Nx.gather(path_points, neighbours)
        |> Nx.vectorize(:select)
        |> Nx.broadcast({2})
        |> Nx.devectorize()
        |> Nx.select(neighbours, 0)
        |> Nx.transpose()
        |> Nx.vectorize(:axes)
        |> Nx.sum()
        |> Nx.devectorize()

      path_points = Nx.indexed_put(path_points, point, Nx.tensor(0, type: :u8))

      {
        distance + 1,
        next_point,
        Nx.indexed_put(path_distances, point, distance),
        path_points,
        start_point
      }
    end
    |> then(fn {distance, point, path_distances, _start_point, _end_point} ->
      Nx.indexed_put(path_distances, point, distance)
    end)
  end

  defnp manhattan_distance_diamond(opts \\ []) do
    assert_keys(opts, [:max_length])
    max_length = opts[:max_length]

    iota_y = Nx.iota({max_length, 1}, type: :s8)
    iota_x = Nx.iota({1, max_length}, type: :s8)

    y_coords = Nx.max(iota_y - max_length, iota_x - max_length)
    x_coords = iota_x - iota_y

    upper_triangle = Nx.stack([y_coords, x_coords], axis: 2)
    lower_triangle = Nx.stack([-y_coords, x_coords], axis: 2)

    middle =
      Nx.stack(
        [
          Nx.broadcast(Nx.tensor(0, type: :s8), {max_length * 2}),
          Nx.concatenate([
            Nx.iota({max_length}, type: :s8) - max_length,
            Nx.iota({max_length}, type: :s8) + 1
          ])
        ],
        axis: 1
      )

    triangles =
      Nx.concatenate([upper_triangle, lower_triangle])
      |> Nx.reshape({:auto, 2})

    Nx.concatenate([triangles, middle])
  end

  defnp count_cheats({coords, path_points, start_point, end_point}, opts \\ []) do
    path_distances = path_distances(path_points, start_point, end_point)
    manhattan_distance_diamond = manhattan_distance_diamond(opts)

    manhattan_distances =
      manhattan_distance_diamond
      |> Nx.abs()
      |> Nx.vectorize(:manhattan_distance)
      |> Nx.sum()
      |> Nx.devectorize()

    path_coords =
      path_points
      |> Nx.vectorize([:y, :x])
      |> Nx.broadcast({2})
      |> Nx.devectorize()
      |> Nx.select(coords, -1)
      |> Nx.reshape({:auto, 2})

    cheat_scores =
      path_coords
      |> Nx.vectorize(:points)
      |> Nx.add(manhattan_distance_diamond)
      |> then(&Nx.gather(path_distances, &1))
      |> Nx.subtract(
        path_distances
        |> Nx.flatten()
        |> Nx.vectorize(:points)
        |> Nx.broadcast(manhattan_distances)
      )
      |> Nx.subtract(manhattan_distances)

    path_points
    |> Nx.flatten()
    |> Nx.vectorize(:points)
    |> Nx.broadcast(manhattan_distances)
    |> Nx.select(cheat_scores, 0)
    |> Nx.greater_equal(100)
    |> Nx.devectorize()
    |> Nx.sum()
  end

  @spec part_1() :: any()
  def part_1() do
    read_lines()
    |> parse_grid()
    |> count_cheats(max_length: 2)
    |> Nx.to_number()
  end

  @spec part_2() :: any()
  def part_2() do
    read_lines()
    |> parse_grid()
    |> count_cheats(max_length: 20)
    |> Nx.to_number()
  end
end

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
