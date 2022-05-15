defmodule BnBBot.OneOffs.GuildMembers.CSV do
  alias Nostrum.{Api, Snowflake}

  def execute(guild_id, filename \\ "./members.csv") do
    members = Api.list_guild_members!(guild_id, limit: 500)

    members =
      for member <- members do
        join_date = member.joined_at
        id = member.user.id
        name = member.user.username
        created_at = Snowflake.creation_time(id) |> DateTime.to_iso8601()
        id = Snowflake.dump(id)
        [id, ",", name, ",", join_date, ",", created_at, "\r\n"]
      end

    iodata = ["id", ",", "name", ",", "join_date", ",", "created_at", "\r\n" | members]

    File.write!(filename, iodata)
  end
end
