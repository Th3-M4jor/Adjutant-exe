defmodule BnBBot.Commands.All do
  @moduledoc """
  Command for searching all BattleChips/Viruses/NPCs for a given name.
  """

  alias Nostrum.Api
  require Logger

  alias BnBBot.Library.{Battlechip, NCP, Virus}

  use BnBBot.SlashCmdFn, permissions: :everyone

  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    [opt] = inter.data.options
    to_search = opt.value
    Logger.info(["Searching for: ", to_search])

    search_inner(inter, to_search)
    :ignore
  end

  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    [opt] = inter.data.options
    to_search = opt.value

    Logger.debug(["Generating autcomplete for: ", inspect(to_search)])

    chips_task =
      Task.async(fn ->
        Battlechip.get_autocomplete(to_search)
      end)

    viruses_task =
      Task.async(fn ->
        Virus.get_autocomplete(to_search)
      end)

    ncp_task =
      Task.async(fn ->
        NCP.get_autocomplete(to_search)
      end)

    all_pos =
      Task.await_many([chips_task, viruses_task, ncp_task])
      |> Enum.concat()
      |> Enum.uniq_by(fn {_, name} -> name end)
      |> Enum.sort_by(fn {pos, _} -> pos end, &>=/2)
      |> Enum.take(25)
      |> Enum.map(fn {_, name} ->
        lower_name = String.downcase(name, :ascii)
        %{name: name, value: lower_name}
      end)

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 8,
        data: %{
          choices: all_pos
        }
      })
  end

  def get_create_map do
    %{
      type: 1,
      name: "search",
      description: "Search NCPs, Chips, and Viruses",
      options: [
        %{
          type: 3,
          name: "name",
          description: "The name of item to search for",
          required: true,
          autocomplete: true
        }
      ]
    }
  end

  defp search_inner(msg_inter, to_search) do
    chips_task =
      Task.async(fn ->
        case Battlechip.get_chip(to_search) do
          {:found, chip} ->
            [{1.0, chip}]

          {:not_found, chips} ->
            chips
        end
      end)

    ncps_task =
      Task.async(fn ->
        case NCP.get_ncp(to_search) do
          {:found, ncp} ->
            [{1.0, ncp}]

          {:not_found, ncps} ->
            ncps
        end
      end)

    viruses_task =
      Task.async(fn ->
        case Virus.get_virus(to_search) do
          {:found, virus} ->
            [{1.0, virus}]

          {:not_found, viruses} ->
            viruses
        end
      end)

    all_pos = Task.await_many([chips_task, ncps_task, viruses_task], :infinity) |> Stream.concat()

    exact_matches = Enum.filter(all_pos, fn {dist, _} -> dist == 1.0 end)

    if Enum.empty?(exact_matches) do
      possibilities =
        Enum.sort_by(all_pos, fn {dist, _} -> dist end, &>=/2)
        |> Enum.take(25)

      do_btn_response(msg_inter, possibilities)
    else
      do_btn_response(msg_inter, exact_matches)
    end
  end

  @spec do_btn_response(Nostrum.Struct.Interaction.t(), [
          {float(),
           BnBBot.Library.NCP.t() | BnBBot.Library.Battlechip.t() | BnBBot.Library.Virus.t()}
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

    uuid =
      System.unique_integer([:positive])
      # constrain to be between 0 and 0xFF_FF_FF
      |> Bitwise.band(0xFF_FF_FF)

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

    case btn_response do
      {btn_inter, {kind, name}} ->
        lib_obj = kind_name_to_lib_obj(kind, name)

        edit_task =
          Task.async(fn ->
            {:ok} =
              Api.create_interaction_response(btn_inter, %{
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

            # Api.execute_webhook(inter.application_id, inter.token, %{
            #  content: resp_text
            # })
          end)

        Task.await_many([edit_task, resp_task], :infinity)

      nil ->
        Api.request(:patch, route, %{
          content: "Timed out waiting for response",
          components: []
        })
    end

    :ignore
  end

  defp kind_name_to_lib_obj(kind, name) do
    case kind do
      ?n ->
        BnBBot.Library.NCP.get!(name)

      ?c ->
        BnBBot.Library.Battlechip.get!(name)

      ?v ->
        BnBBot.Library.Virus.get!(name)
    end
  end
end
