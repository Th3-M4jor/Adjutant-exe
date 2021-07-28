defmodule BnBBot.Library.NCP do
  require Logger

  alias __MODULE__

  @enforce_keys [:id, :name, :cost, :color, :description]
  defstruct [:id, :name, :cost, :color, :description]

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          cost: pos_integer(),
          color: String.t(),
          description: String.t()
        }

  @spec load_ncps() :: {:ok, non_neg_integer()} | :http_err | :parse_err
  def load_ncps() do
    Logger.debug("(Re)loading NCPs")
    ncp_url = Application.fetch_env!(:elixir_bot, :ncp_url)
    resp = HTTPoison.get(ncp_url)
    ncp_list = decode_ncp_resp(resp)

    case ncp_list do
      :http_err ->
        :http_err

      :parse_err ->
        :parse_err

      ncps ->
        ncp_map =
          for ncp <- ncps, reduce: %{} do
            acc ->
              ncp_struct = %NCP{
                id: ncp["Id"],
                name: ncp["Name"],
                cost: ncp["EBCost"],
                color: ncp["Color"],
                description: ncp["Description"]
              }

              Map.put(acc, String.downcase(ncp["Name"], :ascii), ncp_struct)
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

  @spec decode_ncp_resp({:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}) ::
          :http_err | :parse_err | any()
  defp decode_ncp_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    case Poison.decode(resp.body) do
      {:ok, values} ->
        values

      {:error, _} ->
        :parse_err
    end
  end

  defp decode_ncp_resp(_) do
    :http_err
  end
end

defimpl String.Chars, for: BnBBot.Library.NCP do
  @spec to_string(BnBBot.Library.NCP.t()) :: String.t()
  def to_string(%BnBBot.Library.NCP{} = ncp) do
    "```\n#{ncp.name} - (#{ncp.cost} EB) - #{ncp.color}\n#{ncp.description}\n```"
  end
end
