class Api::V1::Accounts::InboxMessagesController < Api::V1::Accounts::BaseController
  before_action :set_inbox
  before_action :set_or_create_contact_inbox
  before_action :set_or_create_conversation

  def create
    return head :ok if @incoming_message.blank?

    @conversation.messages.create!(
      account_id: Current.account.id,
      inbox_id: @inbox.id,
      sender: @contact,
      content: @incoming_message,
      message_type: :incoming
    )

    head :ok
  end

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def set_or_create_contact_inbox
    payload = params[:payload] || {}
    data    = payload.dig(:_data, :Info) || {}

    sender_alt = data[:SenderAlt].presence || payload[:from].presence || ''
    phone = sender_alt.split(':').first.split('@').first
    phone = "+#{phone}" unless phone.start_with?('+')

    name = data[:PushName].presence || phone
    @incoming_message = payload[:body].presence

    @contact = Current.account.contacts.find_or_create_by!(phone_number: phone) do |c|
      c.name = name
      c.account_id = Current.account.id
    end

    @inbox.contact_inboxes.find_or_create_by!(contact: @contact, source_id: phone)
  end

  def set_or_create_conversation
    @conversation = @inbox.conversations
                          .where(contact_id: @contact.id)
                          .where(status: [:open, :pending])
                          .first

    @conversation ||= Conversation.create!(
      account_id: Current.account.id,
      contact_id: @contact.id,
      inbox_id: @inbox.id
    )
  end
end