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
    "Search for an NCP with the given name, \"Did you mean\"'s wait 30 seconds for a response"
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

    # remove all whose similarity is less than 0.61
    filtered_opts = Enum.filter(opts, fn {dist, _} -> dist >= 0.7 end)

    make_btn_response(msg, filtered_opts)
  end

  defp make_btn_response(%Nostrum.Struct.Message{} = msg, []) do
    Api.create_message!(msg.channel_id,
      content: "I'm sorry, there are no NCPs with a similar enough name",
      message_reference: %{message_id: msg.id}
    )
  end

  defp make_btn_response(%Nostrum.Struct.Message{} = msg, opts) do
    ncp_list = Enum.map(opts, fn {_, ncp} -> ncp end)
    buttons = BnBBot.ButtonAwait.generate_msg_buttons(ncp_list)

    resp =
      Api.create_message!(msg.channel_id,
        content: "Did you mean:",
        message_reference: %{message_id: msg.id},
        components: buttons
      )

    btn_response = BnBBot.ButtonAwait.await_btn_click(resp, msg.author.id)

    unless is_nil(btn_response) do
      # ncp_buttons are prefixed with an "n_"
      ["n", ncp] = String.split(btn_response.data.custom_id, "_", parts: 2)
      {:found, ncp} = BnBBot.Library.NCP.get_ncp(ncp)

      {:ok} =
        Api.create_interaction_response(
          btn_response,
          %{
            type: 7,
            data: %{
              content: "#{ncp}",
              components: []
            }
          }
        )
    else
      Api.edit_message!(resp,
        content: "Timed out waiting for response",
        components: []
      )
    end
  end
end
