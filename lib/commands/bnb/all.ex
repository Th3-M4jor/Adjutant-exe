defmodule BnBBot.Commands.All do
  alias Nostrum.Api
  require Logger

  @spec search(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def search(%Nostrum.Struct.Message{} = msg, args) do
    to_search = Enum.join(args, " ")
    search_inner(msg, to_search)
  end

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [opt] = inter.data.options
    to_search = opt.value
    Logger.debug(["Searching for: ", to_search])

    search_inner(inter, to_search)
  end

  def get_create_map() do
    %{
      type: 1,
      name: "search",
      description: "Search NCPs, Chips, and Viruses",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of item to search for",
          required: true
        }
      ]
    }
  end

  defp search_inner(msg_inter, to_search) do
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

    do_response(msg_inter, possibilities)
  end

  # nothing within 0.7 of the search
  defp do_response(%Nostrum.Struct.Message{} = msg, []) do
    Api.create_message!(msg.channel_id,
      content: "I'm sorry, I couldn't find anything with a similar enough name",
      message_reference: %{message_id: msg.id}
    )
  end

  defp do_response(%Nostrum.Struct.Interaction{} = inter, []) do
    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "I'm sorry, I couldn't find anything with a similar enough name",
        flags: 64
      }
    })
  end

  # found one within 0.7 of the search
  defp do_response(%Nostrum.Struct.Message{} = msg, [{_, opt}]) do
    Api.create_message(
      msg.channel_id,
      content: "#{opt}",
      message_reference: %{message_id: msg.id}
    )
  end

  defp do_response(%Nostrum.Struct.Interaction{} = inter, [{_, opt}]) do
    Api.create_interaction_response(inter, %{
      type: 4,
      data: %{
        content: "#{opt}"
      }
    })
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

    btn_resp = BnBBot.ButtonAwait.await_btn_click(resp.id, msg.author.id)

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

  defp do_response(%Nostrum.Struct.Interaction{} = inter, all) do
    obj_list = Enum.map(all, fn {_, opt} -> opt end)
    uuid = System.unique_integer([:positive]) |> rem(1000)
    buttons = BnBBot.ButtonAwait.generate_msg_buttons_with_uuid(obj_list, uuid)

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
      lib_obj =
        case String.split(btn_response.data.custom_id, "_", parts: 3) do
          [_, "c", chip] ->
            {:found, chip} = BnBBot.Library.Battlechip.get_chip(chip)
            chip

          [_, "n", ncp] ->
            {:found, ncp} = BnBBot.Library.NCP.get_ncp(ncp)
            ncp

          [_, "v", _virus] ->
            raise "Unimplemented"
        end

      edit_task =
        Task.async(fn ->
          Api.request(:patch, route, %{
            content: "You selected #{lib_obj.name}",
            components: []
          })
        end)

      resp_task =
        Task.async(fn ->
          resp_text = if is_nil(inter.user) do
            "<@#{inter.member.user.id}> used `/search`\n#{lib_obj}"
          else
            "<@#{inter.user.id}> used `/search`\n#{lib_obj}"
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
