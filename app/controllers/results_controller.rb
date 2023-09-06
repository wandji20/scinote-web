# frozen_string_literal: true

class ResultsController < ApplicationController
  include Breadcrumbs
  skip_before_action :verify_authenticity_token, only: %i(create update destroy duplicate)
  before_action :load_my_module
  before_action :load_vars, only: %i(destroy elements assets upload_attachment archive restore destroy
                                     update_view_state update_asset_view_mode update duplicate)
  before_action :check_destroy_permissions, only: :destroy
  before_action :set_breadcrumbs_items, only: %i(index)
  before_action :set_navigator, only: %i(index)

  def index
    respond_to do |format|
      format.json do
        # API endpoint
        @results = if params[:view_mode] == 'archived'
                     @my_module.results.archived
                   else
                     @my_module.results.active
                   end

        apply_sort!
        apply_filters!

        @results = @results.page(params[:page] || 1)

        render(
          json: {
            results: @results.map do |r|
                       {
                         attributes: ResultSerializer.new(r, scope: current_user).as_json
                       }
                     end,
            next_page: @results.next_page
          },
          formats: :json
        )
      end

      format.html do
        # Main view
        @experiment = @my_module.experiment
        @project = @experiment.project
        render(:index, formats: :html)
      end
    end
  end

  def create
    result = @my_module.results.create!(user: current_user)

    render json: result
  end

  def update
    @result.update!(result_params)

    render json: @result
  end

  def archive
    if @result.archive(current_user)
      render json: {}, status: :ok
    else
      render json: { errors: @result.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def restore
    if @result.restore(current_user)
      render json: {}, status: :ok
    else
      render json: { errors: @result.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def elements
    render json: @result.result_orderable_elements.order(:position),
           each_serializer: ResultOrderableElementSerializer,
           user: current_user
  end

  def assets
    render json: @result.assets,
           each_serializer: AssetSerializer,
           user: current_user
  end

  def upload_attachment
    @result.transaction do
      @asset = @result.assets.create!(
        created_by: current_user,
        last_modified_by: current_user,
        team: @my_module.team,
        view_mode: @result.assets_view_mode
      )
      @asset.file.attach(params[:signed_blob_id])
      @asset.post_process_file(@my_module.team)
    end

    render json: @asset,
           serializer: AssetSerializer,
           user: current_user
  end

  def update_view_state
    view_state = @result.current_view_state(current_user)
    view_state.state['result_assets']['sort'] = params.require(:assets).require(:order)
    view_state.save! if view_state.changed?

    render json: {}, status: :ok
  end

  def update_asset_view_mode
    ActiveRecord::Base.transaction do
      @result.assets_view_mode = params[:assets_view_mode]
      @result.save!(touch: false)
      @result.assets.update_all(view_mode: @result.assets_view_mode)
    end
    render json: { view_mode: @result.assets_view_mode }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error(e.message)
    render json: { errors: e.message }, status: :unprocessable_entity
  end

  def destroy
    if @result.destroy
      render json: {}, status: :ok
    else
      render json: { errors: @result.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def duplicate
    ActiveRecord::Base.transaction do
      new_result = @result.duplicate(
        @my_module, current_user, result_name: "#{@result.name} (1)"
      )

      render json: new_result, serializer: ResultSerializer, user: current_user
    end
  end

  private

  def result_params
    params.require(:result).permit(:name)
  end

  def apply_sort!
    case params[:sort]
    when 'updated_at_asc'
      @results = @results.order(updated_at: :asc)
    when 'updated_at_desc'
      @results = @results.order(updated_at: :desc)
    when 'created_at_asc'
      @results = @results.order(created_at: :asc)
    when 'created_at_desc'
      @results = @results.order(created_at: :desc)
    when 'name_asc'
      @results = @results.order(name: :asc)
    when 'name_desc'
      @results = @results.order(name: :desc)
    end
  end

  def apply_filters!
    if params[:query].present?
      @results = @results.search(current_user, params[:archived] == 'true', params[:query], params[:page] || 1)
    end

    @results = @results.where('created_at >= ?', params[:created_at_from]) if params[:created_at_from]
    @results = @results.where('created_at <= ?', params[:created_at_to]) if params[:created_at_to]
    @results = @results.where('updated_at >= ?', params[:updated_at_from]) if params[:updated_at_from]
    @results = @results.where('updated_at <= ?', params[:updated_at_to]) if params[:updated_at_to]
  end

  def load_my_module
    @my_module = MyModule.readable_by_user(current_user).find(params[:my_module_id])
  end

  def load_vars
    @result = @my_module.results.find(params[:id])

    return render_403 unless @result

    @my_module = @result.my_module
  end

  def check_destroy_permissions
    render_403 unless can_delete_result?(@result)
  end

  def set_navigator
    @navigator = {
      url: tree_navigator_my_module_path(@my_module),
      archived: params[:view_mode] == 'archived',
      id: @my_module.code
    }
  end
end
