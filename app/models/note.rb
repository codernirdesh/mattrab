class Note < ApplicationRecord
  before_update :unpublish_if_unverified
  after_update :create_notifications

  validates :title, presence: true
  validates :body, presence: true

  enum grade: [:twelve, :eleven]
  enum category: [:physics, :chemistry, :biology, :maths, :computer, :english, :nepali, :pastpapers, :solution]
  enum status: [:draft, :published]

  acts_as_votable
  acts_as_taggable_on :tags

  belongs_to :user
  belongs_to :grade
  belongs_to :category
  has_many :questions, dependent: :delete_all

  has_attached_file :image, styles: { medium: "700x500#", small: "350x250>" }, default_url: "/images/small/missing.png"
  validates_attachment_content_type :image, content_type: /\Aimage\/.*\z/

  include PgSearch
  pg_search_scope :search, against: [:title, :body],
    using: {tsearch: {dictionary: 'english'}},
    associated_against: {user: :name, questions: :content}

  def to_param
    "#{id} #{title}".parameterize
  end

  def unpublish_if_unverified
    if self.is_verified_changed? and self.is_verified == false and self.published?
      self.status = "draft"
    end
  end

  def request_verification(admin)
    if self.is_verified == false
      Notification.create(recipient: admin, actor: self.user, action: 'asked for Verification of', notifiable: self)
    end
  end

  def create_notifications
    if self.status_changed? and self.is_verified == true and self.published?
      self.user.followers.each do |recipient|
        Notification.create(recipient: recipient, actor: self.user, action: 'updated', notifiable: self)
      end
    end
  end
end
