require 'watir'
require 'pry'
require 'colorize'
require 'awesome_print'

def record_results lane_key, winner, loser
  @lanes[lane_key] = { winner: winner, loser: loser }
end

def champ_name href
  href.match(/champion\/(.+)\/statistics/)[1].to_s.downcase
end

def determine_team team
  team == 1 ? @team_one_champs : @team_two_champs
end

def mappable_name? name
  NAME_MAP.keys.include? name
end

def map_champion_name name
  NAME_MAP[name]
end

def winner_exists? champions, winner
  champions.include? winner
end

#todo record ties
def record_matchup lane_key, winner, loser
  loser_hash = Hash loser => 'win'
  matchups = YAML.load_file 'matchups.yml'
  matchups[lane_key][winner] = loser_hash

  File.open('matchups.yml', 'w+') do |file|
    file.puts matchups.to_yaml
  end

rescue => e
  warn "lane_key: #{lane_key} || winner: #{winner} || loser: #{loser}"
  raise e
end

def output_results winner, loser, tie=false
  winner_string = !tie ? winner.colorize(:green) : winner.colorize(:orange)
  loser_string = !tie ? loser.colorize(:red) : winner.colorize(:orange)
  puts winner_string, loser_string
end

def lookup_matchup lane_key, champs
  champ1, champ2 = champs.first, champs.last

  url = "https://www.counterstats.net/league-of-legends/#{champ1}/vs-#{champ2}/#{lane_key}/all"
  @b.goto url
  sleep 3

  if @b.div(class: 'vs-head__circle--winner').exists?
    href   = @b.div(class: 'vs-head__circle--winner').a.href
    winner = href.match(/legends\/(.+)/)[1]
    loser  = champs.reject { |champ| champ == winner }.first
  elsif @b.divs(class: 'vs-head__circle--loser').size == 2 # there are two losers (draw)
    # record_matchup lane_key, winner, loser
    output_results winner, loser,true
  else
    binding.pry
    puts "-" * 80
    puts "UNREACHABLE CODE"
    puts "lane_key: #{lane_key}\n"
    puts "champs: #{champs}\n"
    puts "winner: #{winner}\n"
    puts "loser: #{loser}\n"
    puts "-" * 80
  end

  record_matchup lane_key, winner, loser
  output_results winner, loser
end

# :top, ["teemo", "camille"]
def existing_matchup? lane_key, champs
  matchups = YAML.load_file 'matchups.yml'
  champ1   = champs.first
  champ2   = champs.last

  lane_matchups   = matchups.dig lane_key
  champ1_matchups = lane_matchups.dig(champ1)
  champ2_matchups = lane_matchups.dig(champ2)

  return false unless champ1_matchups && champ2_matchups

  one_vs_two = champ1_matchups.dig(champ2)
  two_vs_one = champ2_matchups.dig(champ1)

  return true if one_vs_two
  return true if two_vs_one
  false
rescue => e
  warn "lane_key: #{lane_key} || champs: #{champs}"
  raise e
end

def winner_loser_hash winner, loser
  Hash winner: winner, loser: loser
end

def two_vs_one_results results, champ1, champ2
  winner = results == 'win' ? champ1 : champ2
  loser = results == 'win' ? champ2 : champ1

  winner_loser_hash winner, loser
end

def one_vs_two_results results, champ1, champ2
  winner = results == 'win' ? champ2 : champ1
  loser = results == 'win' ? champ1 : champ2

  winner_loser_hash winner, loser
end

def log_results one_vs_two_results, two_vs_one_results, champ1, champ2
  puts '-' * 80
  puts "WE REACHED THE UNREACHABLE CODE: #{__FILE__ }:#{__LINE__ }!!!"
  puts "champ1: #{champ1}"
  puts "champ2: #{champ2}"
  puts "two_vs_one_results: #{two_vs_one_results}"
  puts "one_vs_two_results: #{one_vs_two_results}"
  puts '-' * 80
end

