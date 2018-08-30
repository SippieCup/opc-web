
require 'open-uri'
# == Schema Information
#
# Table name: vehicle_configs
#
#  id                       :bigint(8)        not null, primary key
#  title                    :string
#  year                     :integer
#  vehicle_make_id          :bigint(8)
#  vehicle_model_id         :bigint(8)
#  vehicle_trim_id          :bigint(8)
#  vehicle_config_status_id :bigint(8)
#  description              :text
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  vehicle_make_package_id  :bigint(8)
#  slug                     :string
#  parent_id                :integer
#  vehicle_config_type_id   :bigint(8)
#

class LookupValidator < ActiveModel::Validator
  def validate(record)
    if !record.new_record?
      dupes = VehicleConfig.where(%(
        (
          vehicle_configs.year = :year AND 
          vehicle_configs.vehicle_make_id = :vehicle_make AND 
          vehicle_configs.vehicle_model_id = :vehicle_model AND
          vehicle_configs.id != :current_id
        ) OR (
          vehicle_configs.year_end = :year AND 
          vehicle_configs.vehicle_make_id = :vehicle_make AND 
          vehicle_configs.vehicle_model_id = :vehicle_model AND
          vehicle_configs.id != :current_id
        ) OR (
          vehicle_configs.year_end = :year AND 
          vehicle_configs.vehicle_make_id = :vehicle_make AND 
          vehicle_configs.vehicle_model_id = :vehicle_model AND
          vehicle_configs.id != :current_id
        ) OR (
          vehicle_configs.year_end = :year_end AND 
          vehicle_configs.vehicle_make_id = :vehicle_make AND 
          vehicle_configs.vehicle_model_id = :vehicle_model AND
          vehicle_configs.id != :current_id
        ) OR (
          ((:year) BETWEEN vehicle_configs.year AND vehicle_configs.year_end) AND 
          vehicle_configs.vehicle_make_id = :vehicle_make AND 
          vehicle_configs.vehicle_model_id = :vehicle_model AND
          vehicle_configs.id != :current_id
        ) OR (
          ((:year_end) BETWEEN vehicle_configs.year AND vehicle_configs.year_end) AND 
          vehicle_configs.vehicle_make_id = :vehicle_make AND 
          vehicle_configs.vehicle_model_id = :vehicle_model AND
          vehicle_configs.id != :current_id
        )
      ), {
        year: record.year,
        year_end: record.year_end,
        vehicle_make: record.vehicle_make_id,
        vehicle_model: record.vehicle_model_id,
        current_id: record.id
      }).count
      else
        dupes = VehicleConfig.where(%(
          (
            vehicle_configs.year = :year AND 
            vehicle_configs.vehicle_make_id = :vehicle_make AND 
            vehicle_configs.vehicle_model_id = :vehicle_model
          ) OR (
            vehicle_configs.year_end = :year AND 
            vehicle_configs.vehicle_make_id = :vehicle_make AND 
            vehicle_configs.vehicle_model_id = :vehicle_model
          ) OR (
            vehicle_configs.year_end = :year AND 
            vehicle_configs.vehicle_make_id = :vehicle_make AND 
            vehicle_configs.vehicle_model_id = :vehicle_model
          ) OR (
            vehicle_configs.year_end = :year_end AND 
            vehicle_configs.vehicle_make_id = :vehicle_make AND 
            vehicle_configs.vehicle_model_id = :vehicle_model
          ) OR (
            ((:year) BETWEEN vehicle_configs.year AND vehicle_configs.year_end) AND 
            vehicle_configs.vehicle_make_id = :vehicle_make AND 
            vehicle_configs.vehicle_model_id = :vehicle_model
          ) OR (
            ((:year_end) BETWEEN vehicle_configs.year AND vehicle_configs.year_end) AND 
            vehicle_configs.vehicle_make_id = :vehicle_make AND 
            vehicle_configs.vehicle_model_id = :vehicle_model
          )
        ), {
          year: record.year,
          year_end: record.year_end,
          vehicle_make: record.vehicle_make_id,
          vehicle_model: record.vehicle_model_id
        }).count
      end

    if dupes > 0
      record.errors[:vehicle_model] << "The year, make, model you entered is already contained within an existing vehicle config."
    end
  end
