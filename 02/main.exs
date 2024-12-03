defmodule Main do
  @moduledoc false

  @spec line_stream() :: Stream.t()
  def line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_line(String.t()) :: [number()]
  def parse_line(line) when is_binary(line) do
    line
    |> String.split()
    |> Enum.map(&String.to_integer/1)
  end

  @spec safe?([number()], Keyword.t()) :: boolean()
  def safe?([first, second | tail] = report, opts \\ []) do
    problem_tolerance = Keyword.get(opts, :problem_tolerance, 0)

    direction_ok? =
      if first < second do
        fn value, prev -> prev < value end
      else
        fn value, prev -> prev > value end
      end

    [second | tail]
    |> Enum.reduce_while({:safe, first}, fn value, {:safe, prev} ->
      diff = abs(value - prev)

      if direction_ok?.(value, prev) && diff in 1..3 do
        {:cont, {:safe, value}}
      else
        {:halt, :unsafe}
      end
    end)
    |> then(fn
      {:safe, _value} ->
        true

      :unsafe ->
        if problem_tolerance <= 0 do
          false
        else
          Enum.any?(0..Enum.count(report), fn problem_index ->
            List.delete_at(report, problem_index)
            |> safe?(problem_tolerance: problem_tolerance - 1)
          end)
        end
    end)
  end

  @spec part_1(Keyword.t()) :: any()
  def part_1(opts \\ []) do
    line_stream()
    |> Enum.map(&parse_line/1)
    |> Enum.filter(&safe?(&1, opts))
    |> Enum.count()
  end

  @spec part_2() :: any()
  def part_2() do
    part_1(problem_tolerance: 1)
  end
end

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
