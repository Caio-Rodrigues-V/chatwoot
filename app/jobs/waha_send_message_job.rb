class WahaSendMessageJob < ApplicationJob
  queue_as :high

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message
    return unless message.outgoing?
    return if message.private?

    conversation = message.conversation
    contact_inbox = conversation.contact_inbox
    source_id = contact_inbox&.source_id
    return unless source_id&.include?('@')

    inbox = message.inbox
    channel = inbox.channel
    return unless channel.is_a?(Channel::Api)

    waha_url = ENV.fetch('WAHA_API_URL', 'https://api.meuchatia.com.br')
    waha_token = ENV.fetch('WAHA_API_TOKEN', '')
    session = ENV.fetch('WAHA_SESSION', 'Comercialddm')

    uri = URI("#{waha_url}/api/sendText")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['X-Api-Key'] = waha_token
    request.body = {
      session: session,
      chatId: source_id,
      text: message.content
    }.to_json

    response = http.request(request)

    unless response.code.to_i == 200 || response.code.to_i == 201
      Rails.logger.error "WahaSendMessageJob failed: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "WahaSendMessageJob error: #{e.message}"
  end
end