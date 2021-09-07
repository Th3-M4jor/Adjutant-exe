defmodule BnBBot.Commands.All do
  alias Nostrum.Api
  require Logger

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    [opt] = inter.data.options
    to_search = opt.value
    Logger.debug(["Searching for: ", to_search])

    search_inner(inter, to_search)
    :ignore
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
    chips_task =
      Task.async(fn ->
        case BnBBot.Library.Battlechip.get_chip(to_search) do
          {:found, chip} ->
            [{1.0, chip}]

          {:not_found, chips} ->
            chips
        end
      end)

    ncps_task =
      Task.async(fn ->
        case BnBBot.Library.NCP.get_ncp(to_search) do
          {:found, ncp} ->
            [{1.0, ncp}]

          {:not_found, ncps} ->
            ncps
        end
      end)

    viruses_task =
      Task.async(fn ->
        case BnBBot.Library.Virus.get_virus(to_search) do
          {:found, virus} ->
            [{1.0, virus}]

          {:not_found, viruses} ->
            viruses
        end
      end)

    all_pos = Task.await_many([chips_task, ncps_task, viruses_task], :infinity) |> Enum.concat()

    exact_matches = Enum.filter(all_pos, fn {dist, _} -> dist == 1.0 end)

    unless Enum.empty?(exact_matches) do
      do_btn_response(msg_inter, exact_matches)
    else
      possibilities =
        Enum.sort_by(all_pos, fn {dist, _} -> dist end, &>=/2)
        |> Enum.take(25)

      do_btn_response(msg_inter, possibilities)
    end
  end

  @spec do_btn_response(Nostrum.Struct.Interaction.t(), [
          {float(), BnBBot.Library.NCP.t() | BnBBot.Library.Battlechip.t()}
        ]) :: :ignore
  def do_btn_response(%Nostrum.Struct.Interaction{} = inter, []) do
    Logger.debug("Nothing similar enough found")

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "I'm sorry, I couldn't find anything with a similar enough name",
          flags: 64
        }
      })

    :ignore
  end

  def do_btn_response(%Nostrum.Struct.Interaction{} = inter, [{_, opt}]) do
    Logger.debug("Found only one option that was similar enough")

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "#{opt}"
        }
      })

    :ignore
  end

  def do_btn_response(%Nostrum.Struct.Interaction{} = inter, all) do
    Logger.debug(["Found ", to_string(length(all)), " options that were similar enough"])

    obj_list = Enum.map(all, fn {_, opt} -> opt end)
    uuid = System.unique_integer([:positive]) |> rem(1000)
    buttons = BnBBot.ButtonAwait.generate_msg_buttons_with_uuid(obj_list, uuid)

    {:ok} =
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

          [_, "v", virus] ->
            {:found, virus} = BnBBot.Library.Virus.get_virus(virus)
            virus
        end

      edit_task =
        Task.async(fn ->
          {:ok} =
            Api.create_interaction_response(btn_response, %{
              type: 7,
              data: %{
                content: "You selected #{lib_obj.name}",
                components: []
              }
            })
        end)

      resp_task =
        Task.async(fn ->
          name = inter.data.name

          resp_text =
            if is_nil(inter.user) do
              "<@#{inter.member.user.id}> used `/#{name}`\n#{lib_obj}"
            else
              "<@#{inter.user.id}> used `/#{name}`\n#{lib_obj}"
            end

          Api.create_message!(inter.channel_id, resp_text)

          #Api.execute_webhook(inter.application_id, inter.token, %{
          #  content: resp_text
          #})
        end)

      Task.await_many([edit_task, resp_task], :infinity)
    else
      Api.request(:patch, route, %{
        content: "Timed out waiting for response",
        components: []
      })
    end

    :ignore
  end
end
