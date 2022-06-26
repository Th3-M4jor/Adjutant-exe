defmodule BnBBot.Command.Slash do
  @moduledoc """
  Describes what public functions each slash command module must define

  All slash commands must implement the callbacks defined here, and may optionally `use`
  this module to define a `call` function that will be called when the command is executed.

  ```elixir
  use BnBBot.Command.Slash, permissions: :everyone
  ```

  When `use`d, the macro expects a `:permissions` option, which defines who can use the command.
  This option expects either a single `:everyone`, `:admin`, or `:owner` value or a list of such values.

  There is also an optional `:scope` argument that can be used to determine the scope of the command
  when it is created.

  Scope can be one of:
  - `:global`: The command is created globally.
  - `Nostrum.Snowflake.t()`: The command is created in only the guild with the given ID.
  - [`Nostrum.Snowflake.t(), ...`]: The command is created in all guilds with the given IDs.

  By default, the command follows the `:default_command_scope` config option.

  this setting in config can either be `:global`, a guild_id or a list of guild_ids

  Note about scope: If you are changing a command's scope from `:global` to a guild, or vice versa,
  you must manually remove the command from the old scope.
  """

  @default_command_scope Application.compile_env!(:elixir_bot, :default_command_scope)

  defp everyone_perms do
    quote do
      @behaviour BnBBot.Command.Slash
      def call(inter), do: call_slash(inter)

      defoverridable call: 1
    end
  end

  defp list_perms(perms) when is_list(perms) do
    quote do
      @behaviour BnBBot.Command.Slash
      def call(inter) do
        user_perms = BnBBot.Util.get_user_perms(inter)

        if user_perms in unquote(perms) do
          call_slash(inter)
        else
          Nostrum.Api.create_interaction_response(inter, %{
            type: 4,
            data: %{
              content: "You don't have permission to do that",
              flags: 64
            }
          })
        end
      end

      defoverridable call: 1
    end
  end

  defp atom_perms(perm) when perm in [:owner, :admin] do
    quote do
      @behaviour BnBBot.Command.Slash
      def call(inter) do
        user_perms = BnBBot.Util.get_user_perms(inter)

        if user_perms == unquote(perm) do
          call_slash(inter)
        else
          Nostrum.Api.create_interaction_response(inter, %{
            type: 4,
            data: %{
              content: "You don't have permission to do that",
              flags: 64
            }
          })
        end
      end

      defoverridable call: 1
    end
  end

  defp creation_state(creation_config) do
    quote do
      def get_creation_state do
        cmd_map = get_create_map()
        {unquote(creation_config), cmd_map}
      end
    end
  end

  defmacro __using__(opts) do
    perms_fn =
      case opts[:permissions] do
        :everyone ->
          everyone_perms()

        [first, second] = perms when first in [:admin, :owner] and second in [:admin, :owner] ->
          list_perms(perms)

        perms when perms in [:admin, :owner] ->
          atom_perms(perms)

        _ ->
          raise "\":permissions\" option must be either :everyone, :admin, :owner or a list of [:admin, :owner]"
      end

    creation_fn_arg = opts[:scope] || @default_command_scope

    creation_fn = creation_state(creation_fn_arg)
    [perms_fn, creation_fn]
  end

  @typedoc """
  The name of the command
  """
  @type command_name :: String.t()

  @typedoc """
  The description of the command
  """
  @type command_desc :: String.t()

  @typedoc """
  The list of choices for a command's args, cannot be more than 25 choices per arg
  """
  @type slash_choices :: %{
          :name => String.t(),
          :value => String.t() | number()
        }

  @typedoc """
  The different kinds for a command's args
  ```
  1: SUB_COMMAND
  2: SUB_COMMAND_GROUP
  3: String,
  4: Integer,
  5: Boolean,
  6: User,
  7: Channel,
  8: Role,
  9: Mentionable,
  10: Number
  ```
  """
  @type slash_option_type :: 1..10

  @typedoc """
  What a commands options must look like,
  required choices must be before optional ones.
  Name must be between 1 and 32 characters long.
  Desc must be between 1 and 100 characters long.
  """
  @type slash_opts :: %{
          required(:type) => slash_option_type(),
          required(:name) => String.t(),
          required(:description) => String.t(),
          optional(:required) => boolean(),
          optional(:choices) => [slash_choices(), ...],
          optional(:options) => [slash_opts(), ...],
          optional(:autocomplete) => boolean()
        }

  @typedoc """
  Name must be between 1 and 32 characters long.
  Desc must be between 1 and 100 characters long.
  """
  @type slash_cmd_map :: %{
          required(:name) => String.t(),
          required(:description) => String.t(),
          optional(:type) => 1..3,
          optional(:dm_permission) => boolean(),
          optional(:default_member_permission) => String.t(),
          optional(:options) => [slash_opts(), ...]
        }

  @type creation_state ::
          {[Nostrum.Snowflake.t()] | Nostrum.Snowflake.t() | :global, slash_cmd_map()}

  @callback call_slash(Nostrum.Struct.Interaction.t()) :: :ignore

  @callback get_create_map() :: slash_cmd_map()

  @callback get_creation_state() :: creation_state()
end

defmodule BnBBot.Command.Slash.Id do
  @moduledoc """
  Module that defines how slash command Ids are stored and retrieved from the DB to handle
  deletion.
  """

  use Ecto.Type
  import Nostrum.Snowflake, only: [is_snowflake: 1]
  alias Nostrum.Snowflake

  def type, do: :binary

  def cast({:global, id}) when is_snowflake(id) do
    {:ok, {:global, id}}
  end

  def cast({:global, id}) when id != nil do
    case Snowflake.cast(id) do
      {:ok, id} ->
        {:ok, {:global, id}}

      :error ->
        :error
    end
  end

  def cast(id) when is_snowflake(id) do
    # assume its a global id
    IO.warn("Attempted to cast an untagged snowflake as a cmd_id, assuming it's a global id")
    {:ok, {:global, id}}
  end

  def cast({:guild, guild_id, id}) when is_snowflake(id) and is_snowflake(guild_id) do
    {:ok, {:guild, [{guild_id, id}]}}
  end

  def cast({:guild, ids}) when is_list(ids) do
    ids =
      for {guild_id, id} <- ids do
        case {Snowflake.cast(guild_id), Snowflake.cast(id)} do
          {{:ok, guild_id}, {:ok, id}} ->
            {guild_id, id}

          _ ->
            :error
        end
      end

    if Enum.any?(ids, fn id -> id == :error end) do
      :error
    else
      {:ok, {:guild, ids}}
    end
  end

  def load(id_data) when is_binary(id_data) do
    case :erlang.binary_to_term(id_data) do
      {:global, id} when is_snowflake(id) ->
        {:ok, {:global, id}}

      {:guild, ids} when is_list(ids) ->
        {:ok, {:guild, ids}}
    end
  end

  def dump({:guild, ids} = data) when is_list(ids) do
    {:ok, :erlang.term_to_binary(data)}
  end

  def dump({:global, id} = data) when is_snowflake(id) do
    {:ok, :erlang.term_to_binary(data)}
  end
end
