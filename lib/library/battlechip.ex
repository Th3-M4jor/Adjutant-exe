defmodule BnBBot.Library.Battlechip do
  require Logger

  @enforce_keys [:id, :name, :elem, :skill, :range, :hits, :targets, :description, :effect, :effduration, :blight, :damage, :kind, :class]
  defstruct [:id, :name, :elem, :skill, :range, :hits, :targets, :description, :effect, :effduration, :blight, :damage, :kind, :class]

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
    class: class(),
  }

end
