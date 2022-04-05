defmodule BnBBot.Library.Virus.Stats do
  @moduledoc """
  Ecto type mapping for a virus's stats.
  """

  use Ecto.Type

  def type, do: :virus_stats

  def cast(%{"mind" => mind, "body" => body, "spirit" => spirit})
      when mind in 1..5 and body in 1..5 and spirit in 1..5 do
    {:ok, %{mind: mind, body: body, spirit: spirit}}
  end

  def cast(_stats), do: :error

  def load(%{"mind" => mind, "body" => body, "spirit" => spirit})
      when mind in 1..5 and body in 1..5 and spirit in 1..5 do
    {:ok, %{mind: mind, body: body, spirit: spirit}}
  end

  def load(_stats), do: :error

  def dump(%{mind: mind, body: body, spirit: spirit})
      when mind in 1..5 and body in 1..5 and spirit in 1..5 do
    {:ok, %{"mind" => mind, "body" => body, "spirit" => spirit}}
  end

  def dump(_stats), do: :error
end

defmodule BnBBot.Library.Virus.Skills do
  @moduledoc """
  Ecto type mapping for a virus's skills.
  """

  @skills [
    # Perception
    :per,
    # Info
    :inf,
    # Tech
    :tch,
    # Strength
    :str,
    # Agility
    :agi,
    # Endurance
    :end,
    # Charm
    :chm,
    # Valor
    :vlr,
    # Affinity
    :aff
  ]

  use Ecto.Type

  defstruct per: 0, inf: 0, tch: 0, str: 0, agi: 0, end: 0, chm: 0, vlr: 0, aff: 0

  def type, do: :virus_skills

  def cast(skills) when is_map(skills) do
    skills =
      Enum.map(skills, fn {key, value} ->
        {convert(key), value}
      end)

    {:ok, struct(__MODULE__, skills)}
  end

  def cast(_skills), do: :error

  def load(skills) when is_map(skills) do
    skills =
      Enum.map(skills, fn {key, value} ->
        {convert(key), value}
      end)

    {:ok, struct(__MODULE__, skills)}
  end

  def load(_skills), do: :error

  def dump(%__MODULE__{} = skills) do
    res =
      Map.from_struct(skills)
      |> Enum.map(fn {key, value} ->
        {to_string(key), value}
      end)
      |> Map.new()

    {:ok, res}
  end

  defp convert(skill) when is_binary(skill) do
    String.downcase(skill, :ascii) |> String.to_existing_atom()
  end

  defp convert(skill) when skill in @skills do
    skill
  end
end

