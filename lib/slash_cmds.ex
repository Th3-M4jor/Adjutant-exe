defmodule BnBBot.SlashCommands do
  @moduledoc """
  Module for creating and performing dispatch on slash commands
  """

  alias BnBBot.Commands
  alias Nostrum.Api

  require Logger

  @commands [
    Commands.Dice,
    Commands.Ping,
    Commands.Shuffle,
    Commands.PHB,
    Commands.NCP,
    Commands.Chip,
    Commands.Virus,
    Commands.Statuses,
    Commands.Blight,
    Commands.Panels,
    Commands.Reload,
    Commands.Groups,
    Commands.Hidden,
    Commands.Create,
    Commands.RemindMe,
    Commands.Team
  ]

  def setup_commands do
    BnBBot.SlashCommands.CreationState.setup_commands(@commands)
  end

  @doc """
  Dispatch functionality on slash commands, including autocomplete, its up the callee to differentiate
  """
  @spec handle_command(Nostrum.Struct.Interaction.t()) :: any
  def handle_command(%Nostrum.Struct.Interaction{} = inter) do
    handle_slash_command(inter.data.name, inter)
  end

  # Generate the command handlers at compile time.
  for cmd <- @commands, Code.ensure_compiled!(cmd) do
    name = cmd.get_create_map()[:name]
    true = function_exported?(cmd, :call, 1)
    true = function_exported?(cmd, :call_slash, 1)

    defp handle_slash_command(unquote(name), %Nostrum.Struct.Interaction{} = inter) do
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

defmodule BnBBot.SlashCommands.CreationState do
  @moduledoc """
  Module for managing the creation state of slash commands
  """

  use Ecto.Schema

  alias BnBBot.Repo.SQLite
  alias Nostrum.Api

  require Logger

  @primary_key false
  schema "created_commands" do
    field :name, :string, primary_key: true
    field :state, :binary
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
        create_command(cmd_state)

        SQLite.insert!(
          %__MODULE__{name: name, state: :erlang.term_to_binary(cmd_state)},
          on_conflict: {:replace, [:state]}
        )
      end
    end
  end

  defp create_command({:global, cmd_map}) do
    {:ok, _} = Api.create_global_application_command(cmd_map)
  end

  defp create_command({guild_ids, cmd_map}) when is_list(guild_ids) do
    Enum.map(guild_ids, fn guild_id ->
      {:ok, _} = Api.create_guild_application_command(guild_id, cmd_map)
    end)
  end

  defp create_command({guild_id, cmd_map}) do
    {:ok, _} = Api.create_guild_application_command(guild_id, cmd_map)
  end
end
