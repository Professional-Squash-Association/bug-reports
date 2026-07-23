# Renders a host page whose layout includes bug_report_alerts, proving the
# engine helper is exposed to host views.
class HomeController < ApplicationController
  def index
  end

  # Raises a genuine 500 (error capture should report it).
  def boom
    raise ArgumentError, "boom from dummy"
  end

  # Raises a 404-mapped error (error capture should ignore it).
  def missing
    raise ActiveRecord::RecordNotFound, "nope"
  end
end
