# frozen_string_literal: true

# The hide and show action shared by the catalog resources of the admin: a form asking for the reason, then the change.
# The form posts the state it asks for rather than a toggle, so a stale page cannot flip the record back.
module CatalogVisibilityActions
  def change_visibility
    return render_visibility_form(!resource.hidden) if request.get?

    hidden = ActiveModel::Type::Boolean.new.cast(params.require(:hidden))
    result = switch_visibility(hidden)
    return refuse_visibility(hidden) if result == :reason_required

    redirect_to resource_path(resource), notice: t("admin.visibility.#{result}")
  end

  private

  def switch_visibility(hidden)
    Catalog::VisibilityChanger.call(record: resource, hidden:, reason: params[:reason], admin: current_admin_user)
  end

  def refuse_visibility(hidden)
    flash.now[:error] = t('admin.visibility.reason_required')
    render_visibility_form(hidden, status: :unprocessable_content)
  end

  def render_visibility_form(hidden, status: :ok)
    @page_title = t(hidden ? 'admin.visibility.hide_title' : 'admin.visibility.show_title')
    render 'admin/visibility/form', locals: { hidden: }, status:
  end
end
