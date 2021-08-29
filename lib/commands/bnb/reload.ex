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

      reload_msg = "#{chip_len} Battlechips loaded\n#{virus_len} Viruses loaded\n#{ncp_len} NCPs loaded"

      Api.create_message!(msg.channel_id, reload_msg)
    end
  end
end
