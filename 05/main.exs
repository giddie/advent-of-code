defmodule Main do
  @moduledoc false

  @type orders :: %{String.t() => [String.t()]}
  @type update :: [String.t()]

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_orders([String.t()]) :: orders()
  defp parse_orders(lines) when is_list(lines) do
    lines
    |> Enum.map(&String.split(&1, "|"))
    |> Enum.group_by(
      fn [l, _r] -> l end,
      fn [_l, r] -> r end
    )
  end

  @spec parse_update(String.t()) :: update()
  defp parse_update(string) when is_binary(string) do
    String.split(string, ",")
  end

  @spec parse_input() :: {orders(), [update()]}
  defp parse_input() do
    line_stream()
    |> Enum.to_list()
    |> Enum.split_while(&(String.length(&1) > 0))
    |> then(fn {orders, ["" | updates]} ->
      {
        parse_orders(orders),
        Enum.map(updates, &parse_update/1)
      }
    end)
  end

  @spec sort_pages(orders(), update()) :: update()
  defp sort_pages(%{} = orders, pages) when is_list(pages) do
    Enum.sort(pages, fn left, right ->
      case Map.fetch(orders, left) do
        {:ok, pages_after} -> right in pages_after
        :error -> false
      end
    end)
  end

  @spec middle_number_sum(update()) :: number()
  defp middle_number_sum(pages) when is_list(pages) do
    pages
    |> Enum.map(&Enum.at(&1, div(Enum.count(&1), 2)))
    |> Enum.map(&String.to_integer/1)
    |> Enum.sum()
  end

  @spec part_1() :: any()
  def part_1() do
    {orders, updates} = parse_input()

    updates
    |> Enum.filter(fn pages ->
      pages == sort_pages(orders, pages)
    end)
    |> middle_number_sum()
  end

  @spec part_2() :: any()
  def part_2() do
    {orders, updates} = parse_input()

    updates
    |> Enum.flat_map(fn pages ->
      case sort_pages(orders, pages) do
        ^pages -> []
        sorted -> [sorted]
      end
    end)
    |> middle_number_sum()
  end
end

Inspect.Opts.default_inspect_fun(&Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists}))
IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