end
class VehicleConfig < ApplicationRecord
  include Scraper
  include ActiveSupport::Inflector
  has_one_attached :image
  acts_as_votable
  has_paper_trail
  paginates_per 400

  # default_scope { includes(:vehicle_make, :vehicle_model, :vehicle_config_type).where(parent_id: nil).order("vehicle_makes.name, vehicle_models.name, year, vehicle_config_types.difficulty_level") }
  
  acts_as_nested_set dependent: :destroy
  extend FriendlyId
  friendly_id :name_for_slug, use: :slugged
  belongs_to :vehicle_make
  belongs_to :vehicle_model
  belongs_to :parent, :class_name => "VehicleConfig", :optional => true
  has_many :vehicle_config_vehicle_trims, -> { order('vehicle_trims.name') }, dependent: :delete_all
  has_many :vehicle_trims, :through => :vehicle_config_vehicle_trims
  has_many :forks, :class_name => "VehicleConfig", :foreign_key => :parent_id, dependent: :delete_all
  belongs_to :vehicle_config_status, :optional => true
  belongs_to :vehicle_make_package, :optional => true
  belongs_to :vehicle_config_type, :optional => true
  accepts_nested_attributes_for :forks
  before_validation :set_default
  before_validation :set_year_end
  # before_save :update_forks
  before_save :set_trim_styles_count
  before_create :set_refreshing
  # after_create :do_scrape_info
  def set_refreshing
    self.refreshing = true
  end
  # before_save :scrape_info
  before_validation :set_title
  validates_numericality_of :year
  validates_with LookupValidator, on: :create
  # MODIFICATIONS
  has_many :vehicle_config_modifications, dependent: :delete_all
  has_many :modifications, :through => :vehicle_config_modifications

  has_many :vehicle_config_hardware_items, dependent: :delete_all

  # CAPABILITIES
  has_many :vehicle_config_capabilities, dependent: :delete_all
  has_many :vehicle_capabilities, :through => :vehicle_config_capabilities

  # REPOSITORIES
  has_many :vehicle_config_repositories, dependent: :delete_all
  has_many :repositories, :through => :vehicle_config_repositories

  # REPOSITORIES
  has_many :vehicle_config_pull_requests, dependent: :delete_all
  has_many :pull_requests, :through => :vehicle_config_pull_requests
  friendly_id :name_for_slug, use: :slugged
  
  # OPTIONS
  # has_many :vehicle_model_options, :through => :vehicle_model
  # has_many :vehicle_options, :through => :vehicle_model_options
  
  has_many :vehicle_config_videos, dependent: :delete_all

  # FORK CONFIGURATION
  amoeba do
  end

  # def difficulty_level
  #   vehicle_config_type.difficulty_level
  # end
  def self.find_by_ymm(year, make, model)
    results = where(%(
      (
        vehicle_configs.year = :year AND 
        vehicle_configs.vehicle_make_id = :vehicle_make AND 
        vehicle_configs.vehicle_model_id = :vehicle_model
      ) OR (
        ((:year) BETWEEN vehicle_configs.year AND vehicle_configs.year_end) AND 
        vehicle_configs.vehicle_make_id = :vehicle_make AND 
        vehicle_configs.vehicle_model_id = :vehicle_model
      )
    ), {
      year: year,
      vehicle_make: make,
      vehicle_model: model
    })
    # byebug
  end

  def has_capability?(cap_id)
    vehicle_capabilities.exists?(id: cap_id)
  end

  def config_type_ids
    vehicle_config_capabilities.includes(:vehicle_config_type).order("vehicle_config_types.difficulty_level").map(&:vehicle_config_type_id).uniq
  end

  def combined_capabilities
    cap_ids = []
    cap_ids << vehicle_capabilities.map(&:id)
    
    forks.each do |fork|
      cap_ids << fork.vehicle_capabilities.map(&:id)
    end

    cap_ids = cap_ids.flatten.uniq

    VehicleCapability.where(id: cap_ids).order(:name)
  end

  def capability_matrix
    matrix = {}
    VehicleConfigType.all.each do |type|
      if config_type_ids.include?(type.id)
        matrix[type.name.parameterize.to_sym] = {}
        vehicle_capabilities.uniq.each do |capability|
          cap = VehicleConfigCapability.joins(:vehicle_config).where("(vehicle_configs.parent_id = :id OR vehicle_configs.id = :id) AND vehicle_configs.vehicle_config_type_id = :type_id AND vehicle_config_capabilities.vehicle_capability_id = :capability_id", { id: id, type_id: type.id, capability_id: capability.id })
          if cap.present?
            cap = cap.first

            if cap.timeout.present?
              if cap.vehicle_capability.name == "Driver Monitor (advanced, vision)"
                cap_value = "<span class=\"line\">Unlimited</span><span class=\"line\">#{cap.timeout_friendly} if disabled</span>".html_safe
              else
                cap_value = "<span class=\"line\">#{cap.timeout_friendly}</span>".html_safe
              end
            elsif cap.kph.present?
              cap_value = "<span class=\"line\">#{cap.mph} mph</span><span class=\"line\">#{cap.kph} kph</span>".html_safe
            else
              cap_value = "<span class=\"fa fa-check\"></span>".html_safe
            end

            matrix[type.name.parameterize.to_sym][:"#{capability.name.parameterize}"] = {
              value: cap_value,
              label: type.name,
              details: type.description,
              capability: cap
            }
          end
        end
      end
    end

    matrix
  end

  def difficulty_class
    case minimum_difficulty
    when "Advanced"
      "danger"
    when "Standard"
      "info"
    when "Basic"
      "warning"
    else
      "danger"
    end
  end

  def minimum_difficulty
    if !forks.blank?
      sorted_forks = forks.joins(:vehicle_config_type).order("vehicle_config_types.difficulty_level ASC")

      if !sorted_forks.first.vehicle_config_type.name.blank?
        sorted_forks.first.vehicle_config_type.name
      else
        'Advanced'
      end
    else
      'Advanced'
    end
  end

  def name_for_slug
    if vehicle_config_type && vehicle_make && vehicle_model
      "#{id} #{year} #{vehicle_make.name} #{vehicle_model.name} #{vehicle_config_type.name}"
    end
  end

  def is_upstreamed?
    if !vehicle_config_status.blank?
      vehicle_config_status.name == 'Upstreamed'
    end
  end

  def is_community_supported?
    if !vehicle_config_status.blank?
      vehicle_config_status.name == 'Community'
    end
  end
  
  def is_pull_request?
    if !vehicle_config_status.blank?
      vehicle_config_status.name == 'Pull Request'
    end
  end
  
  def is_in_development?
    if !vehicle_config_status.blank?
      vehicle_config_status.name == 'In Development'
    end
  end

  def status_classes
    if !vehicle_config_status.blank?
      case vehicle_config_status.name
      when "Community"
        {
          :icon => "fa fa-users",
          :color => "danger",
          :url => latest_repository.repository.blank? ? nil : latest_repository.repository.url,
          :tooltip => "Community Supported in #{latest_repository.repository.blank? ? nil : latest_repository.repository.full_name}",
          :label => "#{latest_repository.repository.blank? ? nil : latest_repository.repository.full_name}#{latest_repository.repository_branch.blank? ? nil : '#' + latest_repository.repository_branch.name}"
        }
      when "In Development"
        {
          :icon => "fa fa-code",
          :color => "warning",
          :tooltip => vehicle_config_status.name,
          :url => (!latest_repository.blank? && !latest_repository.repository.blank?) ? latest_repository.repository.url : nil,
          :label => (!latest_repository.blank? && !latest_repository.repository.blank?) ? "#{latest_repository.repository.full_name}#{latest_repository.repository_branch.blank? ? nil : '#' + latest_repository.repository_branch.name}" : nil
        }
      when "Pull Request"
        {
          :icon => "fa fa-hourglass",
          :color => "info",
          :tooltip => (!latest_open_pull_request.blank?) ? "#{vehicle_config_status.name} ##{latest_open_pull_request.number}" : vehicle_config_status.name,
          :url => (!latest_open_pull_request.blank?) ? latest_open_pull_request.html_url : nil,
          :label => (!latest_repository.blank? && !latest_repository.repository.blank?) ? "#{latest_repository.repository.full_name}#{latest_repository.repository_branch.blank? ? nil : '#' + latest_repository.repository_branch.name}" : nil,
        }
      when "Upstreamed"
        {
          :icon => "fa fa-check",
          :color => "success",
          :tooltip => "Upstreamed to commaai/openpilot",
          :url => (!latest_repository.blank? && !latest_repository.repository.blank?) ? latest_repository.repository.url : nil,
          :label => (!latest_repository.blank? && !latest_repository.repository.blank?) ? "#{latest_repository.repository.full_name}#{latest_repository.repository_branch.blank? ? nil : '#' + latest_repository.repository_branch.name}" : nil,
        }
      when "Researching"
        {
          :icon => "fa fa-globe",
          :color => "default",
          :tooltip => vehicle_config_status.name.downcase,
          :url => "#",
          :label => "Researching"
        }
      when "Archived"
        {
          :icon => "fa fa-archive",
          :color => "default",
          :tooltip => vehicle_config_status.name.downcase,
          :url => "#",
          :label => "fa fa-archive"
        }
      else
        {
          :icon => "fa fa-globe",
          :color => "default",
          :tooltip => "Researching",
          :url => "#",
          :label => "Researching"
        }
      end
    else
      {
        :icon => "fa fa-globe",
        :color => "default",
        :tooltip => "Researching",
        :url => "#",
        :label => "Researching"
      }
    end
  end
  
  def latest_repository
    if !vehicle_config_repositories.blank?
      if repositories = vehicle_config_repositories.joins(:repository).order("repositories.id DESC")
        if !repositories.blank?
          repositories.first
        end
      end
    end
  end

  def latest_open_pull_request
    if !vehicle_config_pull_requests.blank?
      if open_prs = vehicle_config_pull_requests.joins(:pull_request).where(pull_requests: { state: "open" }).order("pull_requests.number DESC")
        if !open_prs.blank?
          open_prs.first.pull_request
        end
      end
    end
  end

  def set_year_end
    if year.to_i > year_end.to_i
      self.year_end = self.year.to_i
    end
  end

  def name
    new_name = "Untitled"
    if vehicle_config_type && vehicle_make && vehicle_model
      new_name = "#{year_range_str} #{vehicle_make.name} #{vehicle_model.name}"
      # if vehicle_trims
      #   new_name = "#{new_name} #{vehicle_trims.map {|trim| trim.name }.join(", ")}"
      # end
      # if vehicle_make_package
      #   new_name = "#{new_name} w/ #{vehicle_make_package.name}"
      # end
      # if vehicle_config_type
      #   new_name = "#{new_name}"
      # end
    end

    new_name
  end

  # def author_ids=(ids)
  #   self.authors = Array(ids).reject(&:blank?).map { |id|
  #     (id =~ /^\d+$/) ? Author.find(id) : Author.new(name: id)
  #   }
  # end
  def has_year_end?
    !self.year_end.blank?
  end

  def year_range=(ystart, year_end)
    if !ystart.blank? && !yend.blank?
      self.year = ystart
      self.year_end = yend
    elsif ystart.blank? && !yend.blank?
      self.year = yend
      self.year_end = yend
    elsif !ystart.blank? && yend.blank?
      self.year = ystart
      self.year_end = ystart
    else
      self.year = nil
      self.year_end = nil
    end
  end

  def year_range
    if !year.blank? && !year_end.blank?
      if (year <= year_end)
        (year..year_end)
      else
        (year..year)
      end
    elsif year.blank? && !year_end.blank?
      (year_end..year_end)
    elsif !year.blank? && year_end.blank?
      (year..year)
    else
      (1917..1917)
    end
  end

  def year_range_str
    if has_year_end? && year != year_end
      "#{year}-#{year_end}"
    elsif has_year_end? && year.blank?
      "#{year_end}"
    else
      "#{year}"
    end
  end

  def vehicle_trim_ids=(ids)
    self.vehicle_trims = Array(ids).reject(&:blank?).map do |id|
      (id =~ /^\d+$/) ? VehicleTrim.find(id) : VehicleTrim.new(name: id, vehicle_model: self.vehicle_model)
    end
  end
  
  def vehicle_trim_names
    vehicle_trims.map(&:name).join(", ")
  end
  
  def has_parent?
    !self.parent.blank?
  end

  def update_forks
    if !forks.blank?
      forks.each do |fork|
        fork.year = year if year
        fork.year_end = year_end if year_end
        fork.vehicle_make = vehicle_make if vehicle_make
        fork.vehicle_model = vehicle_model if vehicle_model
        fork.vehicle_trims = vehicle_trims if vehicle_trims
        fork.vehicle_make_package = vehicle_make_package
      end
    end
  end
  
  def capability_count
    vehicle_capabilities.size
  end

  def is_factory?
    vehicle_config_type.name == 'Factory'
  end

  def is_standard?
    vehicle_config_type.name == 'Standard'
  end

  def is_basic?
    vehicle_config_type.name == 'Basic'
  end

  def is_advanced?
    vehicle_config_type.name == 'Advanced'
  end

  def has_standard
    forks.exists?(:vehicle_config_type => VehicleConfigType.find_by(:name => "Standard"))
  end

  def has_basic
    forks.exists?(:vehicle_config_type => VehicleConfigType.find_by(:name => "Basic"))
  end

  def has_advanced
    forks.exists?(:vehicle_config_type => VehicleConfigType.find_by(:name => "Advanced"))
  end

  def set_default
    if self.parent.blank? && self.vehicle_config_type.blank?
      self.vehicle_config_type = VehicleConfigType.find_by(:name => "Factory")
    end
  end

  def full_support_difficulty
    # forks.
  end
  
  def set_trim_styles_count
    if parent_id.blank?
      if !trim_styles.blank? && trim_styles.count > 0
        self.trim_styles_count = trim_styles.count
      else
        self.trim_styles_count = 0
      end
    end
  end

  def specs
    vehicle_model.vehicle_trims.joins("
      INNER JOIN vehicle_trim_styles ON vehicle_trim_styles.vehicle_trim_id = vehicle_trims.id
      INNER JOIN vehicle_trim_style_specs ON vehicle_trim_style_specs.vehicle_trim_style_id = vehicle_trim_styles.id
      ")
  end
  # VehicleModel.find_by(name: "Civic").vehicle_trims.map(&:id)
  # def capability_groups
  #   vehicle_trim_styles.joins(:vehicle_trim_style_specs).group(:id,:group)
  # end

  def trim_styles
    VehicleTrimStyle.joins(:vehicle_trim).where('vehicle_trims.year IN (:years) AND vehicle_trim_id IN (:trim_ids)',{ :years => year_range, :trim_ids => vehicle_model.vehicle_trims.map(&:id) }).order("vehicle_trims.year, vehicle_trims.sort_order, vehicle_trim_styles.name")
  end

  

  def fork_config
    self.class.amoeba do
      enable
      include_association :vehicle_config_capabilities
      include_association :vehicle_capabilities
      include_association :vehicle_config_modifications
      include_association :modifications
      nullify :slug
      # customize(lambda { |original_post,new_post|
      #   next_difficulty_level = original_post.vehicle_config_type.difficulty_level+1
      #   max_difficulty_level = VehicleConfigType.maximum("difficulty_level")
      #   if next_difficulty_level <= max_difficulty_level
      #     new_config_type = VehicleConfigType.find_by(:difficulty_level => next_difficulty_level)
      #   else
      #     new_config_type = VehicleConfigType.find_by(:difficulty_level => max_difficulty_level)
      #   end
      #   new_post.vehicle_config_type = new_config_type
      # })
      # customize(lambda { |original_post,new_post|
      #   new_post.parent = original_post
      # })
    end
    self.amoeba_dup
  end

  def copy_config
    has_forks = forks.size
    self.class.amoeba do
      enable
      include_association :vehicle_config_capabilities
      include_association :vehicle_capabilities
      include_association :vehicle_config_modifications
      include_association :modifications
      include_association :vehicle_trims
      include_association :forks
    end
    self.amoeba_dup
  end

  # def diff_from(veh_conf)
  #   HashDiff.diff(veh_conf.diff_object,self.diff_object)
  # end

  # def diff_from_parent
  #   if !parent.blank?
  #     diff_from(parent)
  #   end
  # end
  private
  def name_for_slug
    if vehicle_config_type && vehicle_make && vehicle_model
      "#{id} #{year_range_str} #{vehicle_make.name} #{vehicle_model.name} #{vehicle_config_type.name}"
    end
  end

  def set_title
    self.title = "#{year_range_str} #{vehicle_make.name} #{vehicle_model.name} #{vehicle_config_type.name}"
  end

  # def diff_object
  #   {
  #     :year => year,
  #     :make => vehicle_make.name,
  #     :model => vehicle_model.name,
  #     :status => vehicle_config_status.name,
  #     :capabilities => vehicle_config_capabilities.map do |capability|
  #       {
  #         :name => capability.vehicle_capability.name,
  #         :slug => capability.vehicle_capability.slug,
  #         :kph => capability.kph,
  #         :mph => capability.mph,
  #         :timeout => capability.timeout
  #       }
  #     end,
  #     :modifications => modifications.map do |mod|
  #       mod.attributes
  #     end
  #   }
  # end

  # def to_param
  #   slug
  # end

  def is_root
    self.parent.blank?
  end
end
