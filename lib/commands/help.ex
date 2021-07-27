defmodule BnBBot.Commands.Help do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  @behaviour BnBBot.CommandFn

  def help() do
    {"help", :everyone, "prints this help message"}
  end

  def get_name() do
    "help"
  end

  def full_help() do
    "You're a special case of stupid aren't you?"
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.debug("Recieved a help command with no arguments")

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

  def call(%Nostrum.Struct.Message{} = msg, [name]) do
    Logger.debug("Recieved a help command with #{name} as the argument")

    # get every module in the project that's not a dep
    {:ok, modules} = :application.get_key(:elixir_bot, :modules)

    user_perm_num = permission_to_num(BnBBot.Util.get_user_perms(msg))

    found_module =
      for mod <- modules, mod.module_info()[:exports][:help] == 0 and mod.get_name() == name do
        {name, perms, _} = mod.help()
        {mod, name, permission_to_num(perms)}
      end

    resp =
      case found_module do
        [{mod, name, perm_num}] when perm_num <= user_perm_num ->
          full_desc = mod.full_help()
          {name, full_desc}

        [{_, _, _}] ->
          :no_perms

        _ ->
          :no_cmd
      end

    send_specific_resp(msg, resp)
  end

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a help command with too many arguments")
    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)

    dm_task =
      Task.async(fn ->
        channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)

        Api.create_message!(
          channel_id,
          "I am sorry, this command only works with zero or one argument"
        )
      end)

    Task.await_many([react_task, dm_task])
  end

  defp send_specific_resp(%Nostrum.Struct.Message{} = msg, {name, full_desc}) do
    react_task = Task.async(fn -> BnBBot.Util.react(msg) end)

    help_embed = %Embed{
      title: name,
      description: full_desc,
      color: 431_948
    }

    dm_task =
      Task.async(fn ->
        channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
        Api.create_message!(channel_id, embeds: [help_embed])
      end)

    Task.await_many([react_task, dm_task])
  end

  defp send_specific_resp(%Nostrum.Struct.Message{} = msg, :no_perms) do
    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)

    dm_task =
      Task.async(fn ->
        channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)

        Api.create_message!(
          channel_id,
          "I'm sorry, you don't have permission to use this command"
        )
      end)

    Task.await_many([react_task, dm_task])
  end

  defp send_specific_resp(%Nostrum.Struct.Message{} = msg, :no_cmd) do
    react_task = Task.async(fn -> BnBBot.Util.react(msg, false) end)

    dm_task =
      Task.async(fn ->
        channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)

        Api.create_message!(
          channel_id,
          "I'm sorry, either this command doesn't exist or doesn't have an help data"
        )
      end)

    Task.await_many([react_task, dm_task])
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
