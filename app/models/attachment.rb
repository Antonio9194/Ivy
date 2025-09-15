class Attachment < ApplicationRecord
  belongs_to :chat

  validates :file, presence: true
end
