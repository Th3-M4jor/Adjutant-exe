defmodule BnBBot.Library.Battlechip do
  require Logger

  @enforce_keys [
    :id,
    :name,
    :elem,
    :skill,
    :range,
    :hits,
    :targets,
    :description,
    :effect,
    :effduration,
    :blight,
    :damage,
    :kind,
    :class
  ]
  defstruct [
    :id,
    :name,
    :elem,
    :skill,
    :range,
    :hits,
    :targets,
    :description,
    :effect,
    :effduration,
    :blight,
    :damage,
    :kind,
    :class
  ]

  @type class :: :standard | :mega | :giga

  @type t :: %BnBBot.Library.Battlechip{
          id: pos_integer(),
          name: String.t(),
          elem: [BnBBot.Library.Shared.element()],
          skill: [BnBBot.Library.Shared.skill()],
          range: BnBBot.Library.Shared.range(),
          hits: non_neg_integer() | String.t(),
          targets: non_neg_integer(),
          description: String.t(),
          effect: String.t() | nil,
          effduration: non_neg_integer() | nil,
          blight: BnBBot.Library.Shared.blight() | nil,
          damage: BnBBot.Library.Shared.dice() | nil,
          kind: BnBBot.Library.Shared.kind(),
          class: class()
        }

  @spec load_chips :: :http_err | {:ok, non_neg_integer}
  def load_chips() do
    Logger.debug("(Re)loading Chips")

    chip_url = Application.fetch_env!(:elixir_bot, :chip_url)
    resp = HTTPoison.get(chip_url)
    chip_list = decode_chip_resp(resp)

    case chip_list do
      :http_err ->
        :http_err

      chips ->
        chip_map =
          for chip <- chips, reduce: %{} do
            acc ->
              Map.put(acc, String.downcase(chip.name, :ascii), chip)
          end

        len = map_size(chip_map)
        :ets.insert(:bnb_bot_data, chips: chip_map)
        {:ok, len}
    end
  end

  @spec get_chip(String.t()) ::
          {:found, BnBBot.Library.Battlechip.t()}
          | {:not_found, [{float(), BnBBot.Library.Battlechip.t()}]}
  def get_chip(name) do
    lower_name = String.downcase(name, :ascii)

    # returns an empty list if the chip doesn't exist
    chip = :ets.select(:bnb_bot_data, [{{:chips, %{lower_name => :"$1"}}, [], [:"$1"]}])

    case chip do
      [] ->
        [chips: all] = :ets.lookup(:bnb_bot_data, :chips)

        res =
          Map.to_list(all)
          |> Enum.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
          |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
          |> Enum.take(9)

        {:not_found, res}

      [chip] ->
        {:found, chip}
    end
  end

  defp decode_chip_resp({:ok, %HTTPoison.Response{} = resp})
       when resp.status_code in 200..299 do
    maps = :erlang.binary_to_term(resp.body)

    Enum.map(maps, fn ncp -> struct(BnBBot.Library.Battlechip, ncp) end)
  end

  defp decode_chip_resp(_err) do
    :http_err
  end
end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.Battlechip do
  def type(_value), do: :chip

  def to_btn(chip) do
    lower_name = "c_#{String.downcase(chip.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :chip_emoji)

    %{
      type: 2,
      style: 2,
      emoji: emoji,
      label: chip.name,
      custom_id: lower_name
    }
  end
end

defimpl String.Chars, for: BnBBot.Library.Battlechip do

  def to_string(%BnBBot.Library.Battlechip{} = chip) do
    elems = Enum.map(chip.elem, fn elem -> Kernel.to_string(elem) |> String.capitalize() end)
      |> Enum.join(", ")
    skill = String.upcase(Enum.join(chip.skill, ", "), :ascii)
    range = String.capitalize(Kernel.to_string(chip.range), :ascii)
    kind = String.capitalize(Kernel.to_string(chip.kind), :ascii)

    hits = if chip.hits == "1" do
      "1 hit"
    else
      "#{chip.hits} hits"
    end

    targets = if chip.targets == 1 do
      "1 target"
    else
      "#{chip.targets} targets"
    end

    damage = unless is_nil(chip.damage) do
      "#{chip.damage[:dienum]}d#{chip.damage[:dietype]} damage"
    else
      "--"
    end

    class = if chip.class == :standard do
      ""
    else
      " | " <> String.capitalize(Kernel.to_string(chip.class), :ascii)
    end

    "```\n#{chip.name} - #{elems} | #{skill} | #{range} | #{damage} | #{hits} | #{targets} | #{kind}#{class}\n#{chip.description}\n```"
  end

end
