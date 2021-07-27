defmodule BnBBot.Commands.NCP do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.CommandFn

  def help() do
    {"ncp", :everyone, "Searches for a particular NCP"}
  end

  def get_name() do
    "ncp"
  end

  def full_help() do
    "Bot no longer DMs owner on resume events"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()

  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.debug("Recieved an NCP command with no arguments")

    Api.create_message(
      msg.channel_id,
      content: "You must provide a name as an argument",
      message_reference: %{message_id: msg.id}
    )
  end

  def call(%Nostrum.Struct.Message{} = msg, name_list) do
    name = Enum.join(name_list, " ")
    Logger.debug("Searching for the following NCP: #{name}")

    case BnBBot.Library.NCP.get_ncp(name) do
      {:found, ncp} ->
        send_found_ncp(msg, ncp)

      {:not_found, possibilities} ->
        handle_not_found_ncp(msg, possibilities)
    end
  end

  defp send_found_ncp(%Nostrum.Struct.Message{} = msg, %BnBBot.Library.NCP{} = ncp) do
    # "```\n#{val["Name"]} - (#{val["EBCost"]} EB) - #{val["Color"]}\n#{val["Description"]}\n```"
    Api.create_message(
      msg.channel_id,
      content: "#{ncp}",
      message_reference: %{message_id: msg.id}
    )
  end

  defp handle_not_found_ncp(%Nostrum.Struct.Message{} = msg, opts) do
    Logger.debug("handling a not found ncp")

    {ct, mapped} =
      Enum.reduce(opts, {1, []}, fn {_, ncp}, {ct, list} ->
        str = "#{ct}: #{ncp.name}"
        {ct + 1, [str | list]}
      end)

    did_you_mean = Enum.reverse(mapped) |> Enum.join(", ")

    resp =
      Api.create_message!(
        msg.channel_id,
        content: "Did you mean: #{did_you_mean}",
        message_reference: %{message_id: msg.id}
      )

    reaction_adder = Task.async(fn -> BnBBot.ReactionAwait.add_reaction_nums(resp, ct - 1) end)

    reaction = BnBBot.ReactionAwait.await_reaction_add(resp, ct - 1, msg.author.id)

    unless is_nil(reaction) do
      {position, _} = Integer.parse(reaction.emoji.name)
      {_, val} = Enum.at(opts, position)

      ncp = "#{val}"

      edit_task = Task.async(fn -> Api.edit_message(resp.channel_id, resp.id, ncp) end)
      Task.await_many([reaction_adder, edit_task], :infinity)
      Api.delete_all_reactions(resp.channel_id, resp.id)
    else
      Logger.debug("Took too long to react")
      Task.await(reaction_adder, :infinity)
      Api.delete_all_reactions(resp.channel_id, resp.id)
    end
  end
end
