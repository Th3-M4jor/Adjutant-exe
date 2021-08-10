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
          color: String.t(),
          description: String.t()
        }

  @spec load_ncps() :: {:ok, non_neg_integer()} | :http_err
  def load_ncps() do
    Logger.debug("(Re)loading NCPs")
    ncp_url = Application.fetch_env!(:elixir_bot, :ncp_url)
    resp = HTTPoison.get(ncp_url)
    ncp_list = decode_ncp_resp(resp)

    case ncp_list do
      :http_err ->
        :http_err

      ncps ->
        ncp_map =
          for ncp <- ncps, reduce: %{} do
            acc ->
              Map.put(acc, String.downcase(ncp.name, :ascii), ncp)
          end

        len = map_size(ncp_map)
        :ets.insert(:bnb_bot_data, ncps: ncp_map)
        {:ok, len}
    end
  end

  @spec get_ncp(String.t()) ::
          {:found, __MODULE__.t()} | {:not_found, [{float(), __MODULE__.t()}]}
  def get_ncp(name) do
    lower_name = String.downcase(name, :ascii)

    # returns an empty list if no match
    ncp = :ets.select(:bnb_bot_data, [{{:ncps, %{lower_name => :"$1"}}, [], [:"$1"]}])

    case ncp do
      [] ->
        [ncps: all] = :ets.lookup(:bnb_bot_data, :ncps)

        res =
          Map.to_list(all)
          |> Enum.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
          |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
          |> Enum.take(9)

        {:not_found, res}

      # "No NCP with that name"
      [ncp] ->
        {:found, ncp}

        # "```\n#{val["Name"]} - (#{val["EBCost"]} EB) - #{val["Color"]}\n#{val["Description"]}\n```"
    end
  end

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

  @spec decode_ncp_resp({:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}) ::
          :http_err | [__MODULE__.t()] | no_return()
  defp decode_ncp_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    maps = Poison.Parser.parse!(resp.body, keys: :atoms)

    Enum.map(maps, fn ncp ->
      color = String.to_atom(ncp[:color])
      ncp_map = Map.put(ncp, :color, color)
      struct(BnBBot.Library.NCP, ncp_map)
    end)
  end

  defp decode_ncp_resp(_) do
    :http_err
  end
end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.NCP do
  def type(_value), do: :ncp

  @spec to_btn(BnBBot.Library.NCP.t()) :: BnBBot.Library.LibObj.button()
  def to_btn(ncp) do
    lower_name = "n_#{String.downcase(ncp.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :ncp_emoji)

    %{
      # type 2 for button
      type: 2,

      # style 3 for green button
      style: 3,
      emoji: emoji,
      label: ncp.name,
      custom_id: lower_name
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
