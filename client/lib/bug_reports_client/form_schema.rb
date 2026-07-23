require "yaml"

module BugReportsClient
  # Loads and validates the YAML form definition that drives the report form.
  #
  # Resolution order for the schema file:
  #   1. config.form_schema_path (explicit override)
  #   2. <host app>/config/bug_report_form.yml
  #   3. the engine's config/form_schema.yml default
  #
  # Schema shape - top-level keys are report types (bug/feature), each holding
  # an ordered list of fields:
  #
  #   bug:
  #     - field: steps_to_reproduce
  #       type: textarea          # text | textarea | select | checkbox
  #       required: true
  #       section: reproduction   # optional - starts a new card in the form
  #       rows: 4                 # textareas only
  #       options: [Chrome, Safari]  # selects only
  #       label: "How can we see this?"   # optional - falls back to i18n
  #       placeholder: "..."              # optional - falls back to i18n
  #       help: "..."                     # optional - falls back to i18n
  #
  # Answers are stored in BugReport#responses keyed by the field name. A
  # feature field named `priority` doubles as the report's importance rating
  # shown in list views (mirroring severity for bugs).
  class FormSchema
    REPORT_TYPES = %w[bug feature].freeze
    FIELD_TYPES = %w[text textarea select checkbox].freeze

    # A single form field parsed from the YAML definition.
    Field = Struct.new(:key, :type, :required, :options, :section, :label, :placeholder, :help, :rows, keyword_init: true) do
      def required? = !!required
      def select? = type == "select"
      def checkbox? = type == "checkbox"

      # Wording resolution: inline schema values win, then i18n under
      # bug_reports_client.fields.<key>.*, then a humanised fallback.
      def label_text
        label || I18n.t("bug_reports_client.fields.#{key}.label", default: key.humanize)
      end

      def placeholder_text
        placeholder || I18n.t("bug_reports_client.fields.#{key}.placeholder", default: nil)
      end

      def help_text
        help || I18n.t("bug_reports_client.fields.#{key}.help", default: nil)
      end

      def prompt_text
        I18n.t("bug_reports_client.fields.#{key}.prompt",
               default: I18n.t("bug_reports_client.form.select_prompt"))
      end
    end

    class << self
      # The active schema. Reloaded on every call in development so schema
      # edits show up without a restart; memoised elsewhere.
      def current
        if Rails.env.development?
          load_schema
        else
          @current ||= load_schema
        end
      end

      def reset!
        @current = nil
      end

      def default_path
        Engine.root.join("config", "form_schema.yml")
      end

      private

      def load_schema
        new(resolve_path)
      end

      def resolve_path
        explicit = BugReportsClient.config.form_schema_path
        return Pathname.new(explicit) if explicit.present?

        host_default = Rails.root.join("config", "bug_report_form.yml")
        host_default.exist? ? host_default : default_path
      end
    end

    attr_reader :path

    def initialize(path)
      @path = path
      @fields_by_type = parse(path)
    end

    # Report types the schema defines, in file order. The form only shows the
    # bug/feature toggle when more than one type is present.
    def report_types
      @fields_by_type.keys
    end

    def fields_for(report_type)
      @fields_by_type.fetch(report_type.to_s, [])
    end

    def required_fields(report_type)
      fields_for(report_type).select(&:required?)
    end

    # Every field key across all report types - used for strong parameters so
    # only schema-declared answers are ever written to responses.
    def field_keys
      @fields_by_type.values.flatten.map(&:key).uniq
    end

    # Field keys for one report type, falling back to all keys when the type
    # is unknown/blank. Used to scope strong parameters to the selected type
    # so a bug submission can't smuggle in feature answers (and vice versa).
    def field_keys_for(report_type)
      fields = fields_for(report_type)
      fields.any? ? fields.map(&:key).uniq : field_keys
    end

    # Fields grouped into ordered sections for rendering. Fields before any
    # `section` marker fall into a nil section rendered without a heading.
    def sections_for(report_type)
      fields_for(report_type).chunk_while { |a, b| a.section == b.section }.map do |group|
        [ group.first.section, group ]
      end
    end

    private

    def parse(path)
      raise SchemaError, "Bug report form schema not found at #{path}" unless File.exist?(path)

      raw = YAML.safe_load_file(path)
      raise SchemaError, "#{path}: schema must be a hash of report types (bug/feature)" unless raw.is_a?(Hash)

      raw.each_with_object({}) do |(report_type, fields), parsed|
        unless REPORT_TYPES.include?(report_type.to_s)
          raise SchemaError, "#{path}: unknown report type #{report_type.inspect} (expected one of #{REPORT_TYPES.join(', ')})"
        end
        raise SchemaError, "#{path}: #{report_type} must contain a list of fields" unless fields.is_a?(Array)

        parsed[report_type.to_s] = fields.map { |definition| build_field(report_type, definition) }
      end.tap do |parsed|
        raise SchemaError, "#{path}: schema defines no report types" if parsed.empty?
      end
    end

    def build_field(report_type, definition)
      raise SchemaError, "#{path}: each #{report_type} field must be a hash with a `field` key" unless definition.is_a?(Hash)

      key = definition["field"].to_s
      raise SchemaError, "#{path}: #{report_type} entry missing `field` name: #{definition.inspect}" if key.blank?
      unless key.match?(/\A[a-z][a-z0-9_]*\z/)
        raise SchemaError, "#{path}: field name #{key.inspect} must be snake_case (letters, digits, underscores)"
      end

      type = (definition["type"] || "text").to_s
      unless FIELD_TYPES.include?(type)
        raise SchemaError, "#{path}: field #{key} has unknown type #{type.inspect} (expected one of #{FIELD_TYPES.join(', ')})"
      end
      if type == "select" && !definition["options"].is_a?(Array)
        raise SchemaError, "#{path}: select field #{key} needs an `options` list"
      end

      Field.new(
        key: key,
        type: type,
        required: definition["required"] || false,
        options: normalise_options(key, definition["options"]),
        section: definition["section"],
        label: definition["label"],
        placeholder: definition["placeholder"],
        help: definition["help"],
        rows: definition["rows"] || 3
      )
    end

    # Select options may be plain strings (label doubles as the stored value)
    # or {value:, label:} hashes when the stored value should differ from the
    # display text. Normalised to [label, value] pairs for options_for_select.
    def normalise_options(key, options)
      return nil if options.nil?

      options.map do |option|
        case option
        when String then [ option, option ]
        when Hash
          value = option["value"].to_s
          raise SchemaError, "#{path}: option for #{key} missing `value`: #{option.inspect}" if value.blank?
          [ option["label"] || value.humanize, value ]
        else
          raise SchemaError, "#{path}: option for #{key} must be a string or {value:, label:} hash"
        end
      end
    end
  end
end