defmodule BnBBot.Library.Virus do
  @moduledoc """
  Defines the Virus struct, and functionality on it,
  as well as methods for fetching viruses from GenServer that holds them.
  """

  alias BnBBot.Library.Shared.{Blight, Dice, Element}
  alias BnBBot.Library.Virus.{Skills, Stats}

  require Logger

  use Ecto.Schema
  import Ecto.Query
  import BnBBot.CustomQuery

  @derive [Inspect]
  schema "Virus" do
    field(:name, :string)
    field(:element, Element)
    field(:hp, :integer)
    field(:ac, :integer)
    field(:stats, Stats)
    field(:skills, Skills)
    field(:drops, :map)
    field(:description, :string)
    field(:cr, :integer)
    field(:abilities, {:array, :string})
    field(:damage, Dice)
    field(:dmgelem, Element)
    field(:blight, Blight)
    field(:custom, :boolean, default: false)

    field(:attack_kind, Ecto.Enum,
      values: [
        melee: "Melee",
        projectile: "Projectile",
        wave: "Wave",
        burst: "Burst",
        summon: "Summon",
        construct: "Construct",
        support: "Support",
        heal: "Heal",
        trap: "Trap"
      ]
    )
  end

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
          blight: BnBBot.Library.Shared.blight() | nil,
          attack_kind: BnBBot.Library.Shared.kind() | nil
        }

  @spec load_viruses() :: {:ok} | {:error, String.t()}
  def load_viruses do
    {:ok}
    # GenServer.call(:virus_table, :reload, :infinity)
  end

  @spec get_virus_ct() :: pos_integer()
  def get_virus_ct do
    BnBBot.Repo.Postgres.aggregate(__MODULE__, :count)
  end

  @spec get(String.t()) :: t() | nil
  def get(name) do
    query = from(v in __MODULE__, where: v.name == ^name)
    BnBBot.Repo.Postgres.one(query)
  end

  @spec get!(String.t()) :: t() | no_return()
  def get!(name) do
    query = from(v in __MODULE__, where: v.name == ^name)
    BnBBot.Repo.Postgres.one!(query)
  end

  @spec get_autocomplete(String.t(), float()) :: [{float(), String.t()}]
  def get_autocomplete(name, min_dist \\ 0.2) when min_dist >= 0.0 and min_dist <= 1.0 do
    query =
      from(v in __MODULE__,
        where: word_similarity(v.name, ^name) >= ^min_dist,
        limit: 10,
        order_by: [
          fragment("word_similarity(?, ?) DESC", v.name, ^name),
          asc: v.name
        ]
      )

    BnBBot.Repo.Postgres.all(query) |> Enum.map(fn virus -> virus.name end)
  end

  @spec get_cr_list(pos_integer()) :: [BnBBot.Library.Virus.t()]
  def get_cr_list(cr) do
    query = from(v in __MODULE__, where: v.cr == ^cr)
    BnBBot.Repo.Postgres.all(query)
  end

  @spec validate_virus_drops() :: {:ok} | {:error, iodata()}
  def validate_virus_drops do
    query = """
    WITH virus AS (
    SELECT name, (json_each_text(drops::json)).key as "level", (json_each_text(drops::json)).value AS "drop" FROM "Virus"
    )
    SELECT name FROM virus WHERE virus.drop NOT IN (SELECT name from "Battlechip") AND virus.drop NOT LIKE '%Zenny';
    """

    result = BnBBot.Repo.Postgres.query!(query)

    rows = Enum.map(result.rows, &BnBBot.Repo.Postgres.load(__MODULE__, {result.columns, &1}))

    if Enum.empty?(rows) do
      {:ok}
    else
      missing =
        Enum.map(rows, fn %{name: name} ->
          "Virus #{name} has a drop which does not exist"
        end)

      {:error, missing}
    end

    # GenServer.call(:virus_table, :validate_drops, :infinity)
  end

  @spec locate_by_drop(BnBBot.Library.Battlechip.t()) :: [BnBBot.Library.Virus.t()]
  def locate_by_drop(%BnBBot.Library.Battlechip{} = chip) do
    query = """
    WITH drops AS (
    SELECT name, (json_each_text(drops::json)).value as "drop" FROM "Virus"
    ), to_get AS (
    SELECT name from drops WHERE drops.drop = $1
    )
    SELECT * FROM "Virus" WHERE "Virus".name IN (SELECT name from to_get)
    """

    result = BnBBot.Repo.Postgres.query!(query, [chip.name])

    Enum.map(result.rows, &BnBBot.Repo.Postgres.load(__MODULE__, {result.columns, &1}))
    # GenServer.call(:virus_table, {:drops, chip.name}, :infinity)
  end

  @spec make_encounter(pos_integer(), pos_integer()) :: [BnBBot.Library.Virus.t()]
  def make_encounter(num, cr) do
    query = from(v in __MODULE__, where: v.cr == ^cr)

    case BnBBot.Repo.Postgres.all(query) do
      [] ->
        []

      viruses ->
        for _ <- 1..num, do: Enum.random(viruses)
    end

    # GenServer.call(:virus_table, {:encounter, num, cr})
  end

  @spec make_encounter(pos_integer(), pos_integer(), pos_integer()) :: [BnBBot.Library.Virus.t()]
  def make_encounter(num, low_cr, high_cr) when low_cr < high_cr do
    query = from(v in __MODULE__, where: v.cr >= ^low_cr and v.cr <= ^high_cr)

    case BnBBot.Repo.Postgres.all(query) do
      [] ->
        []

      viruses ->
        for _ <- 1..num, do: Enum.random(viruses)
    end

    # GenServer.call(:virus_table, {:encounter, num, low_cr, high_cr})
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

  def abilities_to_io_list(%BnBBot.Library.Virus{abilities: nil}) do
    []
  end

  def abilities_to_io_list(%BnBBot.Library.Virus{abilities: abilities}) do
    [
      "Abilities: ",
      Enum.intersperse(abilities, ", "),
      "\n"
    ]
  end

  defp num_to_2_digit_string(num) when is_integer(num) and num >= 10 do
    "#{num}"
  end

  defp num_to_2_digit_string(num) when is_integer(num) and num >= 0 do
    "0#{num}"
  end

  defimpl BnBBot.Library.LibObj do
    alias Nostrum.Struct.Component.Button

    @virus_emoji :elixir_bot |> Application.compile_env!(:virus_emoji)

    def type(_value), do: :virus

    @spec to_btn(BnBBot.Library.Virus.t(), boolean()) :: Button.t()
    def to_btn(virus, disabled \\ false) do
      lower_name = "v_#{virus.name}"

      Button.interaction_button(virus.name, lower_name,
        style: 4,
        emoji: @virus_emoji,
        disabled: disabled
      )
    end

    @spec to_btn_with_uuid(BnBBot.Library.Virus.t(), boolean(), 0..0xFF_FF_FF) :: Button.t()
    def to_btn_with_uuid(virus, disabled \\ false, uuid) when uuid in 0..0xFF_FF_FF do
      uuid_str = Integer.to_string(uuid, 16) |> String.pad_leading(6, "0")
      lower_name = "#{uuid_str}_v_#{virus.name}"

      Button.interaction_button(virus.name, lower_name,
        style: 4,
        emoji: @virus_emoji,
        disabled: disabled
      )
    end

    @spec to_persistent_btn(BnBBot.Library.Virus.t(), boolean()) :: Button.t()
    def to_persistent_btn(virus, disabled \\ false) do
      lower_name = "vr_#{virus.name}"

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

      abilities = BnBBot.Library.Virus.abilities_to_io_list(virus)

      drops = BnBBot.Library.Virus.drops_to_io_list(virus)

      total_damage =
        if is_nil(virus.damage) do
          []
        else
          [
            "Total Damage: ",
            BnBBot.Library.Shared.dice_to_io_list(virus.damage),
            "\n"
          ]
        end

      damage_elem =
        if is_nil(virus.dmgelem) do
          []
        else
          [
            "Damage Element(s): ",
            Stream.map(virus.dmgelem, &BnBBot.Library.Shared.element_to_string/1)
            |> Enum.intersperse(", "),
            "\n"
          ]
        end

      blight =
        if is_nil(virus.blight) do
          []
        else
          [
            BnBBot.Library.Shared.blight_to_io_list(virus.blight),
            "\n"
          ]
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
end
