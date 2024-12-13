defmodule Main do
  @moduledoc false

  @type machine :: map()
  @type solution :: %{a: non_neg_integer(), b: non_neg_integer()}

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_machine(Enumerable.t(String.t())) :: machine()
  defp parse_machine([a_line, b_line, prize_line | _]) do
    [a_x, a_y] = Regex.run(~r/Button A: X\+(\d+), Y\+(\d+)$/, a_line, capture: :all_but_first)
    [b_x, b_y] = Regex.run(~r/Button B: X\+(\d+), Y\+(\d+)$/, b_line, capture: :all_but_first)
    [p_x, p_y] = Regex.run(~r/Prize: X=(\d+), Y=(\d+)$/, prize_line, capture: :all_but_first)

    %{
      a: %{x: String.to_integer(a_x), y: String.to_integer(a_y)},
      b: %{x: String.to_integer(b_x), y: String.to_integer(b_y)},
      p: %{x: String.to_integer(p_x), y: String.to_integer(p_y)}
    }
  end

  @spec div_rem(integer(), integer()) :: {integer(), integer()}
  defp div_rem(dividend, divisor) do
    {
      div(dividend, divisor),
      rem(dividend, divisor)
    }
  end

  @spec solve_machine(machine()) :: {:some, solution()} | :none
  defp solve_machine(machine) do
    a_gcd = Integer.gcd(machine.a.x, machine.a.y)
    y_mult = div(machine.a.x, a_gcd)
    x_mult = div(machine.a.y, a_gcd)
    b_factor = machine.b.y * y_mult - machine.b.x * x_mult
    k = machine.p.y * y_mult - machine.p.x * x_mult

    {b, 0} = div_rem(k, b_factor)
    a_k = machine.p.x - machine.b.x * b
    {a, 0} = div_rem(a_k, machine.a.x)

    {:some,
     %{
       a: a,
       b: b
     }}
  rescue
    MatchError -> :none
  end

  @spec filter_good_solutions(Enumerable.t(solution())) :: Enumerable.t(solution)
  defp filter_good_solutions(solutions) do
    Stream.flat_map(solutions, fn
      {:some, presses} -> [presses]
      :none -> []
    end)
  end

  @spec count_tokens(Enumerable.t(solution())) :: non_neg_integer()
  defp count_tokens(solutions) do
    solutions
    |> Stream.map(fn presses ->
      presses.a * 3 + presses.b
    end)
    |> Enum.sum()
  end

  @spec parse_input() :: Enumerable.t(machine())
  defp parse_input() do
    line_stream()
    |> Stream.chunk_every(4)
    |> Stream.map(&parse_machine/1)
  end

  @spec part_1() :: any()
  def part_1() do
    parse_input()
    |> Stream.map(&solve_machine/1)
    |> filter_good_solutions()
    |> Stream.filter(fn presses ->
      presses.a in 0..100 and presses.b in 0..100
    end)
    |> count_tokens
  end

  @spec part_2() :: any()
  def part_2() do
    parse_input()
    |> Stream.map(fn machine ->
      machine
      |> update_in([:p, :y], &(&1 + 10_000_000_000_000))
      |> update_in([:p, :x], &(&1 + 10_000_000_000_000))
    end)
    |> Stream.map(&solve_machine/1)
    |> filter_good_solutions()
    |> count_tokens
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
