defmodule BnBBot.Library.NCP do
  require Logger

  @enforce_keys [:id, :name, :cost, :color, :description]
  @derive [Inspect]
  defstruct [:id, :name, :cost, :color, :description]

  @type colors :: :white | :pink | :yellow | :green | :blue | :red | :gray

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          cost: pos_integer(),
          color: colors(),
          description: String.t()
        }

  @spec load_ncps() :: {:ok} | {:error, String.t()}
  def load_ncps() do
    GenServer.call(:ncp_table, :reload, :infinity)
  end

  @spec get_ncp(String.t(), float()) ::
          {:found, t()} | {:not_found, [{float(), t()}]}
  def get_ncp(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:ncp_table, {:get, name, min_dist})
  end

  @spec get_autocomplete(String.t(), float()) :: [{float(), String.t()}]
  def get_autocomplete(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:ncp_table, {:autocomplete, name, min_dist})
  end

  @spec get_ncps_by_color(colors()) :: [t()]
  def get_ncps_by_color(color) do
    GenServer.call(:ncp_table, {:color, color})
  end

  @spec get_ncp_ct() :: non_neg_integer()
  def get_ncp_ct() do
    GenServer.call(:ncp_table, :len, :infinity)
  end

  @spec ncp_color_to_string(BnBBot.Library.NCP.t()) :: String.t()
  def ncp_color_to_string(%BnBBot.Library.NCP{} = ncp) do
    case ncp.color do
      :white -> "White"
      :pink -> "Pink"
      :yellow -> "Yellow"
      :green -> "Green"
      :blue -> "Blue"
      :red -> "Red"
      :gray -> "Gray"
    end
  end
end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.NCP do
  def type(_value), do: :ncp

  @spec to_btn(BnBBot.Library.NCP.t(), boolean()) :: BnBBot.Library.LibObj.button()
  def to_btn(ncp, disabled \\ false) do
    lower_name = "n_#{String.downcase(ncp.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :ncp_emoji)

    %{
      # type 2 for button
      type: 2,

      # style 3 for green button
      style: 3,
      emoji: emoji,
      label: ncp.name,
      custom_id: lower_name,
      disabled: disabled
    }
  end

  @spec to_btn_with_uuid(BnBBot.Library.NCP.t(), boolean(), pos_integer()) ::
          BnBBot.Library.LibObj.button()
  def to_btn_with_uuid(ncp, disabled \\ false, uuid) do
    lower_name = "#{uuid}_n_#{String.downcase(ncp.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :ncp_emoji)

    %{
      # type 2 for button
      type: 2,

      # style 3 for green button
      style: 3,
      emoji: emoji,
      label: ncp.name,
      custom_id: lower_name,
      disabled: disabled
    }
  end

  @spec to_persistent_btn(BnBBot.Library.NCP.t(), boolean()) :: BnBBot.Library.LibObj.button()
  def to_persistent_btn(ncp, disabled \\ false) do
    lower_name = "nr_#{String.downcase(ncp.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :ncp_emoji)

    %{
      # type 2 for button
      type: 2,

      # style 3 for green button
      style: 3,
      emoji: emoji,
      label: ncp.name,
      custom_id: lower_name,
      disabled: disabled
    }
  end
end

defimpl String.Chars, for: BnBBot.Library.NCP do
  def to_string(%BnBBot.Library.NCP{} = ncp) do
    # Same as but faster due to how Elixir works
    # "```\n#{ncp.name} - (#{ncp.cost} EB) - #{ncp.color}\n#{ncp.description}\n```"

    io_list = [
      "```\n",
      ncp.name,
      " - (",
      Kernel.to_string(ncp.cost),
      " EB) - ",
      BnBBot.Library.NCP.ncp_color_to_string(ncp),
      "\n",
      ncp.description,
      "\n```"
    ]

    IO.chardata_to_string(io_list)
  end
end

