defmodule BnBBot.Commands.Help do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  require Logger

  def help() do
    {"help", "prints this help message"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a help command")

    # get every module in the project that's not a dep
    {:ok, modules} = :application.get_key(:elixir_bot, :modules)

    react_task = Task.async(fn -> BnBBot.Util.react(msg) end)


    # for each module, if module has a function named help with arity 0
    help_vals =
      for mod <- modules, mod.module_info()[:exports][:help] == 0 do
        {name, desc} = mod.help()
        %Embed.Field{name: name, value: desc}
      end

    help_embed = %Embed{
      description:
        "If you want more information about a specific command, just pass the name of the command as an argument",
      color: 431_948,
      fields: help_vals
    }

    dm_task = Task.async(fn ->
      channel_id = BnBBot.Util.find_dm_channel_id(msg.author.id)
      Api.create_message!(channel_id, embeds: [help_embed])
    end)

    Task.await_many([react_task, dm_task], :infinity)

  end
end
