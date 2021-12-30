defmodule BnBBot.Commands.Reload do
  @moduledoc """
  Command for telling the bot to reload all chips/viruses/NCPs
  """

  alias Nostrum.Api
  alias BnBBot.Library
  require Logger

  @behaviour BnBBot.SlashCmdFn

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.info("Recieved a reload command")

    perms_level = BnBBot.Util.get_user_perms(msg)

    if perms_level == :owner or perms_level == :admin do
      Task.start(fn -> Api.start_typing(msg.channel_id) end)

      reload_msg = do_reload()

      Api.create_message!(msg.channel_id, reload_msg)
    end
  end

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    Logger.info("Recieved a reload slash command")

    perms_level = BnBBot.Util.get_user_perms(inter)

    if perms_level == :owner or perms_level == :admin do
      Task.start(fn ->
        Api.create_interaction_response(inter, %{
          type: 4,
          data: %{
            content: "Reloading...",
            flags: 64
          }
        })
      end)

      res = do_reload()

      route = "/webhooks/#{inter.application_id}/#{inter.token}/messages/@original"

      :ok =
        Api.request(:patch, route, %{
          content: res
        })
        |> elem(0)
    else
      {:ok} =
        Api.create_interaction_response(inter, %{
          type: 4,
          data: %{
            content: "You don't have permission to do that",
            flags: 64
          }
        })
    end

    :ignore
  end

  def get_create_map() do
    %{
      type: 1,
      name: "reload",
      description: "Reloads chips, ncps, viruses",
      default_permission: false
    }
  end

  defp do_reload() do
    ncp_task =
      Task.async(fn ->
        {:ok} = Library.NCP.load_ncps()
        Library.NCP.get_ncp_ct()
      end)

    chip_task =
      Task.async(fn ->
        {:ok} = Library.Battlechip.load_chips()
        Library.Battlechip.get_chip_ct()
      end)

    virus_task =
      Task.async(fn ->
        {:ok} = Library.Virus.load_viruses()
        Library.Virus.get_virus_ct()
      end)

    [ncp_len, chip_len, virus_len] = Task.await_many([ncp_task, chip_task, virus_task], :infinity)

    validation_msg =
      case Library.Virus.validate_virus_drops() do
        {:ok} -> "All virus drops exist"
        {:error, msg} -> msg
      end

    "#{chip_len} Battlechips loaded\n#{virus_len} Viruses loaded\n#{ncp_len} NCPs loaded\n#{validation_msg}"
  end
end
