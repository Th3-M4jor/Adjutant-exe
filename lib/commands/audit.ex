defmodule BnBBot.Commands.Audit do
  # alias Nostrum.Api
  require Logger
  import Ecto.Query

  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.info("Got an audit cmd with no args")

    text = get_entries() |> Enum.map(&format_entry/1) |> Enum.join("\n")
    Nostrum.Api.create_message(msg, text)
  end

  def call(%Nostrum.Struct.Message{} = msg, ["id", id]) do
    Logger.info("Got an audit cmd with id")

    id = String.to_integer(id)

    query = from(log in BnBBot.LogLine, where: log.id == ^id)

    text = BnBBot.Repo.one(query) |> format_entry()
    Nostrum.Api.create_message(msg, text)
  end

  def call(%Nostrum.Struct.Message{} = msg, ["count", ct]) do
    Logger.info("Got an audit cmd with count")

    ct = String.to_integer(ct)

    text = get_entries(ct) |> Enum.map(&format_entry/1) |> Enum.join("\n")
    Nostrum.Api.create_message(msg, text)
  end

  def call(%Nostrum.Struct.Message{} = msg, _) do
    Logger.info("Got an audit command with unknown args")

    Nostrum.Api.create_message(msg, "I didn't recognize the args for that one")
  end

  def last_one() do
    BnBBot.LogLine |> last |> BnBBot.Repo.one()
  end

  @spec get_entries(non_neg_integer()) :: [BnBBot.LogLine.t()]
  def get_entries(count \\ 10) do
    query = from(log in BnBBot.LogLine, order_by: [desc: log.id], limit: ^count)
    BnBBot.Repo.all(query)
  end

  defp format_entry(%BnBBot.LogLine{} = line) do
    data = [
      NaiveDateTime.to_string(line.inserted_at),
      " ",
      to_string(line.level),
      ": ",
      line.message
    ]

    IO.iodata_to_binary(data)
  end

  defp format_entry(nil) do
    "No entry with that ID exists"
  end
end
