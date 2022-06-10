defmodule BnBBot.OneOffs.Reaction.Test do
  alias Nostrum.Api

  def execute([{_, _} | _] = channel_messages, [_ | _] = emojis) do
    for {channel_id, message_id} <- channel_messages, emoji <- emojis do
      Api.create_reaction!(channel_id, message_id, emoji)
    end
  end
end
