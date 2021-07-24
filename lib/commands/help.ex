defmodule BnBBot.Commands.Help do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"help", :everyone, "prints this help message"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a help command")

    # get every module in the project that's not a dep
    {:ok, modules} = :application.get_key(:elixir_bot, :modules)

    react_task = Task.async(fn -> BnBBot.Util.react(msg) end)

    user_perm_num = permission_to_num(BnBBot.Util.get_user_perms(msg))

    # yes this is inefficient but there are so few commands it's kinda irrelevant
    help_vals =
      Enum.filter(modules, fn mod -> mod.module_info()[:exports][:help] == 0 end)
      |> Enum.map(fn mod -> mod.help() end)
      |> Enum.filter(fn {_, perms, _} -> permission_to_num(perms) <= user_perm_num end)
      |> Enum.sort_by(fn e -> elem(e, 0) end)
      |> Enum.map(fn {name, _, desc} -> %Embed.Field{name: name, value: desc} end)

    help_embed = %Embed{
      description:
        "If you want more information about a specific command, just pass the name of the command as an argument",
      color: 431_948,
      fields: help_vals
    }

    dm_task =
      Task.async(fn ->
        channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
        Api.create_message!(channel_id, embeds: [help_embed])
      end)

    Task.await_many([react_task, dm_task], :infinity)
  end

  defp permission_to_num(:everyone) do
    1
  end

  defp permission_to_num(:admin) do
    2
  end

  defp permission_to_num(:owner) do
    3
  end
end
