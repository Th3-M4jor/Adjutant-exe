defmodule BnBBot.CommandFn do
  @moduledoc """
  Describes what public functions each module must define
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

  @doc """
  Returns the help data for the command
  """
  @callback help() :: {command_name(), command_perms(), command_desc()}

  @doc """
  Returns just the name of the command
  """
  @callback get_name() :: String.t()

  @doc """
  Returns the full help string for the command
  """
  @callback full_help() :: String.t()

  @doc """
  The command function for the module
  """
  @callback call(%Nostrum.Struct.Message{}, [String.t()]) :: any
end

defmodule BnBBot.SlashCmdFn do
  @moduledoc """
  Describes what public functions each slash command module must define
  """
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
          optional(:choices) => [slash_choices(), ...]
        }

  @typedoc """
  Name must be between 1 and 32 characters long.
  Desc must be between 1 and 100 characters long.
  """
  @type slash_cmd_map :: %{
          required(:type) => 1,
          required(:name) => String.t(),
          required(:description) => String.t(),
          optional(:options) => [slash_opts(), ...]
        }

  @callback call_slash(Nostrum.Struct.Interaction.t()) :: :ignore

  @callback get_create_map() :: slash_cmd_map()
end
