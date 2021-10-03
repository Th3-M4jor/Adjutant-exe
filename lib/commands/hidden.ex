defmodule BnBBot.Commands.Hidden do
  require Logger

  alias Nostrum.Api

  @behaviour BnBBot.SlashCmdFn

  def call_slash(%Nostrum.Struct.Interaction{} = inter) do
    case inter.data.options do
      [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "die"} | _] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: die")
        die(inter)

      [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "debug"} | args] ->
        Logger.info(["BnBBot.Commands.Hidden.call_slash: debug ", inspect(args)])
        debug(inter, args)

      [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "shut_up"} | _] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: shut_up")
        shut_up(inter)

      _ ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: unknown")

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
      name: "hidden",
      description: "hidden commands, since you can't have hidden slash commands yet",
      options: [
        %{
          type: 3,
          name: "command-name",
          description: "the name of the hidden command",
          required: true
        },
        %{
          type: 3,
          name: "args",
          description: "the arguments to the hidden command",
          required: false
        }
      ],
      default_permission: false
    }
  end

  defp die(inter) do
    if BnBBot.Util.is_owner_msg?(inter) or BnBBot.Util.is_admin_msg?(inter) do
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Shutting down",
          flags: 64
        }
      })

      System.stop(0)
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp debug(inter, []) do
    if BnBBot.Util.is_owner_msg?(inter) do
      Logger.configure(level: :debug)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Debug logging on",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp debug(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "on"}]) do
    debug(inter, [])
  end

  defp debug(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "off"}]) do
    if BnBBot.Util.is_owner_msg?(inter) do
      Logger.configure(level: :warning)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Debug logging off",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp debug(inter, _unknown) do
    if BnBBot.Util.is_owner_msg?(inter) do
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "That is an invalid argument type",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end

  defp shut_up(inter) do
    if BnBBot.Util.is_owner_msg?(inter) do
      res =
        case :ets.lookup(:bnb_bot_data, :dm_owner) do
          [dm_owner: val] -> val
          _ -> true
        end

      Logger.debug("Currently set to DM messages: #{res}")
      new_val = not res
      :ets.insert(:bnb_bot_data, dm_owner: new_val)

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "Shutting up",
          flags: 64
        }
      })
    else
      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "You don't have permission to do that",
          flags: 64
        }
      })
    end
  end
end
