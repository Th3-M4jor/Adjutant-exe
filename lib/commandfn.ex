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
