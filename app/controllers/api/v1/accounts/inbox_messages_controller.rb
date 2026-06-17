class Api::V1::Accounts::InboxMessagesController < Api::V1::Accounts::BaseController
  before_action :set_inbox
  before_action :set_or_create_contact_inbox
  before_action :set_or_create_conversation

  def create
    message = @conversation.messages.create!(
      account_id: Current.account.id,
      inbox_id: @inbox.id,
      sender: @contact,
      content: params[:content],
      message_type: :incoming
    )
    render json: { id: message.id, content: message.content }, status: :created
  end

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def set_or_create_contact_inbox
    phone = params.dig(:contact, :phone_number) || params.dig(:sender, :phone) || params[:source_id]
    name = params.dig(:contact, :name) || phone

    @contact = Current.account.contacts.find_or_create_by!(phone_number: phone) do |c|
      c.name = name
      c.account_id = Current.account.id
    end

    @inbox.contact_inboxes.find_or_create_by!(
      contact: @contact,
      source_id: phone
    )
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