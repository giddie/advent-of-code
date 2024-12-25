defmodule Main do
  @moduledoc false

  @type point :: {integer(), integer()}
  @type grid :: %{bounds: point(), nodes: %{String.t() => MapSet.t()}}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_grid(Enumerable.t(String.t())) :: map()
  defp parse_grid(lines) do
    grid = %{
      bounds: {
        String.length(Enum.at(lines, 0)) - 1,
        Enum.count(lines) - 1
      },
      antennas: %{}
    }

    for {line, y} <- Enum.with_index(lines),
        {char, x} <- Enum.with_index(String.graphemes(line)),
        char != ".",
        reduce: grid do
      grid ->
        point = {x, y}

        update_in(grid.antennas, fn antennas ->
          Map.update(antennas, char, MapSet.new([point]), &MapSet.put(&1, point))
        end)
    end
  end

  @spec point_permutations(Enumerable.t(point())) :: Enumerable.t({point(), point()})
  defp point_permutations(points) do
    points
    |> Enum.to_list()
    |> Stream.unfold(fn
      [] ->
        nil

      [point_a | tail] ->
        pairs = for point_b <- tail, do: {point_a, point_b}
        {pairs, tail}
    end)
    |> Stream.concat()
  end

  @spec point_in_bounds?(point(), point()) :: boolean()
  defp point_in_bounds?({x, y}, {bounds_x, bounds_y}) do
    x in 0..bounds_x and y in 0..bounds_y
  end

  @spec part_1() :: any()
  def part_1() do
    grid =
      line_stream()
      |> parse_grid()

    for {_char, points} <- grid.antennas do
      points
      |> point_permutations()
      |> Enum.flat_map(fn {{a_x, a_y}, {b_x, b_y}} ->
        diff_x = a_x - b_x
        diff_y = a_y - b_y

        [
          {a_x + diff_x, a_y + diff_y},
          {b_x - diff_x, b_y - diff_y}
        ]
      end)
      |> Enum.filter(&point_in_bounds?(&1, grid.bounds))
    end
    |> Enum.concat()
    |> Enum.uniq()
    |> Enum.count()
  end

  @spec part_2() :: any()
  def part_2() do
    grid =
      line_stream()
      |> parse_grid()

    for {_char, points} <- grid.antennas do
      points
      |> point_permutations()
      |> Enum.flat_map(fn {{a_x, a_y}, {b_x, b_y}} ->
        diff_x = a_x - b_x
        diff_y = a_y - b_y
        gcd = Integer.gcd(diff_x, diff_y)
        step_x = div(diff_x, gcd)
        step_y = div(diff_y, gcd)

        left =
          Stream.iterate({a_x, a_y}, fn {x, y} ->
            {x - step_x, y - step_y}
          end)
          |> Enum.take_while(&point_in_bounds?(&1, grid.bounds))

        right =
          Stream.iterate({a_x, a_y}, fn {x, y} ->
            {x + step_x, y + step_y}
          end)
          |> Enum.take_while(&point_in_bounds?(&1, grid.bounds))

        left ++ right
      end)
    end
    |> Enum.concat()
    |> Enum.uniq()
    |> Enum.count()
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
