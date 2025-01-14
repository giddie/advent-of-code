# Benchmarks
#
# Name             ips        average  deviation         median         99th %
# part_1       32.00 K       31.25 μs    ±35.78%       28.74 μs       55.54 μs
# part_2        1.18 K      846.48 μs    ±23.55%      754.32 μs     1403.61 μs
#
# Comparison:
# part_1       32.00 K
# part_2        1.18 K - 27.09x slower +815.23 μs
#
# Memory usage statistics:
#
# Name      Memory usage
# part_1       0.0100 MB
# part_2         1.24 MB - 123.68x memory usage +1.23 MB

defmodule Main do
  @moduledoc false

  @spec line_stream() :: Stream.t()
  defp line_stream() do
    File.stream!("input")
    |> Stream.map(&String.trim_trailing(&1, "\n"))
  end

  @spec parse_input(Enumerable.t(String.t())) :: map()
  defp parse_input(lines) do
    Enum.reduce(
      lines,
      %{
        a: :none,
        b: :none,
        c: :none,
        program: :none
      },
      fn
        "Register A: " <> num, acc ->
          %{acc | a: String.to_integer(num)}

        "Register B: " <> num, acc ->
          %{acc | b: String.to_integer(num)}

        "Register C: " <> num, acc ->
          %{acc | c: String.to_integer(num)}

        "Program: " <> nums, acc ->
          program =
            nums
            |> String.split(",")
            |> Enum.map(&String.to_integer/1)

          %{acc | program: program}

        "", acc ->
          acc
      end
    )
  end

  @spec read_combo(non_neg_integer(), map()) :: non_neg_integer()
  defp read_combo(operand, registers) do
    case operand do
      0 -> 0
      1 -> 1
      2 -> 2
      3 -> 3
      4 -> registers.a
      5 -> registers.b
      6 -> registers.c
    end
  end

  @spec run_opcode(non_neg_integer(), non_neg_integer(), map()) :: map()
  defp run_opcode(0, operand, registers) do
    result = Bitwise.bsr(registers.a, read_combo(operand, registers))

    %{
      registers
      | a: result,
        ip: registers.ip + 2
    }
  end

  defp run_opcode(1, operand, registers) do
    result = Bitwise.bxor(registers.b, operand)

    %{
      registers
      | b: result,
        ip: registers.ip + 2
    }
  end

  defp run_opcode(2, operand, registers) do
    result = read_combo(operand, registers) |> Bitwise.band(7)

    %{
      registers
      | b: result,
        ip: registers.ip + 2
    }
  end

  defp run_opcode(3, operand, registers) do
    ip =
      case registers.a do
        0 -> registers.ip + 2
        _ -> operand
      end

    %{registers | ip: ip}
  end

  defp run_opcode(4, _operand, registers) do
    result = Bitwise.bxor(registers.b, registers.c)

    %{
      registers
      | b: result,
        ip: registers.ip + 2
    }
  end

  defp run_opcode(5, operand, registers) do
    result = read_combo(operand, registers) |> Bitwise.band(7)

    %{
      registers
      | out: [result | registers.out],
        ip: registers.ip + 2
    }
  end

  defp run_opcode(6, operand, registers) do
    result = Bitwise.bsr(registers.a, read_combo(operand, registers))

    %{
      registers
      | b: result,
        ip: registers.ip + 2
    }
  end

  defp run_opcode(7, operand, registers) do
    result = Bitwise.bsr(registers.a, read_combo(operand, registers))

    %{
      registers
      | c: result,
        ip: registers.ip + 2
    }
  end

  @spec run_program([non_neg_integer()], map()) :: [non_neg_integer()]
  defp run_program(program, registers) do
    if registers.ip >= tuple_size(program) do
      Enum.reverse(registers.out)
    else
      opcode = elem(program, registers.ip)
      operand = elem(program, registers.ip + 1)
      next_registers = run_opcode(opcode, operand, registers)
      run_program(program, next_registers)
    end
  end

  @spec register_a_possibilities([non_neg_integer()], map()) :: Enumerable.t(non_neg_integer())
  defp register_a_possibilities(program, registers) do
    ip = registers.ip - 2

    if ip < 0 do
      [registers.a]
    else
      opcode = elem(program, ip)
      operand = elem(program, ip + 1)

      if opcode == 0 do
        upper = Bitwise.bsl(registers.a, operand)
        lower_max = Bitwise.bsl(1, operand) - 1
        Stream.map(0..lower_max, &Bitwise.bor(upper, &1))
      else
        [registers.a]
      end
      |> Stream.flat_map(fn a ->
        register_a_possibilities(program, %{registers | ip: ip, a: a})
      end)
    end
  end

  @spec registers_that_produce_output([non_neg_integer()], [non_neg_integer()], map()) ::
          Enumerable.t(map())
  defp registers_that_produce_output(_program, [], registers), do: [registers]

  defp registers_that_produce_output(program, [out_head | out_tail], registers) do
    register_a_possibilities(program, %{registers | ip: tuple_size(program)})
    |> Stream.filter(fn a ->
      registers = %{registers | a: a}
      [out] = run_program(program, registers)
      out == out_head
    end)
    |> Stream.flat_map(fn a ->
      registers_that_produce_output(program, out_tail, %{registers | a: a})
    end)
  end

  @spec part_1() :: any()
  def part_1() do
    parsed_input =
      line_stream()
      |> parse_input()

    program = List.to_tuple(parsed_input.program)

    registers =
      Map.take(parsed_input, [:a, :b, :c])
      |> Map.merge(%{ip: 0, out: []})

    run_program(program, registers)
    |> Enum.join(",")
  end

  @spec part_2() :: any()
  def part_2() do
    parsed_input =
      line_stream()
      |> parse_input()

    {single_loop, [3, 0]} = Enum.split(parsed_input.program, -2)
    program = List.to_tuple(single_loop)

    registers =
      Map.take(parsed_input, [:a, :b, :c])
      |> Map.merge(%{a: 0, ip: 0, out: []})

    registers_that_produce_output(program, Enum.reverse(parsed_input.program), registers)
    |> Enum.at(0)
    |> then(&Map.fetch!(&1, :a))
  end
end

Inspect.Opts.default_inspect_fun(
  &Inspect.inspect(&1, %Inspect.Opts{&2 | charlists: :as_lists, limit: :infinity})
)

IO.puts("Part 1: #{Main.part_1()}")
IO.puts("Part 2: #{Main.part_2()}")
