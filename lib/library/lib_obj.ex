defprotocol BnBBot.Library.LibObj do
  @spec type(t) :: atom()
  def type(value)

  @spec type(t) :: map()
  def to_btn(value)
end
