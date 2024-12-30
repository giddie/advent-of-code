# Benchmarks
#
# Name              ips        average  deviation         median         99th %
# part_1           6.36      157.34 ms    ±15.44%      151.08 ms      277.76 ms
# part_2a          6.03      165.91 ms    ±15.32%      160.80 ms      301.73 ms
# part_2b          7.09      141.03 ms    ±11.85%      138.24 ms      237.26 ms
#
# Comparison:
# part_1           6.36 - 1.12x slower +16.31 ms
# part_2a          6.03 - 1.18x slower +24.88 ms
# part_2b          7.09
#
# Memory usage statistics:
#
# Name            average  deviation         median         99th %
# part_1        553.19 MB - 3.40x memory usage +390.72 MB
# part_2a       555.81 MB - 3.42x memory usage +393.34 MB
# part_2b       162.47 MB

defmodule Main do
  @moduledoc false

  @type grid :: [String.t()]

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec line_xmas_count(String.t()) :: non_neg_integer()
  defp line_xmas_count(line) when is_binary(line) do
    splits = String.split(line, "XMAS")
    Enum.count(splits) - 1
  end

  @spec xmas_count(grid()) :: non_neg_integer()
  defp xmas_count(lines) when is_list(lines) do
    lines
    |> Enum.map(&line_xmas_count/1)
    |> Enum.sum()
  end

  @spec reversed(grid()) :: grid()
  defp reversed(lines) when is_list(lines) do
    Enum.map(lines, &String.reverse/1)
  end

  @spec vertical(grid()) :: grid()
  defp vertical(lines) when is_list(lines) do
    lines
    |> Enum.map(&String.graphemes/1)
    |> Enum.zip_with(&Enum.join/1)
  end

  @spec diagonals(grid()) :: grid()
  defp diagonals([first_line | _rest] = lines) do
    x_count = String.length(first_line)
    y_count = Enum.count(lines)

    num_diagonals = x_count + y_count - 1

    for target_line_index <- 0..(num_diagonals - 1) do
      slice_indexes = Enum.to_list(target_line_index..0//-1)
      lines_in_diagonal = Enum.take(lines, target_line_index + 1)

      for {slice_index, line} <- Enum.zip(slice_indexes, lines_in_diagonal), into: "" do
        String.slice(line, slice_index, 1)
      end
    end
  end

  @spec indexes_of(String.t(), String.t(), non_neg_integer()) :: [non_neg_integer()]
  defp indexes_of(string, search_string, offset \\ 0)

  defp indexes_of("", _search_string, _offset), do: []

  defp indexes_of(string, search_string, offset)
       when is_binary(string) and is_binary(search_string) do
    case string do
      ^search_string <> rest ->
        [offset | indexes_of(rest, search_string, offset + String.length(search_string))]

      string ->
        indexes_of(String.slice(string, 1..-1//1), search_string, offset + 1)
    end
  end

  @spec xmas_squares_to_right(grid()) :: [grid()]
  defp xmas_squares_to_right(
         [
           <<a::binary-size(1), b::binary-size(1), <<c::binary-size(1)>>, _rest_1::binary>>,
           <<d::binary-size(1), e::binary-size(1), <<f::binary-size(1)>>, _rest_2::binary>>,
           <<g::binary-size(1), h::binary-size(1), <<i::binary-size(1)>>, _rest_3::binary>>
           | _lines_below
         ] = lines
       ) do
    words = [
      a <> e <> i,
      c <> e <> g
    ]

    squares =
      if Enum.all?(words, &(&1 in ["MAS", "SAM"])) do
        square = [
          a <> b <> c,
          d <> e <> f,
          g <> h <> i
        ]

        [square]
      else
        []
      end

    squares ++
      (Enum.map(lines, &String.slice(&1, 1..-1//1))
       |> xmas_squares_to_right())
  end

  defp xmas_squares_to_right(_lines), do: []

  @spec xmas_squares(grid()) :: [grid()]
  defp xmas_squares([_one, _two_, _three | _rest] = lines) do
    xmas_squares_to_right(lines) ++
      xmas_squares(Enum.drop(lines, 1))
  end

  defp xmas_squares(lines) when is_list(lines), do: []

  @spec part_1() :: any()
  def part_1() do
    original =
      line_stream()
      |> Enum.to_list()

    views =
      [
        original,
        vertical(original),
        diagonals(original),
        diagonals(reversed(original))
      ]

    reversed_views = Enum.map(views, &reversed/1)

    (views ++ reversed_views)
    |> Enum.map(&xmas_count/1)
    |> Enum.sum()
  end

  @doc """
  This approach uses the diagonals from part1 to find the search strings, and looks for matching
  strings in the orthogonal diagonals. But matching up the coordinates proved much trickier than I
  had anticipated. It works, but I'm not happy with the complexity.
  """
  @spec part_2a() :: any()
  def part_2a() do
    original =
      line_stream()
      |> Enum.to_list()

    grid_width = String.length(Enum.at(original, 0))
    diagonals = diagonals(original)
    orthogonals = diagonals(reversed(original))

    points_in_diagonals =
      diagonals
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, line_index} ->
        (indexes_of(line, "MAS") ++ indexes_of(line, "SAM"))
        |> Enum.map(fn match_index ->
          if line_index < grid_width do
            x = line_index - match_index
            y = match_index
            {x, y}
          else
            x = grid_width - match_index - 1
            y = line_index - grid_width + match_index + 1
            {x, y}
          end
        end)
      end)
      |> Enum.map(fn {x, y} -> {x - 1, y + 1} end)
      |> Enum.into(MapSet.new())

    points_in_orthogonals =
      orthogonals
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, line_index} ->
        (indexes_of(line, "MAS") ++ indexes_of(line, "SAM"))
        |> Enum.map(fn match_index ->
          if line_index < grid_width do
            x = grid_width - line_index + match_index - 1
            y = match_index
            {x, y}
          else
            x = match_index
            y = line_index - grid_width + match_index + 1
            {x, y}
          end
        end)
      end)
      |> Enum.map(fn {x, y} -> {x + 1, y + 1} end)
      |> Enum.into(MapSet.new())

    MapSet.intersection(
      points_in_diagonals,
      points_in_orthogonals
    )
    |> Enum.count()
  end

  @doc """
  This approach uses pattern matching to detect the whole square, and I'm much happier with the
  result.
  """
  @spec part_2b() :: any()
  def part_2b() do
    line_stream()
    |> Enum.to_list()
    |> xmas_squares()
    |> Enum.count()
  end
end

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2a: #{Main.part_2a()}")
IO.puts("Part 2b: #{Main.part_2b()}")
