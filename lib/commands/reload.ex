defmodule BnBBot.Commands.Reload do
  alias Nostrum.Api
  alias BnBBot.Library
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"reload", :admin, "Reloads the stored data for bnb Resources"}
  end

  def get_name() do
    "reload"
  end

  def full_help() do
    "Reloads NCPs (Eventually will be chips and viruses as well)"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a reload command")

    perms_level = BnBBot.Util.get_user_perms(msg)

    if perms_level == :owner or perms_level == :admin do
      Task.start(fn -> Api.start_typing(msg.channel_id) end)

      ncp_task = Task.async(fn -> Library.NCP.load_ncps() end)
      chip_task = Task.async(fn -> Library.Battlechip.load_chips() end)

      [ncp_res, chip_res] = Task.await_many([ncp_task, chip_task], :infinity)

      ncp_msg =
        case ncp_res do
          {:ok, len} ->
            "#{len} NCPs loaded"

          :http_err ->
            "Error occurred in reloading NCPs"
        end

        chip_msg =
          case chip_res do
          {:ok, len} ->
            "#{len} Battlechips loaded"
          :http_err ->
            "Error occurred in reloading Battlechips"
        end

        reload_msg = "#{chip_msg}\n#{ncp_msg}"

      Api.create_message!(msg.channel_id, reload_msg)
    end
  end
end