defmodule BnBBot.Library.NCPTable do
  require Logger
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :ncp_table)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :reload}}
    # state = load_ncps()
    # case load_ncps() do
    #  {:ok, ncps} ->
    #    {:ok, ncps}
    #  {:error, reason} ->
    #    Logger.warn("Failed to load NCPS: #{reason}")
    #    {:ok, %{}}
    # end
  end

  @impl true
  def handle_continue(:reload, _state) do
    case load_ncps() do
      {:ok, ncps} ->
        {:noreply, ncps}

      {:error, reason} ->
        Logger.warn("Failed to load NCPS: #{reason}")
        {:noreply, %{}}
    end
  end

  @impl true
  @spec handle_call({:get, String.t(), float()}, GenServer.from(), map()) ::
          {:reply,
           {:found, BnBBot.Library.NCP.t()} | {:not_found, [{float(), BnBBot.Library.NCP.t()}]},
           map()}
  def handle_call({:get, name, min_dist}, _from, state) do
    lower_name = String.downcase(name, :ascii)

    resp =
      case state[lower_name] do
        nil ->
          res =
            Map.to_list(state)
            |> Enum.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
            |> Enum.filter(fn {dist, _} -> dist >= min_dist end)
            |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
            |> Enum.take(25)

          {:not_found, res}

        ncp ->
          {:found, ncp}
      end

    {:reply, resp, state}
  end

  @spec handle_call({:autocomplete, String.t(), float()}, GenServer.from(), map()) ::
          {:reply, [{float(), String.t()}], map()}
  def handle_call({:autocomplete, name, min_dist}, _from, state) do
    lower_name = String.downcase(name, :ascii)

    list = Map.to_list(state)

    list =
      :lists.filtermap(
        fn {key, value} ->
          dist = String.jaro_distance(key, lower_name)

          if dist >= min_dist do
            {true, {dist, value.name}}
          else
            false
          end
        end,
        list
      )
      |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
      |> Enum.take(25)

    {:reply, list, state}
  end

  @spec handle_call({:color, String.t()}, GenServer.from(), map()) ::
          {:reply, [BnBBot.Library.NCP.t()], map()}
  def handle_call({:color, color}, _from, state) do
    resp =
      Map.values(state)
      |> Enum.filter(fn ncp -> ncp.color == color end)
      |> Enum.sort_by(fn ncp -> ncp.name end)

    {:reply, resp, state}
  end

  @spec handle_call(:reload, GenServer.from(), map()) ::
          {:reply, {:ok} | {:error, String.t()}, map()}
  def handle_call(:reload, _from, _state) do
    case load_ncps() do
      {:ok, ncps} ->
        {:reply, {:ok}, ncps}

      {:error, reason} ->
        {:reply, {:error, reason}, Map.new()}
    end
  end

  @spec handle_call(:len, GenServer.from(), map()) :: {:reply, non_neg_integer(), map()}
  def handle_call(:len, _from, state) do
    size = map_size(state)
    {:reply, size, state}
  end

  defp load_ncps() do
    Logger.info("(Re)loading NCPs")
    ncp_url = Application.fetch_env!(:elixir_bot, :ncp_url)
    resp = HTTPoison.get(ncp_url)

    case decode_ncp_resp(resp) do
      {:http_err, reason} ->
        {:error, reason}

      {:ok, ncps} ->
        {:ok, Map.new(ncps)}
    end
  end

  @spec decode_ncp_resp({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          {:ok, [{String.t(), BnBBot.Library.NCP.t()}]} | {:http_err, String.t()}
  defp decode_ncp_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    maps = Poison.Parser.parse!(resp.body, keys: :atoms)

    maps =
      Enum.map(maps, fn ncp ->
        color = String.to_atom(ncp[:color])
        lower_name = String.downcase(ncp[:name], :ascii)
        ncp_map = Map.put(ncp, :color, color)
        {lower_name, struct(BnBBot.Library.NCP, ncp_map)}
      end)

    {:ok, maps}
  end

  defp decode_ncp_resp({:ok, %HTTPoison.Response{} = resp}) do
    {:http_err, "Got http status code #{resp.status_code}"}
  end

  defp decode_ncp_resp({:error, %HTTPoison.Error{} = err}) do
    {:http_err, "Got http error #{err.reason}"}
  end
end
