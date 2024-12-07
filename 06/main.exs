defmodule Main do
  @moduledoc false

  @type point :: %{x: non_neg_integer(), y: non_neg_integer()}
  @type direction :: :up | :down | :left | :right

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec walk(point(), direction(), map(), [point()]) :: [point()]
  defp walk(guard, direction, %{} = map, history \\ []) do
    next_history = [guard | history]

    {filter_axis, {sort_axis, sort_order}, new_direction} =
      case direction do
        :up -> {:x, {:y, :desc}, :right}
        :right -> {:y, {:x, :asc}, :down}
        :down -> {:x, {:y, :asc}, :left}
        :left -> {:y, {:x, :desc}, :up}
      end

    map.obstacles
    |> Enum.filter(fn obstacle ->
      on_same_axis? = Map.fetch!(obstacle, filter_axis) == Map.fetch!(guard, filter_axis)
      sort_axis_operator = if sort_order == :asc, do: &>/2, else: &</2

      in_front_of_guard? =
        sort_axis_operator.(
          Map.fetch!(obstacle, sort_axis),
          Map.fetch!(guard, sort_axis)
        )

      on_same_axis? && in_front_of_guard?
    end)
    |> Enum.sort_by(&Map.fetch!(&1, sort_axis), sort_order)
    |> case do
      [obstacle | _] ->
        offset = if sort_order == :asc, do: -1, else: 1

        %{
          filter_axis => Map.fetch!(obstacle, filter_axis),
          sort_axis => Map.fetch!(obstacle, sort_axis) + offset
        }
        |> walk(new_direction, map, next_history)

      [] ->
        final_position = %{guard | sort_axis => Map.fetch!(map.bounds, sort_axis)}
        Enum.reverse([final_position | next_history])
    end
  end

  @spec part_1() :: any()
  def part_1() do
    lines = Enum.to_list(line_stream())

    map =
      for {line, y} <- Enum.with_index(lines),
          {char, x} <- Enum.with_index(String.graphemes(line)),
          reduce: %{} do
        acc ->
          point = %{x: x, y: y}

          type =
            case char do
              "#" -> {:some, :obstacles}
              "^" -> {:some, :guards}
              _ -> :none
            end

          case type do
            {:some, key} -> Map.update(acc, key, [point], &[point | &1])
            :none -> acc
          end
      end
      |> Map.put(:bounds, %{
        y: Enum.count(lines) - 1,
        x: String.length(Enum.at(lines, 0)) - 1
      })

    [%{} = guard] = map.guards

    [first_point | points] = walk(guard, :up, map)

    Enum.reduce(
      points,
      {first_point, []},
      fn point, {prev_point, covered_points} ->
        for x <- prev_point.x..point.x,
            y <- prev_point.y..point.y do
          %{x: x, y: y}
        end
        |> then(&[&1 | covered_points])
        |> then(&{point, &1})
      end
    )
    |> then(fn {_prev_point, covered_points} -> covered_points end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.count()
  end

  @spec part_2() :: any()
  def part_2() do
    ""
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
