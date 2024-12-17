defmodule Main do
  @moduledoc false

  @debug "--debug" in System.argv()
  if @debug do
    @step "--step" in System.argv()
  end

  @type point :: {integer(), integer()}

  defmacrop debug_log(data) do
    if @debug do
      quote do
        output = unquote(data)

        if is_binary(output) do
          IO.puts(output)
        else
          IO.inspect(output)
        end

        output
      end
    end
  end

  defmacrop debug_log(data, transform_func) do
    quote do
      unquote(data)
      |> debug_pipe(fn output ->
        tap(output, fn output ->
          debug_log(unquote(transform_func).(output))
        end)
      end)
    end
  end

  defmacrop debug_pipe(left, func) do
    if @debug do
      quote do
        unquote(left) |> unquote(func).()
      end
    else
      left
    end
  end

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  if @debug do
    @spec map_to_string(map(), point()) :: :ok
    defp map_to_string(points, {bounds_x, bounds_y}) do
      for y <- 0..(bounds_y - 1) do
        for x <- 0..(bounds_x - 1), into: "" do
          point = {x, y}

          cond do
            Map.has_key?(points.walls, point) ->
              "#"

            Map.has_key?(points.boxes, point) ->
              case points.boxes[point] do
                [^point] -> "O"
                [^point, _] -> "["
                [_, ^point] -> "]"
              end

            Map.has_key?(points.robots, point) ->
              "@"

            true ->
              "."
          end
        end
      end
      |> Enum.join("\n")
    end
  end

  @spec add_points(point(), point()) :: point()
  defp add_points({left_x, left_y}, {right_x, right_y}) do
    {
      left_x + right_x,
      left_y + right_y
    }
  end

  @spec push_box(map(), point(), point()) :: {:moved, map()} | :blocked
  defp push_box(points, box, delta) do
    box_points = Map.fetch!(points.boxes, box)

    targets_condition =
      for box_point <- box_points, reduce: {:ok, points} do
        {:ok, acc_points} ->
          target = add_points(box_point, delta)

          cond do
            target in box_points ->
              {:ok, acc_points}

            Map.has_key?(acc_points.walls, target) ->
              :blocked

            Map.has_key?(acc_points.boxes, target) ->
              with {:moved, acc_points} <- push_box(acc_points, target, delta) do
                {:ok, acc_points}
              end

            true ->
              {:ok, acc_points}
          end

        :blocked ->
          :blocked
      end

    with {:ok, points} <- targets_condition do
      Map.update!(points, :boxes, fn boxes ->
        new_box_points = Enum.map(box_points, &add_points(&1, delta))
        boxes = Map.drop(boxes, box_points)

        for point <- new_box_points, reduce: boxes do
          acc -> Map.put(acc, point, new_box_points)
        end
      end)
      |> then(&{:moved, &1})
    end
  end

  @spec apply_move(map(), String.t()) :: map()
  defp apply_move(points, move) do
    [{robot, [robot]}] = Enum.to_list(points.robots)

    delta =
      case move do
        "^" -> {0, -1}
        "v" -> {0, 1}
        "<" -> {-1, 0}
        ">" -> {1, 0}
      end

    target = add_points(robot, delta)

    target_condition =
      cond do
        Map.has_key?(points.walls, target) ->
          points

        Map.has_key?(points.boxes, target) ->
          case push_box(points, target, delta) do
            {:moved, points} -> {:vacant, points}
            :blocked -> points
          end

        true ->
          {:vacant, points}
      end

    with {:vacant, points} <- target_condition do
      Map.update!(points, :robots, fn robots ->
        robots
        |> Map.delete(robot)
        |> Map.put(target, [target])
      end)
    end
  end

  @spec parse_input() :: any()
  defp parse_input() do
    [map, [""], moves] = line_stream() |> Enum.chunk_by(&(String.length(&1) == 0))
    {map, moves}
  end

  @spec parse_map([String.t()]) :: map()
  defp parse_map(map) do
    bounds = {
      String.length(Enum.at(map, 0)),
      Enum.count(map)
    }

    left_of = &add_points(&1, {-1, 0})
    right_of = &add_points(&1, {1, 0})

    points =
      for {line, y} <- Enum.with_index(map),
          {char, x} <- Enum.with_index(String.graphemes(line)),
          reduce: %{} do
        acc ->
          point = {x, y}

          case char do
            "#" -> {:walls, [point]}
            "O" -> {:boxes, [point]}
            "[" -> {:boxes, [point, right_of.(point)]}
            "]" -> {:boxes, [left_of.(point), point]}
            "@" -> {:robots, [point]}
            "." -> {:empty, []}
          end
          |> then(fn
            {:empty, []} ->
              acc

            {type, points} ->
              Map.update(acc, type, %{point => points}, &Map.put(&1, point, points))
          end)
      end

    {points, bounds}
  end

  @spec expand_map([String.t()]) :: [String.t()]
  defp expand_map(map) do
    for line <- map do
      for char <- String.graphemes(line), into: "" do
        case char do
          "#" -> "##"
          "." -> ".."
          "O" -> "[]"
          "@" -> "@."
        end
      end
    end
  end

  @spec apply_moves(map(), String.t(), point()) :: map()
  defp apply_moves(points, moves, bounds) do
    # Silence unused variable warning
    not @debug and bounds

    moves
    |> Enum.join()
    |> String.graphemes()
    |> debug_pipe(fn data ->
      data
      |> Stream.with_index()
      |> Stream.map(fn {move, index} ->
        if @step, do: IO.gets("")
        debug_log("\n#{index} #{move}")
        move
      end)
    end)
    |> Enum.reduce(points, fn move, points ->
      apply_move(points, move)
      |> debug_log(&map_to_string(&1, bounds))
    end)
  end

  @spec gps_sum(map()) :: non_neg_integer()
  defp gps_sum(points) do
    for {{x, y}, [{x, y} | _]} <- points.boxes, reduce: 0 do
      acc -> acc + (y * 100 + x)
    end
  end

  @spec part_1() :: any()
  def part_1() do
    {map, moves} = parse_input()
    {points, bounds} = parse_map(map)

    debug_log(map_to_string(points, bounds))

    points
    |> apply_moves(moves, bounds)
    |> gps_sum()
  end

  @spec part_2() :: any()
  def part_2() do
    {map, moves} = parse_input()
    {points, bounds} = map |> expand_map() |> parse_map()

    debug_log(map_to_string(points, bounds))

    points
    |> apply_moves(moves, bounds)
    |> gps_sum()
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
