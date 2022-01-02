defmodule BnBBot.Library.Battlechip do
  @moduledoc """
  Defines the BattleChip struct, and functions for interacting with them.
  Also defines methods for fetching them from the GenServer that holds them.
  """
  require Logger

  @enforce_keys [
    :id,
    :name,
    :cr,
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
    :cr,
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
          cr: non_neg_integer(),
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
  def load_chips do
    GenServer.call(:chip_table, :reload, :infinity)
  end

  @spec get_chip_ct() :: non_neg_integer()
  def get_chip_ct do
    GenServer.call(:chip_table, :len, :infinity)
  end

  @spec get_chip(String.t(), float()) ::
          {:found, BnBBot.Library.Battlechip.t()}
          | {:not_found, [{float(), BnBBot.Library.Battlechip.t()}]}
  def get_chip(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:chip_table, {:get, name, min_dist})
  end

  @spec get_or_nil(String.t()) :: BnBBot.Library.Battlechip.t() | nil
  def get_or_nil(name) do
    GenServer.call(:chip_table, {:get_or_nil, name})
  end

  @spec get!(String.t()) :: BnBBot.Library.Battlechip.t()
  def get!(name) do
    res = GenServer.call(:chip_table, {:get_or_nil, name})

    if is_nil(res) do
      raise "Chip not found: #{name}"
    else
      res
    end
  end

  @spec get_autocomplete(String.t(), float()) :: [{float(), String.t()}]
  def get_autocomplete(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:chip_table, {:autocomplete, name, min_dist})
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(name) do
    GenServer.call(:chip_table, {:exists, name})
  end

  @spec get_cr(non_neg_integer()) :: [BnBBot.Library.Battlechip.t()]
  def get_cr(cr) do
    GenServer.call(:chip_table, {:get_cr, cr})
  end

  @spec effect_to_io_list(BnBBot.Library.Battlechip.t()) :: iolist()
  def effect_to_io_list(%{effect: nil, effduration: nil}) do
    []
  end

  def effect_to_io_list(%{effect: effect, effduration: effduration})
      when is_nil(effduration) or effduration == 0 do
    eff_list = Enum.intersperse(effect, ", ")
    ["Effect: ", eff_list]
  end

  def effect_to_io_list(%{effect: effect, effduration: effduration}) do
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
  alias Nostrum.Struct.Component.Button

  @chip_emoji :elixir_bot |> Application.compile_env!(:chip_emoji)

  def type(_value), do: :chip

  @spec to_btn(BnBBot.Library.Battlechip.t(), boolean()) :: Button.t()
  def to_btn(chip, disabled \\ false) do
    lower_name = "c_#{String.downcase(chip.name, :ascii)}"

    Button.interaction_button(chip.name, lower_name,
      style: 2,
      emoji: @chip_emoji,
      disabled: disabled
    )
  end

  @spec to_btn_with_uuid(BnBBot.Library.Battlechip.t(), boolean(), 0..0xFF_FF_FF) ::
          Button.t()
  def to_btn_with_uuid(chip, disabled \\ false, uuid) when uuid in 0..0xFF_FF_FF do
    uuid_str = Integer.to_string(uuid, 16) |> String.pad_leading(6, "0")
    lower_name = "#{uuid_str}_c_#{String.downcase(chip.name, :ascii)}"

    Button.interaction_button(chip.name, lower_name,
      style: 2,
      emoji: @chip_emoji,
      disabled: disabled
    )
  end

  @spec to_persistent_btn(BnBBot.Library.Battlechip.t(), boolean()) :: Button.t()
  def to_persistent_btn(chip, disabled \\ false) do
    lower_name = "cr_#{String.downcase(chip.name, :ascii)}"

    Button.interaction_button(chip.name, lower_name,
      style: 2,
      emoji: @chip_emoji,
      disabled: disabled
    )
  end
end

defimpl String.Chars, for: BnBBot.Library.Battlechip do
  def to_string(%BnBBot.Library.Battlechip{} = chip) do
    elems = [
      Stream.map(chip.elem, fn elem -> BnBBot.Library.Shared.element_to_string(elem) end)
      |> Enum.intersperse(", "),
      " | "
    ]

    skill =
      if is_nil(chip.skill) do
        []
      else
        [String.upcase(Enum.join(chip.skill, ", "), :ascii), " | "]
      end

    range = [String.capitalize(Kernel.to_string(chip.range), :ascii), " | "]
    kind = String.capitalize(Kernel.to_string(chip.kind), :ascii)

    hits = hits_to_io_list(chip)

    targets = targets_to_io_list(chip)

    damage =
      if is_nil(chip.damage) do
        []
      else
        [BnBBot.Library.Shared.dice_to_io_list(chip.damage, " damage"), " | "]
      end

    class =
      if chip.class == :standard do
        []
      else
        [" | ", String.capitalize(Kernel.to_string(chip.class), :ascii)]
      end

    cr = if chip.cr > 0 and chip.class == :standard do
      [" | CR ", Integer.to_string(chip.cr)]
    else
      []
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
      cr,
      "\n\n",
      chip.description,
      "\n```"
    ]

    IO.chardata_to_string(io_list)
  end

  defp hits_to_io_list(%BnBBot.Library.Battlechip{hits: nil}) do
    []
  end

  defp hits_to_io_list(%BnBBot.Library.Battlechip{hits: "1"}) do
    ["1 hit", " | "]
  end

  defp hits_to_io_list(%BnBBot.Library.Battlechip{hits: hits}) do
    [hits, " hits | "]
  end

  defp targets_to_io_list(%BnBBot.Library.Battlechip{targets: nil}) do
    []
  end

  defp targets_to_io_list(%BnBBot.Library.Battlechip{targets: "1"}) do
    ["1 target", " | "]
  end

  defp targets_to_io_list(%BnBBot.Library.Battlechip{targets: targets}) do
    [targets, " targets | "]
  end
