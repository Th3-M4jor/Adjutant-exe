defmodule BnBBot.Commands.Shuffle do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"shuffle", :everyone, "Shuffle a series of numbers"}
  end

  def get_name() do
    "shuffle"
  end

  def full_help() do
    "Based on the number of arguments given, dones one of two things:
      One argument: a shuffled list of numbers from 1 to N (inclusive)
      Two arguments: a shuffled list of numbers from M to N (inclusive)"
  end

  @spec call(Nostrum.Struct.Message.t(), [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.debug("Recived a shuffle command with no args")
    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)

    dm_task =
      Task.async(fn ->
        dm_channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
        Api.create_message(dm_channel_id, "Error, this command requires one or two arguments")
      end)

    Task.await_many([react_task, dm_task], :infinity)
  end

  def call(%Nostrum.Struct.Message{} = msg, [ct]) do
    Logger.debug("Attempting to shuffle all numbers from 1 to #{ct}")

    result =
      case Integer.parse(ct) do
        {n, ""} when n <= 1 ->
          "Cowardly refusing to shuffle a number less than 2"

        {n, ""} when n <= 64 ->
          vals = shuffle_nums(1, n)
          "```\n[#{Enum.join(vals, ", ")}]\n```"

        {_n, ""} ->
          "Cowardly refusing to shuffle a number greater than 64"

        _ ->
          "Error, `#{ct}` is not an integer"
      end

    Api.create_message(msg.channel_id, result)
  end

  def call(%Nostrum.Struct.Message{} = msg, [start, stop]) do
    Logger.debug("Attempting to shuffle all numbers from #{start} to #{stop}")

    result =
      case {Integer.parse(start), Integer.parse(stop)} do
        {{first, ""}, {second, ""}} when abs(first - second) <= 1 ->
          "Cowardly refusing to shuffle numbers with a difference of less than 2"

        {{first, ""}, {second, ""}} when abs(first - second) <= 64 ->
          vals = shuffle_nums(first, second)
          "```\n[#{Enum.join(vals, ", ")}]\n```"

        {{_first, ""}, {_second, ""}} ->
          "Cowardly refusing to shuffle numbers with a difference greater than 64"

        _ ->
          "Error, this command only works on integers"
      end

    Api.create_message(msg.channel_id, result)
  end

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a shuffle command with too many args")

    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)

    dm_task =
      Task.async(fn ->
        dm_channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
        Api.create_message(dm_channel_id, "Error, this command requires one or two arguments")
      end)

    Task.await_many([react_task, dm_task], :infinity)
  end

  defp shuffle_nums(start, stop) when start < stop do
    Enum.shuffle(start..stop)
  end

  defp shuffle_nums(stop, start) when start < stop do
    Enum.shuffle(start..stop)
  end
end
