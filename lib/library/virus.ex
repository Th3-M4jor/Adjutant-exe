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
          element: [BnBBot.Library.Shared.Element.t()],
          hp: pos_integer(),
          ac: pos_integer(),
          stats: map(),
          skills: map(),
          drops: map(),
          description: String.t(),
          cr: pos_integer(),
          abilities: [String.t()] | nil,
          damage: BnBBot.Library.Shared.dice() | nil,
          dmgelem: [BnBBot.Library.Shared.Element.t()] | nil,
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

  def skills_to_io_list(%BnBBot.Library.Virus{} = virus) do

    per = num_to_2_digit_string(virus.skills[:per] || 0)
    inf = num_to_2_digit_string(virus.skills[:inf] || 0)
    tch = num_to_2_digit_string(virus.skills[:tch] || 0)
    str = num_to_2_digit_string(virus.skills[:str] || 0)
    agi = num_to_2_digit_string(virus.skills[:agi] || 0)
    endr = num_to_2_digit_string(virus.skills[:end] || 0)
    chm = num_to_2_digit_string(virus.skills[:chm] || 0)
    vlr = num_to_2_digit_string(virus.skills[:vlr] || 0)
    aff = num_to_2_digit_string(virus.skills[:aff] || 0)

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

    #Map.to_list(virus.skills)
    #|> Enum.sort_by(fn {skill, _} ->
    #  BnBBot.Library.Shared.skill_to_sort_pos(skill)
    #end)
    #|> Enum.map(fn {skill, num} ->
    #  skill = to_string(skill) |> String.upcase(:ascii)
    #  num = to_string(num)
    #  [skill, ": ", num]
    #end)
    #|> Enum.intersperse(" | ")
  end

  def drops_to_io_list(%BnBBot.Library.Virus{} = virus) do
    Map.to_list(virus.drops)
    |> Enum.sort_by(fn {drop, _} ->
      {val, _} = Integer.parse(drop)
      val
    end)
    |> Enum.map(fn {drop, num} ->
      [drop, ": ", num]
    end)
    |> Enum.intersperse(" | ")
  end

  defp num_to_2_digit_string(num) do
    if num < 10 do
      "0#{num}"
    else
      "#{num}"
    end
  end

end

defimpl BnBBot.Library.LibObj, for: BnBBot.Library.Virus do
  def type(_value), do: :virus

  @spec to_btn(BnBBot.Library.Virus.t()) :: BnBBot.Library.LibObj.button()
  def to_btn(virus) do
    lower_name = "v_#{String.downcase(virus.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :virus_emoji)

    %{
      type: 2,
      style: 4,
      emoji: emoji,
      label: virus.name,
      custom_id: lower_name
    }
  end

  @spec to_btn(BnBBot.Library.Virus.t(), pos_integer()) :: BnBBot.Library.LibObj.button()
  def to_btn(virus, uuid) do
    lower_name = "#{uuid}_v_#{String.downcase(virus.name, :ascii)}"
    emoji = Application.fetch_env!(:elixir_bot, :virus_emoji)

    %{
      type: 2,
      style: 4,
      emoji: emoji,
      label: virus.name,
      custom_id: lower_name
    }
  end
end

defimpl String.Chars, for: BnBBot.Library.Virus do
  def to_string(%BnBBot.Library.Virus{} = virus) do
    elems =
      Enum.map(virus.element, fn elem -> BnBBot.Library.Shared.element_to_string(elem) end)
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

    damage_elem = unless is_nil(virus.dmgelem) do
      [
        "Damage Element(s): ",
        Enum.map(virus.dmgelem, fn elem -> BnBBot.Library.Shared.element_to_string(elem) end)
        |> Enum.intersperse(", "),
        "\n"
      ]
    else
      []
    end

    blight = unless is_nil(virus.blight) do
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
      Kernel.to_string(virus.stats[:mind]),
      " | Body: ",
      Kernel.to_string(virus.stats[:body]),
      " | Spirit: ",
      Kernel.to_string(virus.stats[:spirit]),
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

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :virus_table)
  end

  @impl true
  def init(_) do
    case load_viruses() do
      {:ok, viruses} ->
        {:ok, viruses}

      {:error, err} ->
        {:stop, err}
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
          res =
            Map.to_list(state)
            |> Enum.map(fn {key, value} -> {String.jaro_distance(key, lower_name), value} end)
            |> Enum.filter(fn {dist, _} -> dist >= min_dist end)
            |> Enum.sort_by(fn {d, _} -> d end, &>=/2)
            |> Enum.take(25)

          {:not_found, res}

        virus ->
          {:found, virus}
      end

    {:reply, resp, state}
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

  defp load_viruses() do
    Logger.info("(Re)loading viruses")
    virus_url = Application.fetch_env!(:elixir_bot, :virus_url)
    resp = HTTPoison.get(virus_url)
    virus_list = decode_virus_resp(resp)

    case virus_list do
      :http_err ->
        Logger.warn("Failed in loadinv viruses")
        {:error, "Failed to load Viruses"}

      viruses ->
        {:ok, Map.new(viruses)}
    end
  end

  defp decode_virus_resp({:ok, %HTTPoison.Response{} = resp}) when resp.status_code in 200..299 do
    maps = Poison.Parser.parse!(resp.body, keys: :atoms)

    Enum.map(maps, fn virus ->
      elem = virus[:element] |> string_list_to_atoms()
      dmg_elem = virus[:dmgelem] |> string_list_to_atoms()
      lower_name = virus[:name] |> String.downcase(:ascii)

      drops =
        virus[:drops]
        |> Enum.map(fn [range, item] ->
          {range, item}
        end)
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
    end)
  end

  defp decode_virus_resp(_err) do
    :http_err
  end

  defp string_list_to_atoms(nil) do
    nil
  end

  defp string_list_to_atoms(list) do
    Enum.map(list, fn x -> String.to_atom(x) end)
  end
end