def existing_matchup lane_key, champs
  matchups = YAML.load_file 'matchups.yml'
  lane_matchups = matchups[lane_key.to_s]
  champ1 = champs.first
  champ2 = champs.last

  champ1_matchups = lane_matchups.fetch champ1, {}
  champ2_matchups = lane_matchups.fetch champ2, {}

  unless champ1_matchups.empty?
    one_vs_two_results = champ1_matchups.fetch champ2, {}

    unless one_vs_two_results.empty?
      return one_vs_two_results(
          one_vs_two_results,
          champ1,
          champ2
      )
    end
  end

  unless champ2_matchups.empty?
    two_vs_one_results = champ2_matchups.fetch champ1, {}

    unless two_vs_one_results.empty?
      two_vs_one_results(
          two_vs_one_results,
          champ1,
          champ2
      )
    end
  end
end

def collect_lane_champ lane, team_champs, team_num, opts=''
  opts = (' ' + opts) unless opts.empty?
  ap(team_champs, AWESOME_PRINT_OPTS)

  puts "Select#{opts} #{lane.upcase} lane for team #{team_num}"
  puts "Options are: 1-#{team_champs.size}"

  choice = gets.chomp.to_i
  choice -= 1
  team_champs[choice]
end

#todo
def find_random_game
  @b.goto 'https://porofessor.gg/current-games/na'
  ul = @b.ul(class: 'currentGamesGrid')
  ul.detect do |li|
    header = li.div(class: 'cardHeader')
    binding.pry
    header.a.span(class: 'gameDuration')
  end
end

NAME_MAP = {
  "missfortune" => "miss-fortune",
  "twistedfate" => "twisted-fate",
  "masteryi" => "master-yi",
  "nunuwillump" => "nunu-willump",
  "drmundo" => "dr-mundo",
  "xinzhao" => "xin-zhao",
  "tahmkench" => "tahm-kench",
  "jarvaniv" => "jarvan-iv",
  "leesin" => "lee-sin",
  "nunu" => "nunu-willump"
}

AWESOME_PRINT_OPTS = { index: false }

@b = Watir::Browser.new :chrome,
                        switches: [
                             # 'headless',
                            '--ignore-certificate-errors',
                            '--ignore-ssl-errors'
                        ]

url = if ARGV[0] == '--test'
        find_random_game
      else
        "https://na.op.gg/summoner/userName=Payer"
      end

@b.goto url
@b.a(class: 'SpectateTabButton').click
sleep 1

@team_one_champs = []
@team_two_champs = []

@b.tds(class: 'ChampionImage').each_with_index do |td, index|
  champ_name = champ_name td.a.href

  if mappable_name? champ_name
    champ_name = map_champion_name champ_name
  end

  if index < 5
    @team_one_champs << champ_name
  else
    @team_two_champs << champ_name
  end
end

@lanes = {
    'top' => [],
    'middle' => [],
    'bottom' => [],
    'jungle' => []
}

2.times do |index|
  lane = 'top'
  team_num = index + 1
  team_champs = determine_team team_num
  champ = collect_lane_champ lane, team_champs, team_num

  @lanes[lane] << champ
  team_champs.delete champ
end

2.times do |index|
  lane = 'middle'
  team_num = index + 1
  team_champs = determine_team team_num
  champ = collect_lane_champ lane, team_champs, team_num
  @lanes[lane] << champ
  team_champs.delete champ
end

2.times do |index|
  lane = 'jungle'
  team_num = index + 1
  team_champs = determine_team team_num
  champ = collect_lane_champ lane, team_champs, team_num

  @lanes[lane] << champ
  team_champs.delete champ
end

bottom_adc_champs = []
2.times do |index|
  lane = 'bottom'
  team_num = index + 1
  team_champs = determine_team team_num
  champ = collect_lane_champ lane, team_champs, team_num, 'ADC'

  bottom_adc_champs << champ
  team_champs.delete champ
end

# bottom support
support_champs = @team_one_champs + @team_two_champs

# sets both adc and support champs
@lanes['bottom'] = [bottom_adc_champs, support_champs]

# lane - ['top', ["mordekaiser", "camille"]]
@lanes.each do |lane|
  lane_key  = lane.first
  champions = lane.last

  if lane_key == 'bottom'
    champions.each do |champs|
      if existing_matchup? lane_key, champs
        results = existing_matchup lane_key, champs

	# record_results results[:winner], results[:loser]
        output_results results[:winner], results[:loser]
        next
      end

      lookup_matchup lane_key, champs
    end
  else
    if existing_matchup? lane_key, champions
      results = existing_matchup lane_key, champions

      output_results results[:winner], results[:loser]
      next
    end

    lookup_matchup lane_key, champions
  end
end

puts @lanes
