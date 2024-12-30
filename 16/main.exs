# Benchmarks
#
# Name                    ips        average  deviation         median         99th %
# parts_1_and_2          3.76      266.23 ms     ±9.45%      261.62 ms      354.81 ms
#
# Memory usage statistics:
#
# Name             Memory usage
# parts_1_and_2       418.55 MB

defmodule Main do
  @moduledoc false

  @type point :: {integer(), integer()}
  @type grid :: %{point() => String.t()}
  @type graph :: map()

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_grid([String.t()]) :: grid()
  defp parse_grid(lines) do
    lines = Enum.to_list(lines)

    bounds = {
      String.length(Enum.at(lines, 0)),
      Enum.count(lines)
    }

    for {line, y} <- Enum.with_index(lines),
        {char, x} <- Enum.with_index(String.graphemes(line)),
        reduce: %{
          squares: MapSet.new(),
          bounds: bounds
        } do
      acc ->
        acc =
          if char in [".", "S", "E"] do
            Map.update!(acc, :squares, &MapSet.put(&1, {x, y}))
          else
            acc
          end

        case char do
          "S" -> Map.put(acc, :start, {x, y})
          "E" -> Map.put(acc, :end, {x, y})
          _ -> acc
        end
    end
  end

  @spec add_points(point(), point()) :: point()
  defp add_points({left_x, left_y}, {right_x, right_y}) do
    {
      left_x + right_x,
      left_y + right_y
    }
  end

  @spec build_graph(grid()) :: graph()
  defp build_graph(grid) do
    {bounds_x, bounds_y} = grid.bounds

    add_edge = fn graph, node_a, node_b, weight ->
      graph
      |> Map.update(node_a, %{node_b => weight}, &Map.put(&1, node_b, weight))
      |> Map.update(node_b, %{node_a => weight}, &Map.put(&1, node_a, weight))
    end

    graph =
      %{}
      |> add_edge.(:start, {grid.start, :right}, 0)
      |> add_edge.(:end, {grid.end, :top}, 0)
      |> add_edge.(:end, {grid.end, :right}, 0)
      |> add_edge.(:end, {grid.end, :bottom}, 0)
      |> add_edge.(:end, {grid.end, :left}, 0)

    for y <- 0..(bounds_y - 1),
        x <- 0..(bounds_x - 1),
        reduce: graph do
      acc ->
        point = {x, y}

        if point in grid.squares do
          acc =
            acc
            |> add_edge.({point, :left}, {point, :right}, 1)
            |> add_edge.({point, :top}, {point, :bottom}, 1)
            |> add_edge.({point, :top}, {point, :right}, 1001)
            |> add_edge.({point, :right}, {point, :bottom}, 1001)
            |> add_edge.({point, :bottom}, {point, :left}, 1001)
            |> add_edge.({point, :left}, {point, :top}, 1001)

          [
            {{1, 0}, {:right, :left}},
            {{0, 1}, {:bottom, :top}}
          ]
          |> Enum.reduce(acc, fn {neighbour_direction, {point_side, neighbour_side}}, acc ->
            neighbour = add_points(point, neighbour_direction)

            if neighbour in grid.squares do
              add_edge.(acc, {point, point_side}, {neighbour, neighbour_side}, 0)
            else
              acc
            end
          end)
        else
          acc
        end
    end
  end

  @spec shortest_paths(graph(), point(), point()) ::
          {:some, {[point()], non_neg_integer()}} | :none
  defp shortest_paths(graph, from, to) do
    Stream.resource(
      fn ->
        %{
          graph: graph,
          queue: [{from, 0}],
          paths: %{from => {[[]], 0}},
          visited: MapSet.new()
        }
      end,
      fn
        :finished ->
          {:halt, :finished}

        %{queue: []} ->
          {:halt, :none}

        %{queue: [{^to, cost} | _]} = acc ->
          {paths, ^cost} = Map.fetch!(acc.paths, to)
          paths = Enum.map(paths, &Enum.reverse(&1))
          {[{paths, cost}], :finished}

        %{queue: [{node, _node_cost} | queue_tail]} = acc ->
          acc = %{acc | queue: queue_tail}

          if node in acc.visited do
            acc
          else
            acc = Map.update!(acc, :visited, &MapSet.put(&1, node))

            {node_paths, node_cost} = Map.fetch!(acc.paths, node)
            node_paths = Enum.map(node_paths, &[node | &1])

            for {neighbour_node, edge_cost} <- Map.get(graph, node, %{}),
                neighbour_node not in acc.visited,
                reduce: acc do
              acc ->
                cost_through_node = node_cost + edge_cost

                action =
                  case Map.fetch(acc.paths, neighbour_node) do
                    :error ->
                      :replace

                    {:ok, {_path, neighbour_cost}} ->
                      cond do
                        cost_through_node < neighbour_cost -> :replace
                        cost_through_node == neighbour_cost -> :add_alternative
                        true -> :nothing
                      end
                  end

                case action do
                  :replace ->
                    acc
                    |> put_in(
                      [:paths, neighbour_node],
                      {node_paths, cost_through_node}
                    )
                    |> update_in([:queue], fn queue ->
                      {left, right} =
                        Enum.split_while(queue, fn {_point, cost} ->
                          cost < cost_through_node
                        end)

                      left ++ [{neighbour_node, cost_through_node} | right]
                    end)

                  :add_alternative ->
                    update_in(acc.paths[neighbour_node], fn {paths, cost} ->
                      {node_paths ++ paths, cost}
                    end)

                  :nothing ->
                    acc
                end
            end
          end
          |> then(&{[], &1})
      end,
      & &1
    )
    |> Enum.to_list()
    |> then(fn
      [] -> :none
      [value] -> {:some, value}
    end)
  end

  @spec parts_1_and_2() :: any()
  def parts_1_and_2() do
    line_stream()
    |> parse_grid()
    |> build_graph()
    |> shortest_paths(:start, :end)
    |> then(fn {:some, {paths, cost}} ->
      part_1 = cost

      part_2 =
        for path <- paths, {node, _side} <- path, uniq: true do
          node
        end
        |> Enum.count()

      {part_1, part_2}
    end)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

{part_1, part_2} = Main.parts_1_and_2()
IO.puts("Part 1: #{part_1}")
IO.puts("Part 2: #{part_2}")
