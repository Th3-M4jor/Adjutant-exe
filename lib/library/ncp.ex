defmodule BnBBot.Library.NCP do
  require Logger

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
            acc -> Map.put(acc, String.downcase(ncp["Name"], :ascii), ncp)
          end

        len = map_size(ncp_map)
        :ets.insert(:bnb_bot_data, ncps: ncp_map)
        {:ok, len}
    end
  end

  @spec get_ncp(String.t()) :: {:found, map()} | {:not_found, [{float(), map()}]}
  def get_ncp(name) do
    [ncps: all] = :ets.lookup(:bnb_bot_data, :ncps)
    lower_name = String.downcase(name, :ascii)
    case Map.get(all, lower_name) do
      nil ->
        res = Map.to_list(all)
        |> Enum.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
        |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
        |> Enum.take(9)
        {:not_found, res}
        #"No NCP with that name"
      val ->
        {:found, val}
        #"```\n#{val["Name"]} - (#{val["EBCost"]} EB) - #{val["Color"]}\n#{val["Description"]}\n```"
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
