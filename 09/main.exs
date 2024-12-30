# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1        106.61        9.38 ms    ±56.62%        9.02 ms       13.04 ms
# part_2         83.42       11.99 ms    ±10.53%       11.81 ms       16.94 ms
#
# Comparison:
# part_1        106.61
# part_2         83.42 - 1.28x slower +2.61 ms
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1        12.92 MB
# part_2        19.57 MB - 1.51x memory usage +6.65 MB

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
    line_stream()
    |> Enum.at(0)
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
    |> Enum.chunk_every(2, 2, [0])
    |> Enum.with_index()
    |> Enum.reduce(
      %{
        files: [],
        gaps_by_length: %{},
        chunk_start_index: 0
      },
      fn {[file_length, gap_length], file_index}, acc ->
        gap_start_index = acc.chunk_start_index + file_length

        file_chunk = %{
          start_index: acc.chunk_start_index,
          id: file_index,
          length: file_length
        }

        gaps_by_length =
          if gap_length > 0 do
            Map.update(
              acc.gaps_by_length,
              gap_length,
              [gap_start_index],
              &[gap_start_index | &1]
            )
          else
            acc.gaps_by_length
          end

        %{
          acc
          | files: [file_chunk | acc.files],
            gaps_by_length: gaps_by_length,
            chunk_start_index: acc.chunk_start_index + file_length + gap_length
        }
      end
    )
    |> then(fn acc ->
      gaps_by_length =
        for {length, indexes} <- acc.gaps_by_length, into: %{} do
          {length, Enum.reverse(indexes)}
        end

      acc.files
      |> Enum.reduce(
        %{
          gaps_by_length: gaps_by_length,
          files: []
        },
        fn file, acc ->
          acc.gaps_by_length
          |> Enum.reduce(:none, fn
            {_gap_length, []}, acc ->
              acc

            {gap_length, [gap_index | _]}, acc ->
              if gap_length < file.length or gap_index >= file.start_index do
                acc
              else
                case acc do
                  :none ->
                    {gap_length, gap_index}

                  {_acc_gap_length, acc_gap_index} when gap_index < acc_gap_index ->
                    {gap_length, gap_index}

                  _ ->
                    acc
                end
              end
          end)
          |> then(fn
            :none ->
              %{acc | files: [file | acc.files]}

            {gap_length, gap_index} ->
              gaps_by_length = Map.update!(acc.gaps_by_length, gap_length, &Enum.drop(&1, 1))
              new_gap_length = gap_length - file.length

              gaps_by_length =
                if new_gap_length > 0 do
                  new_gap_index = gap_index + file.length

                  Map.update(
                    gaps_by_length,
                    new_gap_length,
                    [new_gap_index],
                    fn indexes ->
                      {left, right} = Enum.split_while(indexes, &(&1 < new_gap_index))
                      left ++ [new_gap_index | right]
                    end
                  )
                else
                  gaps_by_length
                end

              %{
                acc
                | gaps_by_length: gaps_by_length,
                  files: [%{file | start_index: gap_index} | acc.files]
              }
          end)
        end
      )
    end)
    |> then(fn acc ->
      acc.files
      |> Enum.sort_by(& &1.start_index)
      |> Enum.reduce(0, fn file, acc ->
        file_end_index = file.start_index + file.length - 1

        file_checksum =
          ((file.start_index + file_end_index) * file.length * file.id)
          |> Bitwise.bsr(1)

        file_checksum + acc
      end)
    end)
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
