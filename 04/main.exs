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

  @spec part_2() :: any()
  def part_2() do
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
end

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
