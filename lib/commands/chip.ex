defmodule BnBBot.Commands.Chip do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"chip", :everyone, "Get info about a battlechip"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a chip command")

    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)
    dm_task = Task.async(fn ->
      channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
      Api.create_message!(channel_id, "I'm sorry, this command isn't implemented yet")
    end)

    Task.await_many([react_task, dm_task])

    # case Integer.parse(Enum.at(args, 0, "9")) do
    #   {count, ""} when count in 1..9 ->
    #     send_chip(msg, count)

    #   {_count, _remaining} ->
    #     Api.create_message(
    #       msg.channel_id,
    #       content: "Invalid argument given",
    #       message_reference: %{message_id: msg.id}
    #     )

    #   :error ->
    #     Api.create_message(
    #       msg.channel_id,
    #       content: "Invalid argument given",
    #       message_reference: %{message_id: msg.id}
    #     )
    # end
  end

  @spec _send_chip(Nostrum.Struct.Message.t(), integer()) :: any()
  defp _send_chip(%Nostrum.Struct.Message{} = msg, num) do
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

    edit_task = _handle_reaction(response, reaction)

    delete_task = Task.async(fn -> Api.delete_all_reactions(response.channel_id, response.id) end)
    Task.await_many([edit_task, delete_task], :infinity)
  end

  @spec _handle_reaction(Nostrum.Struct.Message.t(), map() | nil) :: Task.t()
  defp _handle_reaction(%Nostrum.Struct.Message{} = response, nil) do
    Task.async(fn ->
      Api.edit_message(response.channel_id, response.id, "You took too long to react")
    end)
  end

  defp _handle_reaction(%Nostrum.Struct.Message{} = response, reaction) do
    Task.async(fn ->
      Api.edit_message(
        response.channel_id,
        response.id,
        "You reacted with #{reaction.emoji.name}"
      )
    end)
  end
end
