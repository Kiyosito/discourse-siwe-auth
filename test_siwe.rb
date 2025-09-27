#!/usr/bin/env ruby
# Este script testa a funcionalidade da gem siwe

require 'siwe'

# Criar uma mensagem SIWE simples
message_str = "forum.kiyosito.io wants you to sign in with your Ethereum account:
0xf76666D7327E028Bc458CB3ce19FA647274F5AE3

Authenticate with ITO to access Kiyosito DAO discussions.

URI: https://forum.kiyosito.io
Version: 1
Chain ID: 1
Nonce: BPyfG80P0VQ55O45
Issued At: 2025-09-27T23:40:59Z"

puts "Tentando parsear a mensagem SIWE..."
begin
  # Parsear a mensagem
  siwe_msg = Siwe::Message.from_message(message_str)
  
  # Verificar se o método to_h existe
  if siwe_msg.respond_to?(:to_h)
    puts "O método to_h existe na versão da gem siwe"
    puts "Resultado de to_h: #{siwe_msg.to_h.inspect}"
  else
    puts "O método to_h NÃO existe na versão da gem siwe"
    puts "Atributos disponíveis:"
    puts "- address: #{siwe_msg.address}"
    puts "- domain: #{siwe_msg.domain}"
    puts "- uri: #{siwe_msg.uri}"
    puts "- version: #{siwe_msg.version}"
    puts "- chain_id: #{siwe_msg.chain_id}"
    puts "- nonce: #{siwe_msg.nonce}"
    puts "- issued_at: #{siwe_msg.issued_at}"
    puts "- expiration_time: #{siwe_msg.expiration_time}"
    puts "- not_before: #{siwe_msg.not_before}"
    puts "- request_id: #{siwe_msg.request_id}"
    puts "- resources: #{siwe_msg.resources}"
    puts "- statement: #{siwe_msg.statement}"
  end
  
  # Testar o método verify
  puts "\nTestando os argumentos do método verify..."
  
  # Verificar os parâmetros aceitos pelo método verify
  begin
    # Tentativa com nonce e domain
    siwe_msg.verify(signature: "0x1234", domain: "forum.kiyosito.io", nonce: "BPyfG80P0VQ55O45")
    puts "verify aceita os parâmetros signature, domain e nonce"
  rescue ArgumentError => e
    puts "Erro ao chamar verify com domain e nonce: #{e.message}"
  rescue => e
    puts "Outro erro ao verificar com domain e nonce: #{e.class}: #{e.message}"
  end
  
  begin
    # Tentativa só com nonce
    siwe_msg.verify(signature: "0x1234", nonce: "BPyfG80P0VQ55O45")
    puts "verify aceita os parâmetros signature e nonce"
  rescue ArgumentError => e
    puts "Erro ao chamar verify só com nonce: #{e.message}"
  rescue => e
    puts "Outro erro ao verificar só com nonce: #{e.class}: #{e.message}"
  end
  
rescue => e
  puts "Erro ao parsear a mensagem: #{e.class}: #{e.message}"
  puts "Backtrace: #{e.backtrace.join("\n")}"
end
