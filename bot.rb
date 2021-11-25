require 'telegram_bot'
require 'telegram_bot/response_error'
require 'net/http'
require 'net/https'
require 'cgi'
require 'yaml'

# Get the config
config = YAML.load_file('config.yml')

token = config['keys'][0]['token']
puts "Set `#{token}` as the token"

session_cookie = config['keys'][0]['cookie']
puts "Set `#{session_cookie}` as the session cookie"

source = "https://adventofcode.com/#{config['keys'][0]['year']}/leaderboard/private/view/"

leaderboards = Hash.new

if config['messages'][0]['start'].nil?
  puts "There was not a start message in the config, using the default"
  hello_msg = "Hola! Me han creado con el propósito de pasar la mantequilla.\n\nNah, mira las opciones que tengo disponibles y úsame senpai."  
else
  hello_msg = config['messages'][0]['start']
end

# Start the bot
bot = TelegramBot.new(token: token)

emojis = ['🤯', '😵‍', '💫', '😈', '🐷', '🥸', '🤗', '😶‍🌫️', '🤖', '👾', '👽', '🤡', '👹', '💀', '🧠', '🥷🏼', '🕺🏼', '🐭', '🐹', '🐗', '🌝', '🌚', '🌈','☄️', '🧘🏼‍', '🚸']

bot.get_updates(fail_silently: true) do |message|
  command = message.get_command_for(bot)
  if !command.empty?
    puts "@#{message.from.username}: #{message.text}"
  end

  begin
    message.reply do |reply|
      case command
      when /start/i
        reply.text = hello_msg


      when /greet/i
        greetings = ['bonjour', 'hola', 'hallo', 'sveiki', 'namaste', 'salaam', 'szia', 'halo', 'ciao']
        reply.text = "#{greetings.sample.capitalize} #{message.from.first_name}!"
        puts "Chat ID: #{message.chat.id}."




      when /set_leaderboard/i
        token = message.text.sub('/set_leaderboard', '').strip

        if token.empty?
          reply.text = "Eeeee me estás vacilando? No me pasaste ningún token. Vuelve a intentarlo"
        else
          leaderboards[message.chat.id] = token

          reply.text = "Okey! He guardado que a este chat le corresponde el leaderboard #{token}"
        end



      when /leaderboard/i
        token = leaderboards[message.chat.id]

        if token.nil?
          reply.text = "Este chat no tiene configurado el token de la leaderboard privada. Configúralo usando /set_leaderboard."
        else
          url = source + token + ".json"

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

