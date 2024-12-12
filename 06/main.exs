defmodule Main do
  @moduledoc false

  @type point :: %{x: non_neg_integer(), y: non_neg_integer()}
  @type direction :: :up | :down | :left | :right
  @type intention :: :leaving_map | {:turn, direction()} | :loop
  @type state :: {point(), intention()}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_map(Stream.t(String.t())) :: map()
  defp parse_map(line_stream) do
    lines = Enum.to_list(line_stream)

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
      y: Enum.count(lines),
      x: String.length(Enum.at(lines, 0))
    })
  end

  # Returns a point representing the new position of the guard after they've walked in the given
  # direction, and the new direction they are now facing.
  @spec next_guard_position(point(), direction(), map()) :: state()
  defp next_guard_position(guard, direction, %{} = map) do
    {filter_axis, {sort_axis, sort_order}, next_direction} =
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
    |> then(fn
      [] ->
        case sort_order do
          :asc -> map.bounds
          :desc -> %{y: -1, x: -1}
        end
        |> then(&{&1, :leaving_map})

      obstacles ->
        sorter = if sort_order == :asc, do: &<=/2, else: &>=/2

        obstacles
        |> Enum.min_by(&Map.fetch!(&1, sort_axis), sorter)
        |> then(&{&1, {:turn, next_direction}})
    end)
    |> then(fn {obstacle, intention} ->
      offset = if sort_order == :asc, do: -1, else: 1

      next_guard_position = %{
        filter_axis => Map.fetch!(guard, filter_axis),
        sort_axis => Map.fetch!(obstacle, sort_axis) + offset
      }

      {next_guard_position, intention}
    end)
  end

  @spec guard_path(map()) :: [state()]
  defp guard_path(%{guards: [%{} = guard]} = map) do
    Stream.unfold(
      [{guard, {:turn, :up}}],
      fn
        :done ->
          nil

        {:final, state} ->
          {state, :done}

        [{guard, {:turn, direction}} = state | _] = history ->
          case next_guard_position(guard, direction, map) do
            {_point, :leaving_map} = final_state ->
              {state, {:final, final_state}}

            {guard, _intention} = next_state ->
              if next_state in history do
                {state, {:final, {guard, :loop}}}
              else
                {state, [next_state | history]}
              end
          end
      end
    )
    |> Enum.to_list()
  end

  @spec interpolate_points([state()]) :: [point()]
  defp interpolate_points([{first_point, _intention} | _] = points) do
    points
    |> Enum.map(fn {point, _direction} -> point end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [start_point, end_point] ->
      for y <- start_point.y..end_point.y,
          x <- start_point.x..end_point.x do
        %{y: y, x: x}
      end
      |> Enum.drop(1)
    end)
    |> then(&[first_point | &1])
  end

  @spec part_1() :: any()
  def part_1() do
    line_stream()
    |> parse_map()
    |> guard_path()
    |> interpolate_points()
    |> Enum.uniq()
    |> Enum.count()
  end

  @spec part_2() :: any()
  def part_2() do
    map = line_stream() |> parse_map()

    map
    |> guard_path()
    |> interpolate_points()
    |> Enum.drop(1)
    |> Task.async_stream(fn new_obstacle_point ->
      map.obstacles
      |> update_in(&[new_obstacle_point | &1])
      |> guard_path()
      |> Enum.at(-1)
      |> then(fn
         {_point, :leaving_map} -> []
         {_point, :loop} -> [new_obstacle_point]
      end)
    end)
    |> Stream.flat_map(fn {:ok, value} -> value end)
    |> Enum.uniq()
    |> Enum.count()
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
