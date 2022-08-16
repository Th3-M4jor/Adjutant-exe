defmodule BnBBot.Command do
  @moduledoc """
  Module for dispatching both text and slash commands
  """

  alias Nostrum.Api
  alias Nostrum.Struct.{Interaction, Message}

  require Logger

  # Legacy text based commands,
  @spec dispatch(Message.t() | Interaction.t()) :: any()
  def dispatch(%Interaction{} = inter) do
    handle_slash_command(inter.data.name, inter)
  end

  def dispatch(%Message{} = msg) do
    BnBBot.Command.Text.dispatch(msg)
  end

  @slash_commands [
    BnBBot.Command.Slash.Dice,
    BnBBot.Command.Slash.Ping,
    BnBBot.Command.Slash.Shuffle,
    BnBBot.Command.Slash.BNB.PHB,
    BnBBot.Command.Slash.BNB.NCP,
    BnBBot.Command.Slash.BNB.Chip,
    BnBBot.Command.Slash.BNB.Virus,
    BnBBot.Command.Slash.BNB.Status,
    BnBBot.Command.Slash.BNB.Blight,
    BnBBot.Command.Slash.BNB.Panels,
    BnBBot.Command.Slash.BNB.Reload,
    BnBBot.Command.Slash.BNB.Groups,
    BnBBot.Command.Slash.Hidden,
    BnBBot.Command.Slash.Insults,
    BnBBot.Command.Slash.RemindMe,
    BnBBot.Command.Slash.HOTG.Team
  ]

  @deleted_commands [
    BnBBot.Command.Slash.BNB.Create
  ]

  def setup_commands do
    BnBBot.Command.State.delete_commands(@deleted_commands)
    BnBBot.Command.State.setup_commands(@slash_commands)
  end

  # Generate the command handlers at compile time.
  for cmd <- @slash_commands, Code.ensure_compiled!(cmd) do
    name = cmd.get_create_map()[:name]
    true = function_exported?(cmd, :call, 1)
    true = function_exported?(cmd, :call_slash, 1)

    defp handle_slash_command(unquote(name), %Interaction{} = inter) do
      unquote(cmd).call(inter)
    end
  end

  defp handle_slash_command(name, %Nostrum.Struct.Interaction{} = inter) do
    Logger.warn("slash command #{name} doesn't exist")

    Api.create_interaction_response!(
      inter,
      %{
        type: 4,
        data: %{
          content: "Woops, Major forgot to implement this command",
          flags: 64
        }
      }
    )
  end
end

defmodule BnBBot.Command.State do
  @moduledoc """
  Module for managing the creation state of slash commands
  """

  use Ecto.Schema

  alias BnBBot.Command.Slash.Id, as: CommandId
  alias BnBBot.Repo.SQLite
  alias Nostrum.Api

  import Ecto.Query

  require Logger

  @primary_key false
  schema "created_commands" do
    field :name, :string, primary_key: true
    field :state, :binary
    field :cmd_ids, CommandId
    timestamps()
  end

  @doc false
  def setup_commands(cmd_list) do
    # since placing this in `BnBBot.SlashCommands` causes a circular dependency
    for command <- cmd_list do
      cmd_state = command.get_creation_state()
      {_, cmd_map} = cmd_state
      name = cmd_map[:name]
      res = SQLite.get(__MODULE__, name)

      should_insert =
        case res do
          %__MODULE__{state: state} ->
            :erlang.binary_to_term(state) != cmd_state

          nil ->
            true
        end

      if should_insert do
        Logger.info("inserting command #{name}")
        ids = create_command(cmd_state)

        SQLite.insert!(
          %__MODULE__{name: name, state: :erlang.term_to_binary(cmd_state), cmd_ids: ids},
          on_conflict: {:replace, [:state, :cmd_ids]}
        )
      end
    end
  end

  @doc false
  def delete_commands(cmd_list) do
    for command <- cmd_list do
      {_, cmd_map} = command.get_creation_state()
      name = cmd_map[:name]
      cmd_data = SQLite.get(__MODULE__, name)

      unless is_nil(cmd_data) do
        Logger.info("deleting command #{name}")

        delete_command(cmd_data.cmd_ids)

        from(c in __MODULE__, where: c.name == ^name)
        |> SQLite.delete_all()
      end
    end
  end

  # returns {:global, id} for insertion
  defp create_command({:global, cmd_map}) do
    {:ok, %{id: id}} = Api.create_global_application_command(cmd_map)
    id = Nostrum.Snowflake.cast!(id)
    {:global, id}
  end

  defp create_command({guild_ids, cmd_map}) when is_list(guild_ids) do
    ids =
      Enum.map(guild_ids, fn guild_id ->
        {:ok, %{id: id}} = Api.create_guild_application_command(guild_id, cmd_map)
        id = Nostrum.Snowflake.cast!(id)
        {guild_id, id}
      end)

    {:guild, ids}
  end

  defp create_command({guild_id, cmd_map}) do
    {:ok, %{id: id}} = Api.create_guild_application_command(guild_id, cmd_map)
    id = Nostrum.Snowflake.cast!(id)
    {:guild, [{guild_id, id}]}
  end

  defp delete_command({:global, id}) do
    {:ok} = Api.delete_global_application_command(id)
  end

  defp delete_command({:guild, ids}) do
    for {guild_id, id} <- ids do
      {:ok} = Api.delete_guild_application_command(guild_id, id)
    end
  end
end
