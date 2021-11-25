require 'telegram_bot'
require 'telegram_bot/response_error'
require 'net/http'
require 'net/https'
require 'cgi'
require 'yaml'
require 'sqlite3'


leaderboards = Hash.new

# Manage database
db = SQLite3::Database.new 'leaderboards.db'
#   Create table
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS leaderboards (
      chat INT PRIMARY KEY,
      lb_number INT
  );
SQL

db.execute 'SELECT * FROM leaderboards;' do |row|
  leaderboards[row[0]] = row[1]
end

# Get the config
config = YAML.load_file('config.yml')

token = config['keys'][0]['token']
puts "Set `#{token}` as the token"

session_cookie = config['keys'][0]['cookie']
puts "Set `#{session_cookie}` as the session cookie"

source = "https://adventofcode.com/#{config['keys'][0]['year']}/leaderboard/private/view/"


if config['messages'][0]['start'].nil?
  puts "There was not a start message in the config, using the default"
  hello_msg = "Hola! Me han creado con el propósito de pasar la mantequilla.\n\nNah, mira las opciones que tengo disponibles y úsame senpai."  
else
  hello_msg = config['messages'][0]['start']
end

# Start the bot
bot = TelegramBot.new(token: token)

emojis = ['🤯', '😵‍', '💫', '😈', '🐷', '🥸', '🤗', '😶‍🌫️', '🤖', '👾', '👽', '🤡', '👹', '💀', '🧠', '🥷🏼', '🕺🏼', '🐭', '🐹', '🐗', '🌝', '🌚', '🌈','☄️', '🧘🏼‍', '🚸']
greetings = ['bonjour', 'hola', 'hallo', 'sveiki', 'namaste', 'salaam', 'szia', 'halo', 'ciao']

bot.get_updates(fail_silently: true) do |message|
  command = message.get_command_for(bot)
  if !command.nil?
    puts "@#{message.from.username}: #{message.text}"
  end

  begin
    message.reply do |reply|
      case command
      when /start/i
        reply.text = hello_msg

      when /greetperson/i
        person = message.text.sub('/greetperson', '').strip

        if person.empty?
          reply.text = "No me vaciles 😡"
        else 
          reply.text = "#{greetings.sample.capitalize} #{person} !"
        end

      when /greet/i
        reply.text = "#{greetings.sample.capitalize} #{message.from.first_name}!"

      when /set_leaderboard/i
        token = message.text.sub('/set_leaderboard', '').strip

        # If no token was provided, show an error message
        if token.empty?
          reply.text = "Eeeee me estás vacilando? No me pasaste ningún token. Vuelve a intentarlo"
        else
          # Save in temporal memory
          leaderboards[message.chat.id] = token

          # Save in the SQLite3 database
          begin
            {message.chat.id => token}.each do |pair|
              db.execute 'INSERT INTO leaderboards VALUES (?, ?)', pair
            end
          rescue
            reply.text = "No he podido insertar tu código en la base de datos, pero sí en la memoria temporal. Esto significa que cuando el bot se reinicie, esta configuración se perderá."
          else
            reply.text = "Okey! He guardado que a este chat le corresponde el leaderboard #{token}"
          end

        end




      when /leaderboard/i
        token = leaderboards[message.chat.id]

        if token.nil?
          reply.text = "Este chat no tiene configurado el token de la leaderboard privada. Configúralo usando /set_leaderboard."
        else
          url = source + token.to_s + ".json"

          uri = URI(url.to_s)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Get.new(uri.request_uri)
          request['Cookie'] = "session=#{session_cookie}"
          resp = http.request(request)
          # puts resp.body

          data = resp.body.strip

          # puts resp.code

          if Integer(resp.code) != 200
            reply.text = "Algo fue mal con la request... Seguro que el token está bien?"
          else
            result = JSON.parse(data)

            msg = ""
            highScore = -1
            highScoreMember = ""

            highStar = -1
            highStarMember = ""

            members = result["members"]
            members.each do |x|
              member = x[1]
              member_id = x[0]
              score = Integer(member["local_score"])
              stars = member["stars"]
              name = member["name"]

              if score>highScore
                highScore = score
                highScoreMember = member_id
              end

              if stars>highStar
                highStar = stars
                highStarMember = member_id
              end

              msg += "* #{name}  #{emojis.sample}:   #{score}    👉🏼    (#{stars} 🌟)\n"
            end

            msg2 = "#{members[highStarMember]["stars"]} tiene más estrellas que nadie, #{highStar} 🌟, "

            if highStar == 0
              reply.text = msg
            else
              if highStarMember != highScoreMember
                msg2 += "pero #{members[highScoreMember]["name"]} va en cabeza con #{highScore} puntos!\n\n"
              else
                msg2 += "y también tiene la puntuación más alta: #{highScore} puntos!\n\n"
              end

              reply.message = msg2 + msg 
            end
          end
        end
      end

        if !reply.text.nil?
          puts "sending #{reply.text.inspect} to @#{message.from.username}"
          reply.send_with(bot)
        end
    end

  rescue TelegramBot::ResponseError => e
    retry
  end
end

