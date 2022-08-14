defmodule BnBBot.PsychoEffects.Insults do
  @moduledoc """
  Defines the troll insults that the bot can use.
  """
  use Ecto.Schema
  import Ecto.Query

  @type t :: %__MODULE__{
          id: integer(),
          insult: String.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "random_insults" do
    field :insult, :string
    timestamps(updated_at: false)
  end

  @spec add_new!(String.t()) :: __MODULE__.t() | no_return()
  def add_new!(insult) do
    %__MODULE__{insult: insult}
    |> BnBBot.Repo.SQLite.insert!()
  end

  @doc """
  Returns a random insult.

  Raises if the table is empty.
  """
  @spec get_random() :: __MODULE__.t() | no_return()
  def get_random() do
    from(i in __MODULE__,
      limit: 1,
      order_by: fragment("RANDOM()")
    )
    |> BnBBot.Repo.SQLite.one!()
  end
end
