# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1        602.45        1.66 ms    ±11.47%        1.61 ms        2.33 ms
# part_2          2.82      354.62 ms     ±7.49%      345.75 ms      431.09 ms
#
# Comparison:
# part_1        602.45
# part_2          2.82 - 213.64x slower +352.96 ms
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1         0.59 MB
# part_2       301.70 MB - 513.26x memory usage +301.11 MB

defmodule Main do
  @moduledoc false

  @bounds %{x: 101, y: 103}
  @centre %{x: div(@bounds.x, 2), y: div(@bounds.y, 2)}

  @type point :: %{x: integer(), y: integer()}
  @type robot :: %{position: point(), velocity: point()}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_line(String.t()) :: robot()
  defp parse_line(line) do
    [p_x, p_y, v_x, v_y] =
      Regex.run(
        ~r/p=(.+),(.+) v=(.+),(.+)/,
        line,
        capture: :all_but_first
      )
      |> Enum.map(&String.to_integer/1)

    %{
      position: %{x: p_x, y: p_y},
      velocity: %{x: v_x, y: v_y}
    }
  end

  @spec advance_robot(robot(), point(), non_neg_integer()) :: robot()
  defp advance_robot(robot, bounds, steps) when is_integer(steps) and steps >= 0 do
    new_x = (robot.position.x + steps * robot.velocity.x) |> Integer.mod(bounds.x)
    new_y = (robot.position.y + steps * robot.velocity.y) |> Integer.mod(bounds.y)
    Map.put(robot, :position, %{x: new_x, y: new_y})
  end

  @spec robots_to_string([robot()], point(), point()) :: [robot()]
  defp robots_to_string(robots, bounds, offset) do
    grouped = Enum.group_by(robots, &Map.fetch!(&1, :position))

    char_at_point = fn point ->
      case Map.get(grouped, point, []) do
        [] -> "."
        robots -> Enum.count(robots) |> Integer.to_string()
      end
    end

    y1 = offset.y
    y2 = offset.y + bounds.y - 1
    x1 = offset.x
    x2 = offset.x + bounds.x - 1

    for y <- y1..y2 do
      for x <- x1..x2, into: "" do
        char_at_point.(%{x: x, y: y})
      end
    end
    |> Enum.join("\n")
  end

  @spec part_1() :: any()
  def part_1() do
    line_stream()
    |> Enum.map(&parse_line/1)
    |> Enum.map(&advance_robot(&1, @bounds, 100))
    |> Enum.group_by(fn robot ->
      vertical =
        cond do
          robot.position.y < @centre.y -> :top
          robot.position.y > @centre.y -> :bottom
          true -> :centre
        end

      horizontal =
        cond do
          robot.position.x < @centre.x -> :left
          robot.position.x > @centre.x -> :right
          true -> :centre
        end

      {vertical, horizontal}
    end)
    |> Enum.flat_map(fn {{vertical, horizontal}, robots} ->
      if :centre in [vertical, horizontal] do
        []
      else
        [Enum.count(robots)]
      end
    end)
    |> Enum.reduce(&*/2)
  end

  @spec part_2() :: any()
  def part_2() do
    line_stream()
    |> Enum.map(&parse_line/1)
    |> Stream.iterate(fn robots ->
      Enum.map(robots, &advance_robot(&1, @bounds, 1))
    end)
    |> Stream.with_index()
    |> Stream.flat_map(fn {robots, index} ->
      robots
      |> Enum.filter(&(&1.position.y == 42 && &1.position.x in 34..64))
      |> Enum.count()
      |> then(fn count ->
        if count == 31 do
          robots_to_string(robots, %{x: 31, y: 33}, %{x: 34, y: 42})
          |> IO.puts()

          [index]
        else
          []
        end
      end)
    end)
    |> Enum.at(0)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
