class Api::V1::Accounts::InboxMessagesController < Api::V1::Accounts::BaseController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :authenticate_access_token!, raise: false
  skip_before_action :check_subscription, raise: false
  skip_before_action :validate_bot_access_token!, raise: false

  def create
    return head :ok unless params[:event] == 'message' && params.dig(:payload, :fromMe) == false

    payload = params[:payload] || {}
    data    = payload.dig(:_data, :Info) || {}

    sender_alt = data[:SenderAlt].presence || payload[:from].presence || ''
    phone = sender_alt.split(':').first.split('@').first
    phone = "+#{phone}" unless phone.start_with?('+')
    name = data[:PushName].presence || phone
    content = payload[:body].presence

    return head :ok if content.blank?

    account = Account.find(params[:account_id])
    inbox   = account.inboxes.find(params[:inbox_id])

    contact = account.contacts.find_or_create_by!(phone_number: phone) do |c|
      c.name = name
      c.account_id = account.id
    end

    contact_inbox = ContactInbox.find_or_create_by!(
      inbox: inbox,
      contact: contact
    ) do |ci|
      ci.source_id = phone
    end

    conversation = inbox.conversations
                        .where(contact_id: contact.id)
                        .where(status: [:open, :pending])
                        .first

    conversation ||= Conversation.create!(
      account_id: account.id,
      contact_id: contact.id,
      inbox_id: inbox.id,
      contact_inbox_id: contact_inbox.id
    )

    conversation.messages.create!(
      account_id: account.id,
      inbox_id: inbox.id,
      sender: contact,
      content: content,
      message_type: :incoming
    )

    head :ok
  end
end