class SettingsController < ApplicationController
  def show
    @user = current_user
  end

  def update
    if current_user.update(profile_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      @user = current_user
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  # Model-provider switching + API keys.
  def update_ai
    attrs = ai_params
    # Blank key fields mean "keep the stored key".
    %i[anthropic_api_key openai_api_key deepseek_api_key].each do |key|
      attrs.delete(key) if attrs[key].blank?
    end
    attrs[:ai_model] = Ai::Providers.default_model_for(attrs[:ai_provider]) if attrs[:ai_model].blank?
    if current_user.update(attrs)
      redirect_to settings_path, notice: "AI provider settings saved."
    else
      redirect_to settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  def profile_params
    params.require(:user).permit(:full_name, settings: [:theme, :results_per_page, :default_scope])
  end

  def ai_params
    params.require(:user).permit(:ai_provider, :ai_model, :anthropic_api_key, :openai_api_key, :deepseek_api_key)
  end
end
