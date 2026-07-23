module BugReportsClient
  # Included into engine views (via the engine's ApplicationController) so
  # host layouts render unmodified inside engine pages. Isolated engines
  # resolve route helpers against their own routes, which breaks host-only
  # helpers (root_path, profile_path, etc) used in host layouts and navbars.
  # This delegates any unknown *_path / *_url helper to the host app, while
  # the engine's own helpers keep resolving first because they are real
  # methods and never reach method_missing.
  module MainAppRoutes
    def method_missing(method, *args, &block)
      if main_app_route_helper?(method)
        main_app.public_send(method, *args)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      main_app_route_helper?(method) || super
    end

    # Active Storage URLs (blobs, attachments, variants - e.g. a user avatar
    # in a host navbar, or image_tag on an attachment) resolve through
    # polymorphic mappings that only exist on the HOST's route set, so route
    # them there explicitly. image_tag goes through polymorphic_url, other
    # callers through url_for - cover all three. Everything else keeps the
    # normal lookup.
    def url_for(argument = nil)
      if MainAppRoutes.active_storage_argument?(argument)
        main_app.polymorphic_path(argument)
      else
        super
      end
    end

    def polymorphic_url(record, options = {})
      if MainAppRoutes.active_storage_argument?(record)
        main_app.polymorphic_url(record, options)
      else
        super
      end
    end

    def polymorphic_path(record, options = {})
      if MainAppRoutes.active_storage_argument?(record)
        main_app.polymorphic_path(record, options)
      else
        super
      end
    end

    def self.active_storage_argument?(argument)
      return false unless defined?(ActiveStorage)

      argument.is_a?(ActiveStorage::Blob) ||
        argument.is_a?(ActiveStorage::Attachment) ||
        argument.is_a?(ActiveStorage::Variant) ||
        argument.is_a?(ActiveStorage::VariantWithRecord) ||
        argument.is_a?(ActiveStorage::Preview)
    end

    private

    def main_app_route_helper?(method)
      method.to_s.end_with?("_path", "_url") && main_app.respond_to?(method)
    end
  end
end
