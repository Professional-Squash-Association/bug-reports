require "test_helper"
require "tempfile"

module BugReportsClient
  class FormSchemaTest < ActiveSupport::TestCase
    test "loads the engine default schema when no host schema exists" do
      schema = FormSchema.current

      assert_equal %w[bug feature], schema.report_types
      assert_includes schema.field_keys, "impact"
      assert_includes schema.field_keys, "priority"
    end

    test "required_fields returns only required fields for the type" do
      schema = FormSchema.current

      assert_equal %w[impact expected_behaviour actual_behaviour], schema.required_fields("bug").map(&:key)
      assert_includes schema.required_fields("feature").map(&:key), "problem"
    end

    test "sections_for groups consecutive fields by section in order" do
      sections = FormSchema.current.sections_for("bug")

      assert_equal "about_the_bug", sections.first.first
      assert_equal %w[impact], sections.first.last.map(&:key)
      reproduction = sections.find { |name, _| name == "reproduction" }
      assert_equal %w[steps_to_reproduce specific_examples page_url browser], reproduction.last.map(&:key)
    end

    test "select options normalise strings and value/label hashes" do
      schema = FormSchema.current
      browser = schema.fields_for("bug").find { |field| field.key == "browser" }
      priority = schema.fields_for("feature").find { |field| field.key == "priority" }

      assert_equal [ "Chrome", "Chrome" ], browser.options.first
      assert_equal "high", priority.options.first.last
      assert_match(/^High/, priority.options.first.first)
    end

    test "a host schema path takes precedence" do
      with_schema(<<~YAML) do |schema|
        bug:
          - field: what_happened
            type: textarea
            required: true
      YAML
        assert_equal %w[bug], schema.report_types
        assert_equal %w[what_happened], schema.field_keys
      end
    end

    test "rejects unknown report types" do
      assert_schema_error(/unknown report type/) do
        load_schema(<<~YAML)
          incident:
            - field: summary
        YAML
      end
    end

    test "rejects unknown field types" do
      assert_schema_error(/unknown type/) do
        load_schema(<<~YAML)
          bug:
            - field: summary
              type: dropdown
        YAML
      end
    end

    test "rejects selects without options" do
      assert_schema_error(/needs an `options` list/) do
        load_schema(<<~YAML)
          bug:
            - field: browser
              type: select
        YAML
      end
    end

    test "rejects entries without a field name" do
      assert_schema_error(/missing `field` name/) do
        load_schema(<<~YAML)
          bug:
            - type: text
        YAML
      end
    end

    test "rejects non-snake-case field names" do
      assert_schema_error(/snake_case/) do
        load_schema(<<~YAML)
          bug:
            - field: "What Happened"
        YAML
      end
    end

    test "rejects a missing schema file" do
      assert_schema_error(/not found/) do
        FormSchema.new(Pathname.new("/nonexistent/schema.yml"))
      end
    end

    test "field wording falls back to i18n then humanised key" do
      with_schema(<<~YAML) do |schema|
        bug:
          - field: impact
          - field: custom_thing
      YAML
        impact, custom = schema.fields_for("bug")
        assert_equal I18n.t("bug_reports_client.fields.impact.label"), impact.label_text
        assert_equal "Custom thing", custom.label_text
      end
    end

    test "inline schema wording wins over i18n" do
      with_schema(<<~YAML) do |schema|
        bug:
          - field: impact
            label: "Custom label"
      YAML
        assert_equal "Custom label", schema.fields_for("bug").first.label_text
      end
    end

    private

    def load_schema(yaml)
      Tempfile.create([ "schema", ".yml" ]) do |file|
        file.write(yaml)
        file.flush
        return FormSchema.new(Pathname.new(file.path))
      end
    end

    def with_schema(yaml)
      Tempfile.create([ "schema", ".yml" ]) do |file|
        file.write(yaml)
        file.flush
        yield FormSchema.new(Pathname.new(file.path))
      end
    end

    def assert_schema_error(matcher, &block)
      error = assert_raises(SchemaError, &block)
      assert_match matcher, error.message
    end
  end
end
