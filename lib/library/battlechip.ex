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
  @derive [Inspect]
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
    maps = Poison.Parser.parse!(resp.body, keys: :atoms)

    Enum.map(maps, fn chip ->
      elem = chip[:elem] |> string_list_to_atoms()
      skill = chip[:skill] |> string_list_to_atoms()
      range = chip[:range] |> String.to_atom()
      kind = chip[:kind] |> String.to_atom()
      class = chip[:class] |> String.to_atom()
      %BnBBot.Library.Battlechip{
        id: chip[:id],
        name: chip[:name],
        elem: elem,
        skill: skill,
        range: range,
        hits: chip[:hits],
        targets: chip[:targets],
        description: chip[:description],
        effect: chip[:effect],
        effduration: chip[:effduration],
        blight: chip[:blight],
        damage: chip[:damage],
        kind: kind,
        class: class
      }
    end)
  end

  defp decode_chip_resp(_err) do
    :http_err
  end

  defp string_list_to_atoms(nil) do
    nil
  end

  defp string_list_to_atoms(list) do
    Enum.map(list, fn x -> String.to_atom(x) end)
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
      [chip.hits , " hits"]
    end

    targets = if chip.targets == 1 do
      "1 target"
    else
      [Kernel.to_string(chip.targets), " targets"]
    end

    damage = unless is_nil(chip.damage) do
      [
        Kernel.to_string(chip.damage[:dienum]),
        "d",
        Kernel.to_string(chip.damage[:dietype]),
        " damage"
      ]
    else
      "--"
    end

    class = if chip.class == :standard do
      ""
    else
      [" | ", String.capitalize(Kernel.to_string(chip.class), :ascii)]
    end


    # same as below except faster because of how elixir handles string concat
    # "```\n#{chip.name} - #{elems} | #{skill} | #{range} | #{damage} | #{hits} | #{targets} | #{kind}#{class}\n#{chip.description}\n```"

    io_list = [
      "```\n",
      chip.name,
      " - ",
      elems,
      " | ",
      skill,
      " | ",
      range,
      " | ",
      damage,
      " | ",
      hits,
      " | ",
      targets,
      " | ",
      kind,
      class,
      "\n",
      chip.description,
      "\n```"
    ]

    IO.chardata_to_string(io_list)

  end

end
