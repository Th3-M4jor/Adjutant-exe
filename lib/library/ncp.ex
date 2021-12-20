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

  @spec get_or_nil(String.t()) :: BnBBot.Library.NCP.t() | nil
  def get_or_nil(name) do
    GenServer.call(:ncp_table, {:get_or_nil, name})
  end

  @spec get!(String.t()) :: BnBBot.Library.NCP.t()
  def get!(name) do
    res = GenServer.call(:ncp_table, {:get_or_nil, name})

    unless is_nil(res) do
      res
    else
      raise "NCP not found: #{name}"
    end
  end

  @spec get_autocomplete(String.t(), float()) :: [{float(), String.t()}]
  def get_autocomplete(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:ncp_table, {:autocomplete, name, min_dist})
  end

  @spec get_starters([colors()]) :: [t()]
  def get_starters(colors) do
    GenServer.call(:ncp_table, {:starters, colors})
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
  def ncp_color_to_string(ncp) do
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

  @spec ncp_color_to_sort_number(BnBBot.Library.NCP.t()) :: non_neg_integer()
  def ncp_color_to_sort_number(ncp) do
    case ncp.color do
      :white -> 0
      :pink -> 1
      :yellow -> 2
      :green -> 3
      :blue -> 4
      :red -> 5
      :gray -> 6
    end
  end

  @spec element_to_colors(BnBBot.Library.Shared.element()) :: [colors()]
  def element_to_colors(element) do
    case element do
      :fire ->
        [:white, :pink, :yellow, :blue, :gray]

      :aqua ->
        [:white, :pink, :yellow, :blue, :red]

      :elec ->
        [:white, :pink, :yellow, :green, :blue]

      :wood ->
        [:white, :pink, :yellow, :green, :red]

      :wind ->
        [:white, :pink, :yellow, :blue, :gray]

      :sword ->
        [:white, :pink, :yellow, :green, :red]

      :break ->
        [:white, :pink, :yellow, :green, :red]

      :cursor ->
        [:white, :pink, :yellow, :blue, :gray]

      :recov ->
        [:white, :pink, :yellow, :blue, :red]

      :invis ->
        [:white, :pink, :yellow, :green, :gray]

      :object ->
        [:white, :pink, :yellow, :red, :gray]

      :null ->
        [:white, :pink, :yellow, :green, :blue, :red, :gray]
    end
  end
end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.NCP do
  @white_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :white])
  @pink_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :pink])
  @yellow_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :yellow])
  @green_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :green])
  @blue_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :blue])
  @red_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :red])
  @gray_emoji :elixir_bot |> Application.compile_env!([:ncp_emoji, :gray])

  def type(_value), do: :ncp

  @spec to_btn(BnBBot.Library.NCP.t(), boolean()) :: BnBBot.Library.LibObj.button()
  def to_btn(ncp, disabled \\ false) do
    lower_name = "n_#{String.downcase(ncp.name, :ascii)}"
    emoji = ncp_color_to_emoji(ncp.color)

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
    emoji = ncp_color_to_emoji(ncp.color)

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
    emoji = ncp_color_to_emoji(ncp.color)

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

  @spec ncp_color_to_emoji(BnBBot.Library.NCP.colors()) :: map()
  defp ncp_color_to_emoji(color) do
    case color do
      :white -> @white_emoji
      :pink -> @pink_emoji
      :yellow -> @yellow_emoji
      :green -> @green_emoji
      :blue -> @blue_emoji
      :red -> @red_emoji
      :gray -> @gray_emoji
    end
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
  alias BnBBot.Library.NCP

  @ncp_url :elixir_bot |> Application.compile_env!(:ncp_url)
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
          res = BnBBot.Library.Shared.gen_suggestions(state, name, min_dist)

          {:not_found, res}

        ncp ->
          {:found, ncp}
      end

    {:reply, resp, state}
  end

  @impl true
  @spec handle_call({:get_or_nil, String.t()}, GenServer.from(), map()) ::
          {:reply, BnBBot.Library.NCP.t() | nil, map()}
  def handle_call({:get_or_nil, name}, _from, state) do
    lower_name = String.downcase(name, :ascii)

    {:reply, state[lower_name], state}
  end

  @spec handle_call({:autocomplete, String.t(), float()}, GenServer.from(), map()) ::
          {:reply, [{float(), String.t()}], map()}
  def handle_call({:autocomplete, name, min_dist}, from, state) do
    vals =
      Map.to_list(state)
      |> Enum.map(fn {k, v} ->
        {k, v.name}
      end)

    Task.start(BnBBot.Library.Shared, :return_autocomplete, [from, vals, name, min_dist])

    # res = BnBBot.Library.Shared.gen_autocomplete(state, name, min_dist)

    {:noreply, state}
  end

  @spec handle_call({:color, String.t()}, GenServer.from(), map()) ::
          {:reply, [BnBBot.Library.NCP.t()], map()}
  def handle_call({:color, color}, _from, state) do
    resp =
      Map.values(state)
      |> Stream.filter(fn ncp -> ncp.color == color end)
      |> Enum.sort_by(fn ncp -> ncp.name end)

    {:reply, resp, state}
  end

  @spec handle_call({:starters, [BnBBot.Library.NCP.colors()]}, GenServer.from(), map()) ::
          {:reply, [NCP.t()], map()}
  def handle_call({:starters, colors}, _from, state) do
    resp =
      Map.values(state)
      |> Stream.filter(fn ncp -> Enum.member?(colors, ncp.color) and ncp.cost <= 2 end)
      |> Enum.sort_by(fn ncp -> {NCP.ncp_color_to_sort_number(ncp), ncp.name} end)

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
    resp = HTTPoison.get(@ncp_url)

    case decode_ncp_resp(resp) do
      {:http_err, reason} ->
        {:error, reason}

      {:ok, ncps} ->
        {:ok, ncps}
    end
  end

  @spec decode_ncp_resp({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          {:ok, map()} | {:http_err, String.t()}
  defp decode_ncp_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    data_list = Jason.decode!(resp.body, keys: :atoms, strings: :copy)

    ncp_map =
      for ncp <- data_list, into: %{} do
        color = String.to_atom(ncp[:color])
        lower_name = String.downcase(ncp[:name], :ascii)
        ncp_map = Map.put(ncp, :color, color)
        {lower_name, struct(BnBBot.Library.NCP, ncp_map)}
      end

    # maps =
    #  Jason.decode!(resp.body, keys: :atoms, strings: :copy)
    #  |> Enum.map(fn ncp ->
    #    color = String.to_atom(ncp[:color])
    #    lower_name = String.downcase(ncp[:name], :ascii)
    #    ncp_map = Map.put(ncp, :color, color)
    #    {lower_name, struct(BnBBot.Library.NCP, ncp_map)}
    #  end)

    {:ok, ncp_map}
  end

  defp decode_ncp_resp({:ok, %HTTPoison.Response{} = resp}) do
    {:http_err, "Got http status code #{resp.status_code}"}
  end

  defp decode_ncp_resp({:error, %HTTPoison.Error{} = err}) do
    {:http_err, "Got http error #{err.reason}"}
  end
end
