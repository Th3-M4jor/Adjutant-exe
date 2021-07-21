defmodule BnBBot.Commands.Dice do
  alias Nostrum.Api
  require Logger

  def help() do
    {"roll", "rolls XdY dice, defaults to 1d20"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, []) do
    resp_str = roll_dice("1d20")
    Api.create_message(
      msg.channel_id,
      content: resp_str,
      message_reference: %{message_id: msg.id}
    )
  end

  def call(%Nostrum.Struct.Message{} = msg, args) do

    typing_task = Task.async(fn -> Api.start_typing!(msg.channel_id) end)

    die_str = Enum.join(args)

    resp_str =
      if String.match?(die_str, ~r/^(?:\d+d\d+|\d+)(?:\+\d+d\d+|\+\d+)*$/) do
        roll_dice(die_str)
      else
        "An invalid character was found, must be in the format XdY + Z"
      end

    Task.await(typing_task)

    Api.create_message(
      msg.channel_id,
      content: resp_str,
      message_reference: %{message_id: msg.id}
    )
  end

  @spec roll_dice(String.t()) :: String.t()
  defp roll_dice(die_str) do
    rolls = String.split(die_str, "+")

    case do_roll([], rolls) do
      res when is_list(res) ->
        die_result = Enum.sum(res)
        "You rolled: #{die_result}\n#{inspect(res, charlists: :as_lists)}"

      res when is_bitstring(res) ->
        res
    end
  end

  defp do_roll(count, []) do
    count
  end

  defp do_roll(count, [to_roll | rest]) do
    vals = String.split(to_roll, "d")
    die_and_size = Enum.map(vals, fn val -> String.to_integer(val) end)

    count =
      case die_and_size do
        [num, size] when size > 0 and num in 1..65535 ->
          Logger.debug("Rolling #{num}d#{size}")
          roll_die(num, size, count)

        [num] ->
          count ++ [num]

        _ ->
          :error
      end

    case count do
      :error -> "Cowardly refusing to perform an insane operation"
      nums -> do_roll(nums, rest)
    end
  end

  defp roll_die(0, _size, count) do
    count
  end

  defp roll_die(num_rem, size, count) do
    result = Enum.random(1..size)
    count = count ++ [result]
    roll_die(num_rem - 1, size, count)
  end
end
