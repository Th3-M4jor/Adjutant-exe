defmodule BnBBot.Commands.NCP do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [opt] = inter.data.options
    name = opt.value
    Logger.debug(["Searching for the following NCP: ", name])

    case BnBBot.Library.NCP.get_ncp(name) do
      {:found, ncp} ->
        send_found_ncp(inter, ncp)

      {:not_found, possibilities} ->
        handle_not_found_ncp(inter, possibilities)
    end
    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "ncp",
      description: "Searches for a particular NCP",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of the NCP to search for",
          required: true
        }
      ]
    }
  end

  defp send_found_ncp(%Nostrum.Struct.Interaction{} = inter, %BnBBot.Library.NCP{} = ncp) do
    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: to_string(ncp)
      }
    })
  end

  defp handle_not_found_ncp(msg_inter, opts) do
    Logger.debug("handling a not found ncp")

    # remove all whose similarity is less than 0.61
    filtered_opts = Enum.filter(opts, fn {dist, _} -> dist >= 0.7 end)

    make_btn_response(msg_inter, filtered_opts)
  end

  defp make_btn_response(%Nostrum.Struct.Interaction{} = inter, []) do
    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "I'm sorry, there are no NCPs with a similar name",
        flags: 64
      }
    })
  end

  defp make_btn_response(%Nostrum.Struct.Interaction{} = inter, opts) do
    ncp_list = Enum.map(opts, fn {_, ncp} -> ncp end)
    uuid = System.unique_integer([:positive]) |> rem(1000)
    buttons = BnBBot.ButtonAwait.generate_msg_buttons_with_uuid(ncp_list, uuid)

    Api.create_interaction_response(
      inter,
      %{
        type: 4,
        data: %{
          content: "Did you mean:",
          flags: 64,
          components: buttons
        }
      }
    )

    btn_response = BnBBot.ButtonAwait.await_btn_click(uuid, nil)

    route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

    unless is_nil(btn_response) do
      # ncp_buttons are prefixed with an "n_"
      [_uuid, "n", ncp] = String.split(btn_response.data.custom_id, "_", parts: 3)

      {:found, ncp} = BnBBot.Library.NCP.get_ncp(ncp)

      edit_task =
        Task.async(fn ->

          Api.request(:patch, route, %{
            content: "You selected #{ncp.name}",
            components: []
          })
        end)

      resp_task =
        Task.async(fn ->

          resp_text = if is_nil(inter.user) do
            "<@#{inter.member.user.id}> used `/ncp`\n#{ncp}"
          else
            "<@#{inter.user.id}> used `/ncp`\n#{ncp}"
          end

          Api.execute_webhook(inter.application_id, inter.token, %{
            content: resp_text
          })
        end)

      Task.await_many([edit_task, resp_task], :infinity)
    else

      Api.request(:patch, route, %{
        content: "Timed out waiting for response",
        components: []
      })
    end
  end
end
