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
      Api.start_typing!(msg.channel_id)

      ncp_msg =
        case Library.NCP.load_ncps() do
          {:ok, len} ->
            "#{len} NCPs loaded"

          :http_err ->
            "API Error occurred in reloading NCPs"
        end

      Api.create_message!(msg.channel_id, ncp_msg)
    end
  end
end
