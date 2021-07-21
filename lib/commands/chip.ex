defmodule BnBBot.Commands.Chip do
  alias Nostrum.Api
  require Logger

  def help() do
    {"chip", "Get info about a battlechip"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, args) do
    Logger.debug("Recieved a chip command")

    case Integer.parse(Enum.at(args, 0, "9")) do
      {count, ""} when count in 1..9 ->
        send_chip(msg, count)

      {_count, _remaining} ->
        Api.create_message(
          msg.channel_id,
          content: "Invalid argument given",
          message_reference: %{message_id: msg.id}
        )

      :error ->
        Api.create_message(
          msg.channel_id,
          content: "Invalid argument given",
          message_reference: %{message_id: msg.id}
        )
    end
  end

  defp send_chip(%Nostrum.Struct.Message{} = msg, num) do
    {:ok, response} =
      Api.create_message(
        msg.channel_id,
        content: "React to this",
        message_reference: %{message_id: msg.id}
      )

    reaction_adder = Task.async(fn -> BnBBot.ReactionAwait.add_reaction_nums(response, num) end)

    reaction_getter =
      Task.async(fn -> BnBBot.ReactionAwait.await_reaction_add(response, num, msg.author.id) end)

    [_, reaction] = Task.await_many([reaction_adder, reaction_getter], :infinity)

    edit_task = handle_reaction(response, reaction)

    delete_task = Task.async(fn -> Api.delete_all_reactions(response.channel_id, response.id) end)
    Task.await_many([edit_task, delete_task], :infinity)
  end

  @spec handle_reaction(Nostrum.Struct.Message.t(), map() | nil) :: Task.t()
  defp handle_reaction(%Nostrum.Struct.Message{} = response, nil) do
    Task.async(fn ->
      Api.edit_message(response.channel_id, response.id, "You took too long to react")
    end)
  end

  defp handle_reaction(%Nostrum.Struct.Message{} = response, reaction) do
    Task.async(fn ->
      Api.edit_message(
        response.channel_id,
        response.id,
        "You reacted with #{reaction.emoji.name}"
      )
    end)
  end
end
