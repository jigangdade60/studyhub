class ApplicationController < ActionController::Base
  include Authentication
  before_action :set_current_session

  private

  def set_current_session
    if session_record = Session.find_by(id: cookies.signed[:session_id])
      Current.session = session_record
    end
  end
end