class Category < ApplicationRecord
  # Full class names so Tailwind picks them up
  COLORS = {
    "orange" => "bg-orange-500/15 text-orange-700 dark:text-orange-300",
    "lime" => "bg-lime-500/15 text-lime-700 dark:text-lime-300",
    "sky" => "bg-sky-500/15 text-sky-700 dark:text-sky-300",
    "amber" => "bg-amber-500/15 text-amber-700 dark:text-amber-300",
    "cyan" => "bg-cyan-500/15 text-cyan-700 dark:text-cyan-300",
    "red" => "bg-red-500/15 text-red-700 dark:text-red-300",
    "violet" => "bg-violet-500/15 text-violet-700 dark:text-violet-300",
    "pink" => "bg-pink-500/15 text-pink-700 dark:text-pink-300",
    "fuchsia" => "bg-fuchsia-500/15 text-fuchsia-700 dark:text-fuchsia-300",
    "indigo" => "bg-indigo-500/15 text-indigo-700 dark:text-indigo-300",
    "teal" => "bg-teal-500/15 text-teal-700 dark:text-teal-300",
    "stone" => "bg-stone-500/15 text-stone-700 dark:text-stone-300",
    "blue" => "bg-blue-500/15 text-blue-700 dark:text-blue-300",
    "emerald" => "bg-emerald-500/15 text-emerald-700 dark:text-emerald-300",
    "green" => "bg-green-500/15 text-green-700 dark:text-green-300",
    "gray" => "bg-gray-500/15 text-gray-700 dark:text-gray-300"
  }.freeze

  has_many :entries, dependent: :nullify
  has_many :merchant_categories, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :color, inclusion: { in: COLORS.keys }

  scope :alphabetical, -> { order(:name) }

  def badge_classes
    COLORS.fetch(color, COLORS["gray"])
  end
end
