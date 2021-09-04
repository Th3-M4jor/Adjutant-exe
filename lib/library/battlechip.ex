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
          hits: String.t(),
          targets: String.t(),
          description: String.t(),
          effect: [String.t()] | nil,
          effduration: non_neg_integer() | nil,
          blight: BnBBot.Library.Shared.blight() | nil,
          damage: BnBBot.Library.Shared.dice() | nil,
          kind: BnBBot.Library.Shared.kind(),
          class: class()
        }

  @spec load_chips :: {:ok} | {:error, String.t()}
  def load_chips() do
    GenServer.call(:chip_table, :reload, :infinity)
  end

  @spec get_chip_ct() :: non_neg_integer()
  def get_chip_ct() do
    GenServer.call(:chip_table, :len, :infinity)
  end

  @spec get_chip(String.t(), float()) ::
          {:found, BnBBot.Library.Battlechip.t()}
          | {:not_found, [{float(), BnBBot.Library.Battlechip.t()}]}
  def get_chip(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:chip_table, {:get, name, min_dist})
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(name) do
    GenServer.call(:chip_table, {:exists, name})
  end

  @spec effect_to_io_list(BnBBot.Library.Battlechip.t()) :: iolist()
  def effect_to_io_list(%BnBBot.Library.Battlechip{effect: nil, effduration: nil}) do
    []
  end

  def effect_to_io_list(%BnBBot.Library.Battlechip{effect: effect, effduration: effduration})
      when is_nil(effduration) or effduration == 0 do
    eff_list = Enum.intersperse(effect, ", ")
    ["Effect: ", eff_list]
  end

  def effect_to_io_list(%BnBBot.Library.Battlechip{effect: effect, effduration: effduration}) do
    eff_list = Enum.intersperse(effect, ", ")

    [
      "Effect: ",
      eff_list,
      " for up to ",
      to_string(effduration),
      " round(s)"
    ]
  end
end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.Battlechip do
  def type(_value), do: :chip

  @spec to_btn(BnBBot.Library.Battlechip.t()) :: BnBBot.Library.LibObj.button()
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

  @spec to_btn(BnBBot.Library.Battlechip.t(), pos_integer()) :: BnBBot.Library.LibObj.button()
  def to_btn(chip, uuid) do
    lower_name = "#{uuid}_c_#{String.downcase(chip.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :chip_emoji)

    %{
      type: 2,
      style: 2,
      emoji: emoji,
      label: chip.name,
      custom_id: lower_name
    }
  end

  @spec to_persistent_btn(BnBBot.Library.Battlechip.t()) :: BnBBot.Library.LibObj.button()
  def to_persistent_btn(chip) do
    lower_name = "cr_#{String.downcase(chip.name, :ascii)}"
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
    elems =
      [Enum.map(chip.elem, fn elem -> BnBBot.Library.Shared.element_to_string(elem) end)
      |> Enum.intersperse(", "), " | "]

    skill =
      unless is_nil(chip.skill) do
        [String.upcase(Enum.join(chip.skill, ", "), :ascii), " | "]
      else
        []
      end

    range = [String.capitalize(Kernel.to_string(chip.range), :ascii), " | "]
    kind = String.capitalize(Kernel.to_string(chip.kind), :ascii)

    hits =
      case chip.hits do
        nil -> []
        "1" -> ["1 hit", " | "]
        _ -> [chip.hits, " hits | "]
      end

    targets =
      case chip.targets do
        nil -> []
        "1" -> ["1 target", " | "]
        _ -> [chip.targets, " targets | "]
      end

    damage =
      unless is_nil(chip.damage) do
        [BnBBot.Library.Shared.dice_to_io_list(chip.damage, " damage"), " | "]
      else
        []
      end

    class =
      if chip.class == :standard do
        []
      else
        [" | ", String.capitalize(Kernel.to_string(chip.class), :ascii)]
      end

    io_list = [
      "```\n",
      chip.name,
      " - ",
      elems,
      skill,
      range,
      damage,
      hits,
      targets,
      kind,
      class,
      "\n\n",
      chip.description,
      "\n```"
    ]

    IO.chardata_to_string(io_list)
  end
end

defmodule BnBBot.Library.BattlechipTable do
  require Logger
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :chip_table)
  end

  @impl true
  def init(_) do
    case load_chips() do
      {:ok, chips} ->
        {:ok, chips}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  @spec handle_call({:get, String.t(), float()}, GenServer.from(), map()) ::
          {:reply,
           {:found, BnBBot.Library.Battlechip.t()}
           | {:not_found, [{float(), BnBBot.Library.Battlechip.t()}]}, map()}
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

        chip ->
          {:found, chip}
      end

    {:reply, resp, state}
  end

  @spec handle_call(:reload, GenServer.from(), map()) ::
          {:reply, {:ok} | {:error, String.t()}, map()}
  def handle_call(:reload, _from, _state) do
    case load_chips() do
      {:ok, chips} ->
        {:reply, {:ok}, chips}

      {:error, reason} ->
        {:reply, {:error, reason}, Map.new()}
    end
  end

  @spec handle_call(:len, GenServer.from(), map()) :: {:reply, non_neg_integer(), map()}
  def handle_call(:len, _from, state) do
    size = map_size(state)
    {:reply, size, state}
  end

  @spec handle_call({:exists, String.t()}, GenServer.from(), map()) :: {:reply, boolean(), map()}
  def handle_call({:exists, name}, _from, state) do
    lower_name = String.downcase(name, :ascii)
    exists = Map.has_key?(state, lower_name)
    {:reply, exists, state}
  end

  defp load_chips() do
    Logger.debug("(Re)loading Chips")

    chip_url = Application.fetch_env!(:elixir_bot, :chip_url)
    resp = HTTPoison.get(chip_url)
    chip_list = decode_chip_resp(resp)

    case chip_list do
      :http_err ->
        Logger.warn("Failed in loading chips")
        {:error, "Failed to load Chips"}

      chips ->
        {:ok, Map.new(chips)}
    end
  end

  @spec decode_chip_resp({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          [{String.t(), BnBBot.Library.Battlechip}] | :http_err
  defp decode_chip_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    maps = Poison.Parser.parse!(resp.body, keys: :atoms)

    Enum.map(maps, fn chip ->
      elem = chip[:elem] |> string_list_to_atoms()
      skill = chip[:skill] |> string_list_to_atoms()
      range = chip[:range] |> String.to_atom()
      kind = chip[:kind] |> String.to_atom()
      class = chip[:class] |> String.to_atom()
      lower_name = String.downcase(chip[:name], :ascii)

      chip = %BnBBot.Library.Battlechip{
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

      {lower_name, chip}
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
