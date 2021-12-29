defmodule BnBBot.Library.Virus do
  require Logger

  @enforce_keys [
    :id,
    :name,
    :element,
    :hp,
    :ac,
    :stats,
    :skills,
    :drops,
    :description,
    :cr,
    :abilities,
    :damage,
    :dmgelem,
    :blight
  ]
  @derive [Inspect]
  defstruct [
    :id,
    :name,
    :element,
    :hp,
    :ac,
    :stats,
    :skills,
    :drops,
    :description,
    :cr,
    :abilities,
    :damage,
    :dmgelem,
    :blight
  ]

  @type t :: %BnBBot.Library.Virus{
          id: pos_integer(),
          name: String.t(),
          element: [BnBBot.Library.Shared.element()],
          hp: pos_integer(),
          ac: pos_integer(),
          stats: map(),
          skills: map(),
          drops: map(),
          description: String.t(),
          cr: pos_integer(),
          abilities: [String.t()] | nil,
          damage: BnBBot.Library.Shared.dice() | nil,
          dmgelem: [BnBBot.Library.Shared.element()] | nil,
          blight: BnBBot.Library.Shared.blight() | nil
        }

  @spec load_viruses() :: {:ok} | {:error, String.t()}
  def load_viruses() do
    GenServer.call(:virus_table, :reload, :infinity)
  end

  @spec get_virus_ct() :: pos_integer()
  def get_virus_ct() do
    GenServer.call(:virus_table, :len, :infinity)
  end

  @spec get_virus(String.t(), float()) ::
          {:found, BnBBot.Library.Virus.t()} | {:not_found, [{float(), BnBBot.Library.Virus.t()}]}
  def get_virus(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:virus_table, {:get, name, min_dist})
  end

  @spec get_or_nil(String.t()) :: BnBBot.Library.Virus.t() | nil
  def get_or_nil(name) do
    GenServer.call(:virus_table, {:get_or_nil, name})
  end

  @spec get!(String.t()) :: BnBBot.Library.Virus.t()
  def get!(name) do
    res = GenServer.call(:virus_table, {:get_or_nil, name})

    unless is_nil(res) do
      res
    else
      raise "Virus not found: #{name}"
    end
  end

  @spec get_autocomplete(String.t(), float()) :: [{float(), String.t()}]
  def get_autocomplete(name, min_dist \\ 0.7) when min_dist >= 0.0 and min_dist <= 1.0 do
    GenServer.call(:virus_table, {:autocomplete, name, min_dist})
  end

  @spec get_cr_list(pos_integer()) :: [BnBBot.Library.Virus.t()]
  def get_cr_list(cr) do
    GenServer.call(:virus_table, {:cr, cr})
  end

  @spec validate_virus_drops() :: {:ok} | {:error, String.t()}
  def validate_virus_drops() do
    GenServer.call(:virus_table, :validate_drops, :infinity)
  end

  @spec locate_by_drop(BnBBot.Library.Battlechip.t()) :: [BnBBot.Library.Virus.t()]
  def locate_by_drop(%BnBBot.Library.Battlechip{} = chip) do
    GenServer.call(:virus_table, {:drops, chip.name}, :infinity)
  end

  @spec make_encounter(pos_integer(), pos_integer()) :: [BnBBot.Library.Virus.t()]
  def make_encounter(num, cr) do
    GenServer.call(:virus_table, {:encounter, num, cr})
  end

  @spec make_encounter(pos_integer(), pos_integer(), pos_integer()) :: [BnBBot.Library.Virus.t()]
  def make_encounter(num, low_cr, high_cr) when low_cr < high_cr do
    GenServer.call(:virus_table, {:encounter, num, low_cr, high_cr})
  end

  @spec skills_to_io_list(BnBBot.Library.Virus.t()) :: iolist()
  def skills_to_io_list(%BnBBot.Library.Virus{} = virus) do
    per = Map.get(virus.skills, :per, 0) |> num_to_2_digit_string()
    inf = Map.get(virus.skills, :inf, 0) |> num_to_2_digit_string()
    tch = Map.get(virus.skills, :tch, 0) |> num_to_2_digit_string()
    str = Map.get(virus.skills, :str, 0) |> num_to_2_digit_string()
    agi = Map.get(virus.skills, :agi, 0) |> num_to_2_digit_string()
    endr = Map.get(virus.skills, :end, 0) |> num_to_2_digit_string()
    chm = Map.get(virus.skills, :chm, 0) |> num_to_2_digit_string()
    vlr = Map.get(virus.skills, :vlr, 0) |> num_to_2_digit_string()
    aff = Map.get(virus.skills, :aff, 0) |> num_to_2_digit_string()

    [
      "PER: ",
      per,
      " | ",
      "STR: ",
      str,
      " | ",
      "CHM: ",
      chm,
      "\nINF: ",
      inf,
      " | ",
      "AGI: ",
      agi,
      " | ",
      "VLR: ",
      vlr,
      "\nTCH: ",
      tch,
      " | ",
      "END: ",
      endr,
      " | ",
      "AFF: ",
      aff
    ]
  end

  def drops_to_io_list(%BnBBot.Library.Virus{} = virus) do
    virus.drops
    |> Enum.sort_by(fn {drop, _} ->
      {val, _} = Integer.parse(drop)
      val
    end)
    |> Enum.map(fn {drop, num} ->
      [drop, ": ", num]
    end)
    |> Enum.intersperse(" | ")
  end

  defp num_to_2_digit_string(num) when is_integer(num) and num >= 10 do
    "#{num}"
  end

  defp num_to_2_digit_string(num) when is_integer(num) and num >= 0 do
    "0#{num}"
  end
