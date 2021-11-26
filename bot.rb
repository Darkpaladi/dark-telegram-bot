require 'telegram_bot'
require 'telegram_bot/response_error'
require 'net/http'
require 'net/https'
require 'cgi'
require 'yaml'
require 'sqlite3'

# Get the config
config = YAML.load_file('config.yml')

token = config['keys'][0]['token']
puts "Set `#{token}` as the token"

if config['messages'][0]['start'].nil?
  puts "There was not a start message in the config, using the default"
  hello_msg = "Hiya"  
else
  hello_msg = config['messages'][0]['start']
end

# Start the bot
bot = TelegramBot.new(token: token)

emojis = ['🤯', '😵‍', '💫', '😈', '🐷', '🥸', '🤗', '😶‍🌫️', '🤖', '👾', '👽', '🤡', '👹', '💀', '🧠', '🥷🏼', '🕺🏼', '🐭', '🐹', '🐗', '🌝', '🌚', '🌈','☄️', '🧘🏼‍', '🚸']
greetings = ['bonjour', 'hola', 'hallo', 'sveiki', 'namaste', 'salaam', 'szia', 'halo', 'ciao']
xokast = [ 'Tú cuando juegas a un videojuego y pierdes y no te enfadas y piensas que es un juego, eres una mierda. Eso es lo que eres', '¿Que pasa? CALLADITO', 'Sí soy mejor que vuestros novios y gano más dinero y soy más exitoso y probablemente soy más atractivo que ellos.', '¿Qué miras?', 'Aprende a valorarte.', 'Soy yo literal. Tú calla la boca.', 'Al contrario de lo que dice el refrán, Dios sí castiga dos veces. Y tres y cuatro y más.', 'No recuerdo haber hecho Magisterio para estar aquí como en parvulitos.', 'Esto no es un juego, nada es un juego.', 'Te relajas un poco, ¿vale?', 'Impresionante, así soy un p* pro, una persona profesional en todos los ámbitos de la vida.', '¿Tú quién te crees que eres, trozo de basura? Fuera de mi p* vista.']

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

      when /greet/i
        person = message.text.sub('/greet', '').strip
        if person.empty?
          reply.text = "#{greetings.sample.capitalize} #{message.from.first_name}!"
        else 
          reply.text = "#{greetings.sample.capitalize} #{person} !"
        end

      when /xokas/i
          reply.text = "#{xokast.sample}"

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

