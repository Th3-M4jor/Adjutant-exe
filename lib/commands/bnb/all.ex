defmodule BnBBot.Commands.All do
  alias Nostrum.Api
  require Logger

  @spec search(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def search(%Nostrum.Struct.Message{} = msg, args) do
    to_search = Enum.join(args, " ")

    chips =
      case BnBBot.Library.Battlechip.get_chip(to_search) do
        {:found, chip} ->
          [{1.0, chip}]

        {:not_found, chips} ->
          Enum.filter(chips, fn {dist, _} -> dist >= 0.7 end)
      end

    ncps =
      case BnBBot.Library.NCP.get_ncp(to_search) do
        {:found, ncp} ->
          [{1.0, ncp}]

        {:not_found, ncps} ->
          Enum.filter(ncps, fn {dist, _} -> dist >= 0.7 end)
      end

    possibilities =
      Enum.concat([chips, ncps])
      |> Enum.sort_by(fn {dist, _} -> dist end, &>=/2)
      |> Enum.take(9)

    do_response(msg, possibilities)
  end

  # nothing within 0.7 of the search
  defp do_response(%Nostrum.Struct.Message{} = msg, []) do
    Api.create_message!(msg.channel_id,
      content: "I'm sorry, I couldn't find anything with a similar enough name",
      message_reference: %{message_id: msg.id}
    )
  end

  # found one within 0.7 of the search
  defp do_response(%Nostrum.Struct.Message{} = msg, [{_, opt}]) do
    Api.create_message(
      msg.channel_id,
      content: "#{opt}",
      message_reference: %{message_id: msg.id}
    )
  end

  # found multiple within 0.7 of the search
  defp do_response(%Nostrum.Struct.Message{} = msg, all) do
    obj_list = Enum.map(all, fn {_, opt} -> opt end)
    buttons = BnBBot.ButtonAwait.generate_msg_buttons(obj_list)

    resp =
      Api.create_message!(
        msg.channel_id,
        content: "Did you mean:",
        message_reference: %{message_id: msg.id},
        components: buttons
      )

    btn_resp = BnBBot.ButtonAwait.await_btn_click(resp, msg.author.id)

    replacement_content =
      unless is_nil(btn_resp) do
        case String.split(btn_resp.data.custom_id, "_", parts: 2) do
          ["c", chip] ->
            {:found, chip} = BnBBot.Library.Battlechip.get_chip(chip)
            chip

          ["n", ncp] ->
            {:found, ncp} = BnBBot.Library.NCP.get_ncp(ncp)
            ncp

          ["v", _virus] ->
            raise "Unimplemented"
        end
      else
        "Timed out waiting for response"
      end

    {:ok} =
      Api.create_interaction_response(
        btn_resp,
        %{
          type: 7,
          data: %{
            content: "#{replacement_content}",
            components: []
          }
        }
      )
  end
end
