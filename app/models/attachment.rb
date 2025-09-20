class Attachment < ApplicationRecord
  belongs_to :chat
  has_one_attached :photo

  validates :photo, presence: true
end
