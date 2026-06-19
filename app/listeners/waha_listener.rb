class WahaListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.outgoing?
    return if message.private?
    return unless message.inbox&.channel.is_a?(Channel::Api)

    WahaSendMessageJob.perform_later(message.id)
  end
end