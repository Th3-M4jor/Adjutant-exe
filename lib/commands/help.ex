defmodule BnBBot.Commands.Help do
  alias Nostrum.Api
  require Logger

  def help() do
    {"help", "prints this help message"}
  end

  @spec call(%Nostrum.Struct.Message{}, [String.t()]) :: any()
  def call(%Nostrum.Struct.Message{} = msg, _args) do
    {:ok, modules} = :application.get_key(:elixir_bot, :modules)

    help_vals =
      Enum.reduce(modules, [], fn mod, acc ->
        # will be nil if the fn does not exist
        function = mod.module_info()[:exports][:help]

        if is_nil(function) do
          acc
        else
          {name, desc} = apply(mod, :help, [])
          val = "#{name}\n\t#{desc}"
          acc ++ [val]
        end
      end)

    help_msg = Enum.join(help_vals, "\n")

    channel = Api.create_dm!(msg.author.id)
    Api.create_message!(channel.id, content: help_msg)
  end
end