end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.Virus do
  alias Nostrum.Struct.Component.Button

  @virus_emoji :elixir_bot |> Application.compile_env!(:virus_emoji)

  def type(_value), do: :virus

  @spec to_btn(BnBBot.Library.Virus.t(), boolean()) :: Button.t()
  def to_btn(virus, disabled \\ false) do
    lower_name = "v_#{String.downcase(virus.name, :ascii)}"

    Button.interaction_button(virus.name, lower_name,
      style: 4,
      emoji: @virus_emoji,
      disabled: disabled
    )
  end

  @spec to_btn_with_uuid(BnBBot.Library.Virus.t(), boolean(), 0..0xFF_FF_FF) :: Button.t()
  def to_btn_with_uuid(virus, disabled \\ false, uuid) when uuid in 0..0xFF_FF_FF do
    uuid_str = Integer.to_string(uuid, 16) |> String.pad_leading(6, "0")
    lower_name = "#{uuid_str}_v_#{String.downcase(virus.name, :ascii)}"

    Button.interaction_button(virus.name, lower_name,
      style: 4,
      emoji: @virus_emoji,
      disabled: disabled
    )
  end

  @spec to_persistent_btn(BnBBot.Library.Virus.t(), boolean()) :: Button.t()
  def to_persistent_btn(virus, disabled \\ false) do
    lower_name = "vr_#{String.downcase(virus.name, :ascii)}"

    Button.interaction_button(virus.name, lower_name,
      style: 4,
      emoji: @virus_emoji,
      disabled: disabled
    )
  end
end

defimpl String.Chars, for: BnBBot.Library.Virus do
  def to_string(%BnBBot.Library.Virus{} = virus) do
    elems =
      Stream.map(virus.element, &BnBBot.Library.Shared.element_to_string/1)
      |> Enum.intersperse(", ")

    skills = BnBBot.Library.Virus.skills_to_io_list(virus)

    abilities =
      unless is_nil(virus.abilities) do
        [
          "Abilities: ",
          Enum.intersperse(virus.abilities, ", "),
          "\n"
        ]
      else
        []
      end

    drops = BnBBot.Library.Virus.drops_to_io_list(virus)

    total_damage =
      unless is_nil(virus.damage) do
        [
          "Total Damage: ",
          BnBBot.Library.Shared.dice_to_io_list(virus.damage),
          "\n"
        ]
      else
        []
      end

    damage_elem =
      unless is_nil(virus.dmgelem) do
        [
          "Damage Element(s): ",
          Stream.map(virus.dmgelem, &BnBBot.Library.Shared.element_to_string/1)
          |> Enum.intersperse(", "),
          "\n"
        ]
      else
        []
      end

    blight =
      unless is_nil(virus.blight) do
        [
          BnBBot.Library.Shared.blight_to_io_list(virus.blight),
          "\n"
        ]
      else
        []
      end

    io_list = [
      "```\n",
      virus.name,
      " (",
      elems,
      ") - CR ",
      Kernel.to_string(virus.cr),
      "\nHP: ",
      Kernel.to_string(virus.hp),
      " | AC: ",
      Kernel.to_string(virus.ac),
      "\nMind: ",
      Kernel.to_string(virus.stats.mind),
      " | Body: ",
      Kernel.to_string(virus.stats.body),
      " | Spirit: ",
      Kernel.to_string(virus.stats.spirit),
      "\n",
      skills,
      "\n",
      abilities,
      total_damage,
      damage_elem,
      blight,
      drops,
      "\n\n",
      virus.description,
      "\n```"
    ]

    IO.chardata_to_string(io_list)
  end
