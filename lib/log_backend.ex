defmodule BnBBot.LogLine do
  use Ecto.Schema

  @type t :: %__MODULE__{
          level: :debug | :info | :notice | :warn | :error | :critical | :alert | :emergency,
          message: String.t(),
          inserted_at: NaiveDateTime.t()
        }

  schema "bot_log" do
    field(:level, Ecto.Enum,
      values: [:debug, :info, :notice, :warn, :error, :critical, :alert, :emergency]
    )

    field(:message, :string)
    timestamps(updated_at: false)
    # field(:inserted_at, :naive_datetime)
  end
end

defmodule BnBBot.LogBackend do
  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event(
        {level, _group_leader, {Logger, message, _timestamp, _metadata}},
        %{level: min_level, online: false} = state
      ) do
    # just drop the message if repo is offline, but check each time
    try do
      state =
        if Ecto.Repo.all_running() |> Enum.member?(BnBBot.Repo) do
          if right_log_level?(min_level, level) do
            msg = IO.chardata_to_string(message)

            line = %BnBBot.LogLine{
              level: level,
              message: msg
            }

            BnBBot.Repo.insert(line)
          end

          Map.put(state, :online, true)
        else
          state
        end

      {:ok, state}
    rescue
      _ ->
        {:ok, state}
    end
  end

  def handle_event(
        {level, _group_leader, {Logger, message, _timestamp, _metadata}},
        %{level: min_level} = state
      ) do
    if right_log_level?(min_level, level) do
      msg = IO.chardata_to_string(message)

      line = %BnBBot.LogLine{
        level: level,
        message: msg
      }

      BnBBot.Repo.insert(line)
    end

    {:ok, state}
  end

  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end

  defp configure(name, []) do
    base_level = Application.get_env(:logger, :level, :debug)

    Application.get_env(:logger, name, [])
    |> Enum.into(%{name: name, level: base_level, online: false})
  end

  defp configure(_name, [level: new_level], state) do
    Map.merge(state, %{level: new_level})
  end

  defp configure(_name, _opts, state), do: state

  defp right_log_level?(nil, _level), do: true

  defp right_log_level?(min_level, level) do
    Logger.compare_levels(level, min_level) != :lt
  end
end
