defmodule BnBBot.CommandFn do
  @moduledoc """
  Defines the behaviour to be used by text based commands.
  """

  @typedoc """
  Who can use the command?
  """
  @type command_perms :: :everyone | :admin | :owner

  @typedoc """
  The name of the command
  """
  @type command_name :: String.t()

  @typedoc """
  The description of the command
  """
  @type command_desc :: String.t()
end

defmodule BnBBot.SlashCmdFn do
  @moduledoc """
  Describes what public functions each slash command module must define

  All slash commands must implement the callbacks defined here, and may optionally `use`
  this module to define a `call` function that will be called when the command is executed.

  ```elixir
  use BnBBot.SlashCmdFn, permissions: :everyone
  ```

  When `use`d, the macro expects a `:permissions` option, which defines who can use the command.
  This option expects either a single `:everyone`, `:admin`, or `:owner` value or a list of such values.
  """

  defp everyone_perms do
    quote do
      @behaviour BnBBot.SlashCmdFn
      def call(inter), do: call_slash(inter)

      defoverridable call: 1
    end
  end

  defp list_perms(perms) when is_list(perms) do
    quote do
      @behaviour BnBBot.SlashCmdFn
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
      @behaviour BnBBot.SlashCmdFn
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

  defmacro __using__(opts) do
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

  @callback call_slash(Nostrum.Struct.Interaction.t()) :: :ignore

  @callback get_create_map() :: slash_cmd_map()
end
