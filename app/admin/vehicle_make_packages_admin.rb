Trestle.resource(:vehicle_make_packages) do

  # Customize the table columns shown on the index view.
  #
  table do
    column :name, link: true
    # column :created_at, align: :center
    # actions
  end

  # Customize the form fields shown on the new/edit views.
  #
  # form do |vehicle_make_package|
  #   text_field :name
  #
  #   row do
  #     col(xs: 6) { datetime_field :updated_at }
  #     col(xs: 6) { datetime_field :created_at }
  #   end
  # end

  # By default, all parameters passed to the update and create actions will be
  # permitted. If you do not have full trust in your users, you should explicitly
  # define the list of permitted parameters.
  #
  # For further information, see the Rails documentation on Strong Parameters:
  #   http://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
  #
  # params do |params|
  #   params.require(:vehicle_make_package).permit(:name, ...)
  # end
end
