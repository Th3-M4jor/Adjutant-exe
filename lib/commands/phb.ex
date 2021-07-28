defmodule BnBBot.Commands.PHB do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.CommandFn

  def help() do
    {"phb", :everyone, "Get a link to the PHB"}
  end

  def get_name() do
    "phb"
  end

  def full_help() do
    "Get a link to the PHB, future updates will include multiple sections in a link"
  end

  def call(%Nostrum.Struct.Message{} = msg, _args) do
    Logger.debug("Recieved a PHB command")

    phb_url = Application.fetch_env!(:elixir_bot, :phb)

    Api.create_message!(msg.channel_id,
      content: "B&B Players Handbook Links:",
      components: [
        %{
          type: 1,
          components: [
            %{
              type: 2,
              style: 5,
              label: "B&B PHB",
              url: phb_url
            }
          ]
        }
      ]
    )
  end
end
