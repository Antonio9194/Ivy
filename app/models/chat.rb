class Chat < ApplicationRecord
  belongs_to :user
  has_many :attachments, dependent: :destroy

  validates :content, presence: true
end
