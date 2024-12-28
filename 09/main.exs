defmodule Main do
  @moduledoc false

  @type file :: %{id: non_neg_integer(), length: non_neg_integer()}
  @type gap :: non_neg_integer()

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_disk_map(String.t()) :: {[file()], [gap()]}
  defp parse_disk_map(string) when is_binary(string) do
    string
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
    |> Enum.chunk_every(2, 2, [0])
    |> Enum.with_index()
    |> Enum.reduce(
      {[], []},
      fn {[file_length, gap_length], index}, {files, gaps} ->
        {
          [%{id: index, length: file_length} | files],
          [gap_length | gaps]
        }
      end
    )
  end

  @spec part_1() :: any()
  def part_1() do
    {files, gaps} =
      line_stream()
      |> Enum.at(0)
      |> parse_disk_map()

    Stream.resource(
      fn ->
        %{
          chunks_in_place: Enum.reverse(files),
          chunks_to_relocate: files,
          gaps: Enum.reverse(gaps),
          chunk: [],
          remaining_gaps: Enum.count(gaps) - 1
        }
      end,
      fn
        :finished ->
          {:halt, {}}

        %{remaining_gaps: value, chunks_to_relocate: [final_chunk | _]} when value <= 0 ->
          {[[final_chunk]], :finished}

        %{
          chunks_in_place: [chunk_in_place | chunks_in_place_tail],
          chunks_to_relocate: [chunk_to_relocate | chunks_to_relocate_tail],
          gaps: [gap_length | gap_tail]
        } = acc ->
          cond do
            chunk_to_relocate.length < gap_length ->
              {[],
               %{
                 acc
                 | chunks_to_relocate: chunks_to_relocate_tail,
                   gaps: [gap_length - chunk_to_relocate.length | gap_tail],
                   chunk: [chunk_to_relocate | acc.chunk],
                   remaining_gaps: acc.remaining_gaps - 1
               }}

            chunk_to_relocate.length > gap_length ->
              {[
                 [
                   chunk_in_place
                   | Enum.reverse([%{chunk_to_relocate | length: gap_length} | acc.chunk])
                 ]
               ],
               %{
                 acc
                 | chunks_in_place: chunks_in_place_tail,
                   chunks_to_relocate: [
                     %{chunk_to_relocate | length: chunk_to_relocate.length - gap_length}
                     | chunks_to_relocate_tail
                   ],
                   gaps: gap_tail,
                   chunk: [],
                   remaining_gaps: acc.remaining_gaps - 1
               }}

            true ->
              {
                [[chunk_in_place | Enum.reverse([chunk_to_relocate | acc.chunk])]],
                %{
                  acc
                  | chunks_in_place: chunks_in_place_tail,
                    chunks_to_relocate: chunks_to_relocate_tail,
                    gaps: gap_tail,
                    chunk: [],
                    remaining_gaps: acc.remaining_gaps - 2
                }
              }
          end
      end,
      & &1
    )
    |> Enum.concat()
    |> Stream.transform(0, fn chunk, chunk_start_index ->
      next_chunk_start_index = chunk_start_index + chunk.length

      # Sum of integer sequence
      chunk_checksum_sum =
        ((chunk_start_index + next_chunk_start_index - 1) * chunk.length * chunk.id)
        |> Bitwise.bsr(1)

      {[chunk_checksum_sum], next_chunk_start_index}
    end)
    |> Enum.sum()
  end

  @spec part_2() :: any()
  def part_2() do
    {files, gaps} =
      line_stream()
      |> Enum.at(0)
      |> parse_disk_map()

    files
    |> Enum.with_index()
    |> Enum.reduce(
      %{
        files_after_relocations: [],
        gaps: gaps |> Enum.with_index() |> Enum.reverse(),
        relocations: %{}
      },
      fn
        {chunk_to_relocate, file_index}, acc ->
          Enum.split_while(acc.gaps, fn {gap, gap_index} ->
            gap < chunk_to_relocate.length and gap_index > file_index
          end)
          |> then(fn found ->
            with {_left, [{_gap, gap_index} | _]} when gap_index <= file_index <- found do
              {acc.gaps, []}
            end
          end)
          |> then(fn
            {_left, []} ->
              %{
                acc
                | files_after_relocations: [
                    {:chunk, chunk_to_relocate} | acc.files_after_relocations
                  ]
              }

            {left, [{chosen_gap, index} | right]} ->
              new_gap_length = chosen_gap - chunk_to_relocate.length
              gaps = left ++ [{new_gap_length, index} | right]

              relocations =
                Map.update(
                  acc.relocations,
                  index,
                  [{:chunk, chunk_to_relocate}],
                  &[{:chunk, chunk_to_relocate} | &1]
                )

              %{
                acc
                | files_after_relocations: [
                    {:gap, chunk_to_relocate.length} | acc.files_after_relocations
                  ],
                  gaps: gaps,
                  relocations: relocations
              }
          end)
      end
    )
    |> then(fn acc ->
      new_gap_chunks =
        for {gap_length, index} <- acc.gaps do
          chunks = Map.get(acc.relocations, index, [])

          if gap_length > 0 do
            [{:gap, gap_length} | chunks]
          else
            chunks
          end
          |> Enum.reverse()
        end

      Enum.zip(acc.files_after_relocations, new_gap_chunks)
      |> Enum.map(fn {left, right} -> [left | right] end)
      |> Enum.concat()
    end)
    |> Stream.transform(0, fn
      {:gap, length}, chunk_start_index ->
        {[], chunk_start_index + length}

      {:chunk, chunk}, chunk_start_index ->
        next_chunk_start_index = chunk_start_index + chunk.length

        # Sum of integer sequence
        chunk_checksum_sum =
          ((chunk_start_index + next_chunk_start_index - 1) * chunk.length * chunk.id)
          |> Bitwise.bsr(1)

        {[chunk_checksum_sum], next_chunk_start_index}
    end)
    |> Enum.sum()
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