end

defmodule BnBBot.Library.BattlechipTable do
  @moduledoc """
  BattleChipTable stores all BattleChips currently in the game
  """
  require Logger
  use GenServer

  @chip_url :elixir_bot |> Application.compile_env!(:chip_url)
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :chip_table)
  end

  @impl true
  def init(_) do
    # make loading data be async
    {:ok, %{}, {:continue, :reload}}
  end

  @impl true
  def handle_continue(:reload, _state) do
    case load_chips() do
      {:ok, chips} ->
        {:noreply, chips}

      {:error, reason} ->
        Logger.warn("Failed to load Chips: #{reason}")
        {:noreply, %{}}
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
          res = BnBBot.Library.Shared.gen_suggestions(state, name, min_dist)

          {:not_found, res}

        chip ->
          {:found, chip}
      end

    {:reply, resp, state}
  end

  @impl true
  @spec handle_call({:get_or_nil, String.t()}, GenServer.from(), map()) ::
          {:reply, {BnBBot.Library.Battlechip.t() | nil}, map()}
  def handle_call({:get_or_nil, name}, _from, state) do
    lower_name = String.downcase(name, :ascii)

    {:reply, state[lower_name], state}
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

  @spec handle_call({:get_cr, non_neg_integer()}, GenServer.from(), map()) ::
          {:reply, [BnBBot.Library.Battlechip.t()], map()}
  def handle_call({:get_cr, cr}, _from, state) do
    chips = Map.values(state)
    |> Enum.filter(fn chip ->
      chip.cr == cr
    end)

    {:reply, chips, state}
  end

  defp load_chips do
    Logger.info("(Re)loading Chips")

    resp = HTTPoison.get(@chip_url)
    chip_list = decode_chip_resp(resp)

    case chip_list do
      {:http_err, reason} ->
        {:error, reason}

      {:ok, chips} ->
        {:ok, chips}
    end
  end

  @spec decode_chip_resp({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          {:ok, map()} | {:http_err, String.t()}
  defp decode_chip_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    data_list = Jason.decode!(resp.body, keys: :atoms, strings: :copy)

    chip_map =
      for chip <- data_list, into: %{} do
        elem = chip[:elem] |> string_list_to_atoms()
        skill = chip[:skill] |> string_list_to_atoms()
        range = chip[:range] |> String.to_atom()
        kind = chip[:kind] |> String.to_atom()
        class = chip[:class] |> String.to_atom()
        lower_name = String.downcase(chip[:name], :ascii)

        chip = %BnBBot.Library.Battlechip{
          id: chip[:id],
          name: chip[:name],
          cr: chip[:cr],
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
      end

    {:ok, chip_map}
  end

  defp decode_chip_resp({:ok, %HTTPoison.Response{} = resp}) do
    {:http_err, "Got http status code #{resp.status_code}"}
  end

  defp decode_chip_resp({:error, %HTTPoison.Error{} = err}) do
    {:http_err, "Got http error #{err.reason}"}
  end

  defp string_list_to_atoms(nil) do
    nil
  end

  defp string_list_to_atoms(list) do
    Enum.map(list, fn x -> String.to_atom(x) end)
  end
end
