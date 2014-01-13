class Post < ActiveRecord::Base

  validates :title, :author, presence: true
  validates :description, length: { minimum: 20 }

end
