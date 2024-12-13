defmodule Main do
  @moduledoc false

  @type point :: %{y: integer(), x: integer()}

  @fence_deltas [{-1, 0}, {1, 0}, {0, -1}, {0, 1}]

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_grid(Enumerable.t()) :: map()
  defp parse_grid(lines) do
    for {line, y} <- Enum.with_index(lines),
        {char, x} <- Enum.with_index(String.graphemes(line)),
        into: %{} do
      {%{y: y, x: x}, char}
    end
  end

  @spec root(point(), map()) :: point()
  defp root(point, parents) do
    case Map.fetch(parents, point) do
      {:ok, ^point} -> point
      {:ok, parent} -> root(parent, parents)
      :error -> point
    end
  end

  @spec unify(map(), point(), point()) :: map()
  defp unify(parents, left, right) do
    Map.put(parents, root(left, parents), root(right, parents))
  end

  @spec add_in(map(), any(), any()) :: map()
  defp add_in(map, key, value) do
    Map.update(map, key, [value], &[value | &1])
  end

  @spec parents_and_fences(map()) :: {map(), map()}
  defp parents_and_fences(grid) do
    for {point, char} <- grid,
        {y_delta, x_delta} = fence_delta <- @fence_deltas,
        reduce: {%{}, %{}} do
      {parents, fences} ->
        neighbour = %{y: point.y + y_delta, x: point.x + x_delta}

        case Map.fetch(grid, neighbour) do
          {:ok, ^char} -> {unify(parents, point, neighbour), fences}
          {:ok, _other} -> {parents, add_in(fences, point, fence_delta)}
          :error -> {parents, add_in(fences, point, fence_delta)}
        end
    end
  end

  @spec part_1() :: any()
  def part_1() do
    grid = parse_grid(line_stream())
    {parents, fences} = parents_and_fences(grid)

    for {point, _char} <- grid do
      fence_count = Map.get(fences, point, []) |> Enum.count()
      {root(point, parents), fence_count}
    end
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {_root, fence_counts} ->
      Enum.count(fence_counts) * Enum.sum(fence_counts)
    end)
    |> Enum.sum()
  end

  @spec part_2() :: any()
  def part_2() do
    grid = parse_grid(line_stream())
    {parents, fences} = parents_and_fences(grid)

    for {point, _char} <- grid do
      root = root(point, parents)
      fences = Map.get(fences, point, [])

      for fence <- fences do
        case fence do
          {0, side} -> [:x, point.x, side, point.y]
          {side, 0} -> [:y, point.y, side, point.x]
        end
      end
      |> then(&{root, &1})
    end
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {_root, fence_lists} ->
      fence_lists
      |> Enum.concat()
      |> Enum.group_by(&Enum.slice(&1, 0..2), &Enum.at(&1, 3))
      |> Enum.map(fn {_fence_line, indexes} ->
        [first | tail] = Enum.sort(indexes)

        Enum.chunk_while(
          tail,
          [first],
          fn current, [previous | _] = chunk ->
            if current > previous + 1 do
              {:cont, chunk, [current]}
            else
              {:cont, [current | chunk]}
            end
          end,
          fn chunk -> {:cont, chunk, []} end
        )
        |> Enum.count()
      end)
      |> Enum.sum()
      |> then(fn sides ->
        area = Enum.count(fence_lists)
        sides * area
      end)
    end)
    |> Enum.sum()
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