end

defmodule BnBBot.Library.VirusTable do
  require Logger

  use GenServer

  @virus_url :elixir_bot |> Application.compile_env!(:virus_url)

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :virus_table)
  end

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :reload}}
    # case load_viruses() do
    #  {:ok, viruses} ->
    #    {:ok, viruses}
    #
    #  {:error, reason} ->
    #    Logger.warn("Failed to load Viruses: #{reason}")
    #    {:ok, %{}}
    # end
  end

  @impl true
  def handle_continue(:reload, _state) do
    case load_viruses() do
      {:ok, viruses} ->
        {:noreply, viruses}

      {:error, reason} ->
        Logger.warn("Failed to load Viruses: #{reason}")
        {:noreply, %{}}
    end
  end

  @impl true
  @spec handle_call({:get, String.t(), float()}, GenServer.from(), map()) ::
          {:reply,
           {:found, BnBBot.Library.Virus.t()}
           | {:not_found, [{float(), BnBBot.Library.Virus.t()}]}, map()}
  def handle_call({:get, name, min_dist}, _from, state) do
    lower_name = String.downcase(name)

    resp =
      case state[lower_name] do
        nil ->
          res = BnBBot.Library.Shared.gen_suggestions(state, name, min_dist)

          {:not_found, res}

        virus ->
          {:found, virus}
      end

    {:reply, resp, state}
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

  @spec handle_call({:get_or_nil, String.t()}, GenServer.from(), map()) ::
          {:reply, BnBBot.Library.Virus.t() | nil, map()}
  def handle_call({:get_or_nil, name}, _from, state) do
    lower_name = String.downcase(name)

    {:reply, state[lower_name], state}
  end

  @spec handle_call(:reload, GenServer.from(), map()) ::
          {:reply, {:ok} | {:error, String.t()}, map()}
  def handle_call(:reload, _from, _state) do
    case load_viruses() do
      {:ok, viruses} ->
        {:reply, {:ok}, viruses}

      {:error, reason} ->
        {:reply, {:error, reason}, Map.new()}
    end
  end

  @spec handle_call(:len, GenServer.from(), map()) :: {:reply, non_neg_integer(), map()}
  def handle_call(:len, _from, state) do
    size = map_size(state)
    {:reply, size, state}
  end

  @spec handle_call({:cr, pos_integer()}, GenServer.from(), map()) ::
          {:reply, [BnBBot.Library.Virus.t()], map()}
  def handle_call({:cr, cr}, _from, state) do
    viruses =
      Map.values(state)
      |> Enum.filter(fn virus -> virus.cr == cr end)

    {:reply, viruses, state}
  end

  @spec handle_call({:encounter, pos_integer(), pos_integer()}, GenServer.from(), map()) ::
          {:reply, [BnBBot.Library.Virus.t()], map()}
  def handle_call({:encounter, count, cr}, _from, state) do
    viruses =
      Map.values(state)
      |> Enum.filter(fn virus -> virus.cr == cr end)

    viruses =
      unless Enum.empty?(viruses) do
        for _ <- 1..count, do: Enum.random(viruses)
      else
        []
      end

    {:reply, viruses, state}
  end

  @spec handle_call(
          {:encounter, pos_integer(), pos_integer(), pos_integer()},
          GenServer.from(),
          map()
        ) ::
          {:reply, [BnBBot.Library.Virus.t()], map()}
  def handle_call({:encounter, count, low_cr, high_cr}, _from, state) do
    viruses =
      Map.values(state)
      |> Enum.filter(fn virus -> virus.cr in low_cr..high_cr end)

    viruses =
      unless Enum.empty?(viruses) do
        for _ <- 1..count, do: Enum.random(viruses)
      else
        []
      end

    {:reply, viruses, state}
  end

  @spec handle_call(:validate_drops, GenServer.from(), map()) ::
          {:reply, {:ok} | {:error, String.t()}, map()}
  def handle_call(:validate_drops, _from, state) do
    viruses = Map.values(state)

    res =
      Enum.find_value(viruses, fn virus ->
        drop =
          Map.to_list(virus.drops)
          |> Enum.find(fn {_, drop} ->
            !String.contains?(drop, "Zenny") && !BnBBot.Library.Battlechip.exists?(drop)
          end)

        unless is_nil(drop) do
          {pos, drop} = drop
          "#{virus.name} drops #{drop} at #{pos}, however it doesn't exist"
        end
      end)

    to_ret =
      if is_nil(res) do
        {:ok}
      else
        {:error, res}
      end

    {:reply, to_ret, state}
  end

  @spec handle_call({:drops, String.t()}, GenServer.from(), map()) ::
          {:reply, [BnBBot.Library.Virus.t()], map()}
  def handle_call({:drops, name}, _from, state) do
    viruses =
      Map.values(state)
      |> Enum.filter(fn virus ->
        Map.values(virus.drops)
        |> Enum.any?(fn drop -> drop == name end)
      end)

    {:reply, viruses, state}
  end

  defp load_viruses() do
    Logger.info("(Re)loading viruses")

    resp = HTTPoison.get(@virus_url)
    virus_list = decode_virus_resp(resp)

    case virus_list do
      {:http_err, reason} ->
        {:error, reason}

      {:ok, viruses} ->
        {:ok, viruses}
    end
  end

  @spec decode_virus_resp({:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}) ::
          {:ok, map()} | {:http_err, String.t()}
  defp decode_virus_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    data_list = Jason.decode!(resp.body, keys: :atoms, strings: :copy)

    virus_map =
      for virus <- data_list, into: %{} do
        elem = virus[:element] |> string_list_to_atoms()
        dmg_elem = virus[:dmgelem] |> string_list_to_atoms()
        lower_name = virus[:name] |> String.downcase(:ascii)

        drops =
          virus[:drops]
          |> Stream.map(&List.to_tuple/1)
          |> Map.new()

        virus = %BnBBot.Library.Virus{
          id: virus[:id],
          name: virus[:name],
          element: elem,
          hp: virus[:hp],
          ac: virus[:ac],
          stats: virus[:stats],
          skills: virus[:skills],
          drops: drops,
          description: virus[:description],
          cr: virus[:cr],
          abilities: virus[:abilities],
          damage: virus[:damage],
          dmgelem: dmg_elem,
          blight: virus[:blight]
        }

        {lower_name, virus}
      end

    # maps =
    #   Jason.decode!(resp.body, keys: :atoms, strings: :copy)
    #   |> Enum.map(fn virus ->
    #     elem = virus[:element] |> string_list_to_atoms()
    #     dmg_elem = virus[:dmgelem] |> string_list_to_atoms()
    #     lower_name = virus[:name] |> String.downcase(:ascii)
    #
    #     drops =
    #       virus[:drops]
    #       |> Stream.map(fn [range, item] ->
    #         {range, item}
    #       end)
    #       |> Map.new()
    #
    #     virus = %BnBBot.Library.Virus{
    #       id: virus[:id],
    #       name: virus[:name],
    #       element: elem,
    #       hp: virus[:hp],
    #       ac: virus[:ac],
    #       stats: virus[:stats],
    #       skills: virus[:skills],
    #       drops: drops,
    #       description: virus[:description],
    #       cr: virus[:cr],
    #       abilities: virus[:abilities],
    #       damage: virus[:damage],
    #       dmgelem: dmg_elem,
    #       blight: virus[:blight]
    #     }
    #
    #     {lower_name, virus}
    #   end)

    {:ok, virus_map}
  end

  defp decode_virus_resp({:ok, %HTTPoison.Response{} = resp}) do
    {:http_err, "Got http status code #{resp.status_code}"}
  end

  defp decode_virus_resp({:error, %HTTPoison.Error{} = err}) do
    {:http_err, "Got http error #{err.reason}"}
  end

  defp string_list_to_atoms(nil) do
    nil
  end

  defp string_list_to_atoms(list) when is_list(list) do
    Enum.map(list, fn x -> String.to_atom(x) end)
  end
end
