require 'pry'
require 'watir'
lobby_players_string = File.read('players.yml')

#def find_players
teammates = lobby_players_string.split("\n").map do |player|
  player[0, player.index(" joined")]
end

b = Watir::Browser.new :chrome
b.goto "https://na.op.gg"

teammates.each_with_index do |teammate, index|
  unless index == 0
    b.link(class: "opgg-header__logo-anchor").click(:control, :shift)
    b.windows.last.use
  end

  b.goto "https://na.op.gg/summoner/userName=#{teammate}"
end

binding.pry;2


