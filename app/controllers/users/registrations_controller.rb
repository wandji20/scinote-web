class Users::RegistrationsController < Devise::RegistrationsController
  prepend_before_action :check_captcha, only: [:create]
  before_action :registration_enabled?,
                only: %i(new create new_with_provider create_with_provider)
  before_action :sign_up_with_provider_enabled?,
                only: %i(new_with_provider create_with_provider)
  layout :layout

  def avatar
    user = User.find_by_id(params[:id]) || current_user
    style = params[:style] || :icon_small
    redirect_to user.avatar_url(style)
  end

  def update_resource(resource, params)
    @user_avatar_url = avatar_path(current_user, :thumb)

    if params.include? :change_password
      # Special handling if changing password
      params.delete(:change_password)
      if resource.valid_password?(params[:current_password]) &&
         params.include?(:password) &&
         params.include?(:password_confirmation) &&
         params[:password].blank?
        # If new password is blank and we're in process of changing
        # password, add error to the resource and return false
        resource.errors.add(:password, :blank)
        false
      else
        resource.update_with_password(params)
      end
    elsif params.include? :change_avatar
      params.delete(:change_avatar)
      if !params.include?(:avatar) || (params[:avatar].length > Constants::AVATAR_MAX_SIZE_MB.megabytes * 2)
        resource.errors.add(:avatar, :blank)
        false
      else
        temp_file = Tempfile.new('avatar', Rails.root.join('tmp'))
        begin
          check_extension = params[:avatar].split(';')[0].split('/')[1]
          temp_file.binmode
          temp_file.write(Base64.decode64(params[:avatar].split(',')[1]))
          temp_file.rewind
          resource.avatar.attach(io: temp_file, filename: "avatar.#{check_extension}")
        ensure
          temp_file.close
          temp_file.unlink
        end
        params.delete(:avatar)
        resource.update_without_password(params)
      end
    elsif params.include?(:email) || params.include?(:password)
      # For changing email or password, validate current_password
      resource.update_with_password(params)
    else
      # For changing some attributes, no current_password validation
      # is required
      resource.update_without_password(params)
    end
  end

  # Override default registrations_controller.rb implementation
  # to support JSON
  def update
    change_password = account_update_params.include? :change_password
    respond_to do |format|
      self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
      prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

      resource_updated = update_resource(resource, account_update_params)

      yield resource if block_given?
      if resource_updated
        # Set "needs confirmation" flash if neccesary
        if is_flashing_format? || account_update_params['change_avatar']
          flash_key = update_needs_confirmation?(resource, prev_unconfirmed_email) ?
            :update_needs_confirmation : :updated
          set_flash_message :notice, flash_key
        end

        # Set "password successfully updated" flash if neccesary
        if change_password
          set_flash_message :notice, :password_changed
        end

        format.html {
          sign_in resource_name, resource, bypass: true
          respond_with resource, location: edit_user_registration_path
        }
        format.json {
          flash.keep
          sign_in resource_name, resource, bypass: true
          render json: {}
        }
      else
        clean_up_passwords resource
        format.html {
          respond_with resource, location: edit_user_registration_path
        }
        format.json {
          render json: resource.errors, status: :bad_request
        }
      end
    end
  end

  def new; end

  def create
    build_resource(sign_up_params)
    valid_resource = resource.valid?
    # ugly checking if new team on sign up is enabled :(
    if Rails.configuration.x.new_team_on_signup
      # Create new team for the new user
      @team = Team.new
      @team.name = params[:team][:name]
      valid_team = @team.valid?

      if valid_team && valid_resource
        # this must be called after @team variable is defined. Otherwise this
        # variable won't be accessable in view.
        super do |resource|
          # Set the confirmed_at == created_at IF not using email confirmations
          unless Rails.configuration.x.enable_email_confirmations
            resource.update(confirmed_at: resource.created_at)
          end

          if resource.valid? && resource.persisted?
            @team.created_by = resource # set created_by for oraganization
            @team.save

            # Add this user to the team as owner
            UserTeam.create(user: resource, team: @team, role: :admin)

            # set current team to new user
            resource.current_team_id = @team.id
            resource.save
          end
        end
      else
        render :new
      end
    elsif valid_resource
      super do |resource|
        # Set the confirmed_at == created_at IF not using email confirmations
        unless Rails.configuration.x.enable_email_confirmations
          resource.update(confirmed_at: resource.created_at)
          resource.save
        end
      end
    else
      render :new
    end
  end

  def new_with_provider; end

  def create_with_provider
    @user = User.find_by_id(user_provider_params['user'])
    # Create new team for the new user
    @team = Team.new(team_provider_params)

    if @team.valid? && @user && Rails.configuration.x.new_team_on_signup
      # Set the confirmed_at == created_at IF not using email confirmations
      unless Rails.configuration.x.enable_email_confirmations
        @user.update!(confirmed_at: @user.created_at)
      end

      @team.created_by = @user # set created_by for team
      @team.save!

      # Add this user to the team as owner
      UserTeam.create(user: @user, team: @team, role: :admin)

      # set current team to new user
      @user.current_team_id = @team.id
      @user.save!

      sign_in_and_redirect @user
    else
      render :new_with_provider
    end
  end

  def two_factor_enable
    totp = ROTP::TOTP.new(current_user.otp_secret, issuer: 'SciNote')
    if totp.verify(params[:submit_code], drift_behind: 10)
      current_user.update!(two_factor_auth_enabled: true)
      redirect_to edit_user_registration_path
    else
      render json: { error: t('users.registrations.edit.2fa_errors.wrong_submit_code') }, status: :unprocessable_entity
    end
  end

  def two_factor_disable
    if current_user.valid_password?(params[:password])
      current_user.update!(two_factor_auth_enabled: false, otp_secret: nil)
      redirect_to edit_user_registration_path
    else
      render json: { error: t('users.registrations.edit.2fa_errors.wrong_password') }, status: :forbidden
    end
  end

  def two_factor_qr_code
    current_user.ensure_2fa_token
    qr_code_url = ROTP::TOTP.new(current_user.otp_secret, issuer: 'SciNote').provisioning_uri(current_user.email)
    qr_code = RQRCode::QRCode.new(qr_code_url)
    render json: { qr_code: qr_code.as_svg }
  end

  protected

  # Called upon creating User (before .save). Permits parameters and extracts
  # initials from :full_name (takes at most 4 chars). If :full_name is empty, it
  # uses "PLCH" as a placeholder (user won't get error complaining about
  # initials being empty.
  def sign_up_params
    tmp = params.require(:user).permit(:full_name, :initials, :email, :password, :password_confirmation)
    initials = tmp[:full_name].titleize.scan(/[A-Z]+/).join()
    initials = if initials.strip.empty?
                 'PLCH'
               else
                 initials[0..Constants::USER_INITIALS_MAX_LENGTH]
               end
    tmp.merge(:initials => initials)
  end

  def team_provider_params
    params.require(:team).permit(:name)
  end

  def user_provider_params
    params.permit(:user)
  end

  def account_update_params
    params.require(:user).permit(
      :full_name,
      :initials,
      :avatar,
      :email,
      :password,
      :password_confirmation,
      :current_password,
      :change_password,
      :change_avatar
    )
  end

  def avatar_params
    params.permit(
      :file
    )
  end

  private

  def layout
    'fluid' if action_name == 'edit'
  end

  def check_captcha
    if Rails.configuration.x.enable_recaptcha
      unless verify_recaptcha
        # Construct new resource before rendering :new
        self.resource = resource_class.new sign_up_params

        # Also validate team
        @team = Team.new(name: params[:team][:name])
        @team.valid?

        respond_with_navigational(resource) { render :new }
      end
    end
  end

  def registration_enabled?
    render_403 unless Rails.configuration.x.enable_user_registration
  end

  def sign_up_with_provider_enabled?
    render_403 unless Rails.configuration.x.linkedin_signin_enabled
  end

  # Redirect to login page after signing up
  def after_sign_up_path_for(resource)
    new_user_session_path
  end

  # Redirect to login page after signing up
  def after_inactive_sign_up_path_for(resource)
    new_user_session_path
  end
end
