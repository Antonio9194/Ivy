class Chat < ApplicationRecord
  belongs_to :user
  has_many :attachments, dependent: :destroy
  accepts_nested_attributes_for :attachments, allow_destroy: true

  validates :content, presence: true

  # Trigger only when response changes
  after_update_commit :broadcast_response, if: :saved_change_to_response?

  private

  def broadcast_response
    broadcast_replace_to "user_#{user.id}_chats",
                         target: "chat_#{id}",
                         partial: "chats/chat",
                         locals: { chat: self }
  end
end