defmodule BnBBot.Commands.Audit do
  @moduledoc """
  Text based command for getting debug/error log information.
  """

  # alias Nostrum.Api
  require Logger
  import Ecto.Query

  def call(%Nostrum.Struct.Message{} = msg, []) do
    Logger.info("Got an audit cmd with no args")

    # |> Enum.join("\n")
    {_, acc, _} =
      get_entries() |> Enum.map(&format_entry/1) |> Enum.reduce({msg, [], 0}, &join_entries/2)

    text = :erlang.iolist_to_binary(acc)

    Nostrum.Api.create_message!(msg, text)
  end

  def call(%Nostrum.Struct.Message{} = msg, ["id", id]) do
    Logger.info("Got an audit cmd with id")

    id = String.to_integer(id)

    query = from(log in BnBBot.LogLine, where: log.id == ^id)

    text = BnBBot.Repo.SQLite.one(query) |> format_entry()
    Nostrum.Api.create_message(msg, text)
  end

  def call(%Nostrum.Struct.Message{} = msg, ["count", ct]) do
    Logger.info("Got an audit cmd with count")

    ct = String.to_integer(ct)

    text = get_entries(ct) |> Enum.map(&format_entry/1) |> IO.iodata_to_binary()
    Nostrum.Api.create_message(msg, text)
  end

  def call(%Nostrum.Struct.Message{} = msg, ["dump"]) do
    Logger.info("Got an audit cmd for \"dump\"")
    Task.start(fn -> Nostrum.Api.start_typing(msg.channel_id) end)

    # text =
    #  BnBBot.Repo.SQLite.all(BnBBot.LogLine) |> Enum.map(&format_entry/1) |> Enum.intersperse("\n\n")

    dump_log()

    Nostrum.Api.create_message(msg, %{
      content: "Dumped log to log_dump.txt",
      files: ["log_dump.txt"]
    })
  end

  def call(%Nostrum.Struct.Message{} = msg, _) do
    Logger.info("Got an audit command with unknown args")

    Nostrum.Api.create_message(msg, "I didn't recognize the args for that one")
  end

  def last_one do
    BnBBot.LogLine |> last |> BnBBot.Repo.SQLite.one()
  end

  @spec get_entries(non_neg_integer()) :: [BnBBot.LogLine.t()]
  def get_entries(count \\ 10) do
    query = from(log in BnBBot.LogLine, order_by: [desc: log.id], limit: ^count)
    BnBBot.Repo.SQLite.all(query) |> Enum.reverse()
  end

  def get_formatted(count \\ 10) do
    query = from(log in BnBBot.LogLine, order_by: [desc: log.id], limit: ^count)
    BnBBot.Repo.SQLite.all(query) |> Enum.reverse() |> Enum.map(&format_entry/1)
  end

  def dump_log do
    file_ptr = File.open!("log_dump.txt", [:write, :delayed_write, :utf8])

    line_stream =
      BnBBot.Repo.SQLite.stream(BnBBot.LogLine)
      |> Stream.map(&format_entry/1)
      |> Stream.intersperse("\n\n")
      |> Stream.each(fn x ->
        IO.write(file_ptr, x)
        x
      end)

    # streams must happen in a transaction
    BnBBot.Repo.SQLite.transaction(fn ->
      Stream.run(line_stream)
    end)

    :ok = File.close(file_ptr)
  end

  defp format_entry(%BnBBot.LogLine{} = line) do
    [
      NaiveDateTime.to_string(line.inserted_at),
      " ",
      to_string(line.level),
      ": ",
      line.message,
      "\n"
    ]
  end

  defp format_entry(nil) do
    "No entry with that ID exists"
  end

  defp join_entries(elem, {msg, acc, acc_len}) do
    elem_len = :erlang.iolist_size(elem)

    if elem_len + acc_len > 1950 do
      text = :erlang.iolist_to_binary(acc)
      Nostrum.Api.create_message!(msg, text)
      {msg, [elem, "\n"], elem_len + 1}
    else
      {msg, [acc, elem, "\n"], acc_len + elem_len + 1}
    end
  end
end
