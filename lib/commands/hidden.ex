defmodule BnBBot.Commands.Hidden do
  @moduledoc """
  Module that defines "hidden" commands.

  `die` to shutdown the bot.

  `debug` to toggle debug mode.

  `shut_up` to toggle if the bot should DM the owner.

  `add_to_bans` to add people to the list of who would be banned by...

  `salt the earth` to ban everyone on the list of people to ban from the server.

  `list_bans` to list the people who would be banned from the server.
  """
  require Logger

  alias Nostrum.Api
  alias Nostrum.Struct.ApplicationCommandInteractionDataOption, as: Option

  @behaviour BnBBot.SlashCmdFn

  @ownercmds ["die", "debug", "shut_up", "add_to_bans", "salt_the_earth", "list_bans"]
  @admincmds ["die", "add_to_bans", "salt_the_earth", "list_bans"]

  def call_slash(%Nostrum.Struct.Interaction{type: 2} = inter) do
    case inter.data.options do
      [%Option{value: "die"} | _] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: die")
        die(inter)

      [%Option{value: "debug"} | args] ->
        Logger.info(["BnBBot.Commands.Hidden.call_slash: debug ", inspect(args)])
        debug(inter, args)

      [%Option{value: "shut_up"} | _] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: shut_up")
        shut_up(inter)

      [%Option{value: "add_to_bans"} | args] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: add_to_bans")
        BnBBot.Commands.AddToBans.add_to_bans(inter, args)

      [%Option{value: "salt_the_earth"} | _] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: salt_the_earth")
        BnBBot.Commands.AddToBans.salt_the_earth(inter)

      [%Option{value: "list_bans"} | _] ->
        Logger.info("BnBBot.Commands.Hidden.call_slash: list_bans")
        BnBBot.Commands.AddToBans.list_bans(inter)

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

  def call_slash(%Nostrum.Struct.Interaction{type: 4} = inter) do
    Logger.debug("Recieved an autocomplete request for a hidden command")

    list =
      cond do
        BnBBot.Util.is_owner_msg?(inter) ->
          @ownercmds

        BnBBot.Util.is_admin_msg?(inter) ->
          @admincmds

        true ->
          []
      end

    resp =
      Enum.map(list, fn cmd ->
        %{name: cmd, value: cmd}
      end)

    {:ok} =
      Api.create_interaction_response(inter, %{
        type: 8,
        data: %{
          choices: resp
        }
      })
  end

  def get_create_map do
    %{
      type: 1,
      name: "hidden",
      description: "hidden commands, since you can't have hidden slash commands yet",
      options: [
        %{
          type: 3,
          name: "command-name",
          description: "the name of the hidden command",
          required: true,
          autocomplete: true
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

  defp debug(inter, [%Nostrum.Struct.ApplicationCommandInteractionDataOption{value: "dump"}]) do
    if BnBBot.Util.is_owner_msg?(inter) do
      Logger.debug("Dumping the current state of the bot")

      # BnBBot.Commands.Audit.dump_log()

      {lines1, lines2} = BnBBot.Commands.Audit.get_formatted(20) |> Enum.split(10)
      lines1 = lines1 |> Enum.intersperse("\n\n")
      lines2 = lines2 |> Enum.intersperse("\n\n")

      Api.create_interaction_response(inter, %{
        type: 4,
        data: %{
          content: "log_dump.txt written",
          files: [%{name: "log_dump1.txt", body: lines1}, %{name: "log_dump2.txt", body: lines2}],
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
