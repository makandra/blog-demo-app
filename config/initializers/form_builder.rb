# -*- coding: utf-8 -*-
require 'ostruct'
include ActionView::Helpers::JavaScriptHelper
include ActionView::Helpers::TagHelper

ActionView::Helpers::FormBuilder.class_eval do

  class CheckBoxList

    def initialize(form, field, choices, options = {})
      @object = form.object
      @object_name = form.object_name
      @field = field
      @choices = parse_choices(choices)
      @assigned_values = parse_assigned_values
      @options = options
    end

    def render(template)
      html = "".html_safe
      if @choices.present?
        @choices.each do |choice|
          item_html = ''.html_safe
          item_html << template.check_box_tag(field_name, choice.value, assigned?(choice), :id => check_box_id(choice))
          item_html << ' '
          item_html << template.label_tag(check_box_id(choice), label_text(choice))
          html << template.content_tag(:li, item_html)
        end
      else
        html << template.content_tag(:li, 'Keine Auswahlmöglichkeiten', :class => 'no_choices')
      end
      html << template.hidden_field_tag(field_name, '') unless @options[:allow_empty] # cannot serialize an empty list
      template.content_tag(:ul, html, :class => "check_boxes #{@options[:class]}", :id => @options[:id])
    end

    class Choice
      attr_reader :value, :humanized
      def initialize(value, humanized)
        @value = value
        @humanized = humanized
      end
    end

    private

    def check_box_id(choice)
      "#{field_name}_#{choice.value}".gsub(/[^a-z0-9]/i, '_')
    end

    def label_text(choice)
      label_text = choice.humanized
      label_text = content_tag(:del, label_text) if soft_deleted?(choice)
      label_text
    end

    def field_name
      "#{@object_name}[#{@field}][]"
    end

    def parse_assigned_values
      @assigned_values = (@object.send(@field) || []).collect(&:to_s)
    end

    def parse_choices(choices)
      if choices.is_a?(Hash)
        choices.collect do |value, label|
          Choice.new(value, label)
        end
      else
        choices.collect do |choice|
          if choice.is_a?(String) || choice.is_a?(Fixnum)
            value = choice.to_s
            label = value
          else
            value = extract_property(choice, [:value, :id]).to_s
            label = extract_property(choice, [:humanized, :label, :title, :name, :to_s])
          end
          Choice.new(value, label)
        end
      end
    end

    def assigned?(choice)
      @assigned_values.include?(choice.value)
    end

    def soft_deleted?(choice)
      choice.respond_to?(:trashed?) && choice.trashed? ||
      choice.respond_to?(:deleted?) && choice.deleted?
    end

    def extract_property(choice, methods)
      property = nil
      methods.each do |method|
        if choice.respond_to?(method)
          property = choice.send(method)
          break
        end
      end
      property or raise "Could not extract choice property from #{choice.inspect}"
    end

  end

  def check_boxes(field, choices, options = {})
    CheckBoxList.new(self, field, choices, options).render(@template)
  end

  def partial(name, locals = {})
    @template.render name, locals.merge(:form => self)
  end

  def combined_label(*attrs)
    options = attrs.extract_options!
    text = attrs.collect { |attr| object.class.human_attribute_name(attr) }.join(' / ')
    has_errors = attrs.any? { |attr| object.errors[attr].present? }
    for_field = extract_element_attribute(label(attrs.first), 'for')
    label = @template.label_tag(for_field, text, options)
    if has_errors
      label = ActionView::Base.field_error_proc.call(label)
    end
    label
  end

  def radio_button_with_label(field, value, _label, options = {}, &block)
    html = ''.html_safe
    html << "<div class='radio_button_with_label'>".html_safe
    html << radio_button(field, value, options)
    html << label(field, " #{_label}", :for => "#{object_name}_#{field}_#{value}".gsub(/[^a-z0-9]/i, '_')).gsub('__', '_')
    if block_given?
      html << @template.content_tag(:span) do
        yield
      end
    end
    html << "</div>".html_safe
    html
  end

  def errors_on_base
    html = ''.html_safe
    for error in Array.wrap(object.errors[:base])
      html << @template.content_tag(:p, error, :class => 'error')
    end
    html
  end

  def error_message_on(*attrs)
    message = attrs.collect { |attr| Error.message(object, attr) }.compact.first
    @template.content_tag(:div, message, :class => 'error_message') if message.present?
  end

  def spec_label(field, text = nil, options = {})
    label_html = label(field)
    id = extract_element_attribute(label_html, 'for')
    text ||= extract_element_text(label_html)
    @template.spec_label_tag(id, text, options)
  end

  def qualified_label(field, options)
    html = ''.html_safe
    spec_label_prefix = options[:spec_label_prefix] # or raise "Missing option :spec_label_prefix"
    html << label(field)
    html << spec_label(field, "#{spec_label_prefix}: #{object.class.human_attribute_name field}") if spec_label_prefix
    html
  end

  def image_picker(field, options = {})
    # for carrierwave attachments https://github.com/jnicklas/carrierwave
    html = ''
    if object.send("#{field}?")
      destroy_field = options[:destroy_field] || "remove_#{field}"
      html = [
          @template.image_tag(object.send(field).url),
          check_box(destroy_field),
          label(destroy_field, "#{object.class.human_attribute_name(field)} löschen")
        ].join(" ")
    else
      html = file_field(field)
    end
    @template.content_tag(:span, html.html_safe, :class => 'image_picker')
  end

  def file_picker(field, options = {})
    file = object.send(field)
    if file.exists?
      destroy_field = options[:destroy_field] || "destroy_#{field}"
      html = [@template.content_tag(:span, file.original_filename, :class => 'filename'), check_box(destroy_field), label(destroy_field, "Datei löschen")].join(" ")
    else
      html = file_field field
    end
    @template.content_tag :span, html.html_safe, :class => 'file_picker'
  end

  def coordinates_picker
    @template.content_tag :span, :class => 'coordinates_picker' do
      spec_label(:latitude) + number_field(:latitude) + ' / ' + spec_label(:longitude) + number_field(:longitude)
    end
  end

  def destroy_marker(label = 'löschen')
    html = ''.html_safe
    unless object.new_record?
      html << check_box(:_destroy)
      html << " "
      html << label(:_destroy, label)
      html << spec_label(:_destroy, label)
    end
    html
  end

  def person_picker(field, choices, options = {})
    choices = choices.all if Util.scopish?(choices)
    collection_select(field, choices, :id, :full_name, { :include_blank => true }, :class => 'person_picker')
  end

  # A text field that the date in localized format, but doesn't open a date picker UI when clicked.
  def date_field(field, options = {})
    append_class_option(options, "date_field")
    value = object.send(field)
    if value.is_a?(Date)
      value = I18n.l(value, :format => :default)
    end
    options[:value] = value
    text_field(field, options)
  end

  # A text field that the date in localized format, and opens a date picker UI when clicked.
  def date_picker(field, options = {})
    append_class_option(options, "date_picker")
    date_field(field, options)
  end

  def date_range_picker(left_field, right_field, options = {})
    # append_class_option(options, "date_range_picker_")
    html = ''.html_safe
    html << spec_label(left_field)
    html << date_picker(left_field, options.merge('data-date-range-picker-role' => 'left'))
    html << String.nbsp
    html << 'bis'
    html << String.nbsp
    html << spec_label(right_field)
    html << date_picker(right_field, options.merge('data-date-range-picker-role' => 'right'))
    @template.content_tag(:span, html, :class => 'date_range_picker')
  end

  def datetime_picker(field, options = {})
    append_class_option(options, "datetime_picker")
    value = object.send(field)
    if value.is_a?(Time)
      options[:value] = I18n.l(value, :format => :default)
    end
    text_field(field, options)
  end

  def phone_field(field, options = {})
    value = object.send(field)
    if value.present?
      options[:value] = value
    end
    text_field(field, options.merge(:type => 'phone'))
  end

  #def email_field(field, options = {})
  #  email_field(field)
  #end

  def money_field(field, options = {})
    append_class_option(options, "money_field")
    number_field(field, options.reverse_merge(:unit => "€", :money => true))
  end

  def number_field(field, options = {})
    append_class_option(options, "number_field")
    observe_with = options.delete(:observe_with)
    unit = options.delete(:unit)
    value = object.send(field)
    unless value.blank? || value.is_a?(String)
       value = value.to_s.sub(/\.0+\z/,"").sub('.',',')
    end
    options[:value] = value
    text_field_html = text_field(field, options) + (unit.present? ? " #{unit}" : "")
    text_field_id = extract_element_id(text_field_html)
    html = ''
    html << text_field_html
    html << @template.observe_field(text_field_id, :frequency => 0.2, :function => observe_with) if observe_with
    html.html_safe
  end

  def wysiwyg_editor(field, options = {})
    @template.ensure_ckeditor_included
    options[:class] = "#{options[:class]} wysiwyg_editor ckeditor"
    options[:rows] ||= 30
    text_area(field, options)
  end

  def combo_box(field, choices, options = {})
    if Rails.env == 'test' || Rails.env == 'cucumber'
      text_field(field, options)
    else
      current_choice = object.send(field)
      choices << current_choice unless current_choice.blank? || choices.include?(current_choice)
      more_choice = "Neuer Wert..."
      choices << more_choice
      if choices.length > 1
        collection_select field, choices, :to_s, :to_s, { :include_blank => true }, options.merge(:class => "combo_box", 'data-combo_box_new_choice' => more_choice)
      else
        text_field field, options
      end
    end
  end

  FakeTagCount = Struct.new(:name, :count)

  def tag_picker(field, options = {})
    tag_classes = (1..10).collect { |i| "weight#{i}" }
    tag_names = object.send(field).natural_sort
    value = tag_names.join(", ")
    text_field_html = text_field(field, :autocomplete => 'off', :value => value, :class => 'tag_input')
    #text_field_id = extract_element_id(text_field_html)
    scope = options[:scope] || object.class #.scoped(:conditions => ["updated_at > ?", Time.now - 18.months])
    tag_context = options[:context] || field.to_s.gsub(/_list$/, '').pluralize.to_sym

    tag_counts = scope.send("top_#{tag_context}", 20)
    max_tag_count = tag_counts.first.andand.count || 1

    # Ensure the selected tags are part of the cloud
    tag_names_not_in_cloud = tag_names - tag_counts.collect(&:name)  # tag equality is on name
    tag_names_not_in_cloud.each do |tag_name|
      tag_counts << FakeTagCount.new(tag_name, max_tag_count)
    end

    tag_counts = tag_counts.natural_sort_by(&:name)

    cloud = ''.html_safe
    @template.tag_cloud(tag_counts, tag_classes) do |tag, klass|
      cloud << @template.link_to(tag.name, '#', :class => "tag #{klass}")
      cloud << " "
    end

    cloud_expander = @template.link_to(@template.icon(:expand, 'Tag-Cloud anzeigen'), '#', :class => 'tag_cloud_action tag_cloud_expander')
    cloud_collapser = @template.link_to(@template.icon(:collapse, 'Tag-Cloud verbergen'), '#', :class => 'tag_cloud_action tag_cloud_collapser hidden')

    @template.content_tag(:div, :class => 'tag_picker', 'data-human_attribute_name' => object.class.human_attribute_name(field)) do
      text_field_html +
      cloud_expander +
      cloud_collapser +
      @template.content_tag(:div, cloud, :class => 'tag_cloud hidden')
    end

  end

  #def label_with_required_field(*args)
  #  options = args.extract_options!
  #  required = options.delete(:required)
  #  args << options if options.present?
  #  html = label_without_required_field(*args)
  #  if required
  #    required_field_options = required.is_a?(Hash) ? required : {}
  #    unsafe_html = '' + html
  #    unsafe_html.sub!(/(>)(.*?)(<\/label>)/) do |match|
  #      $1 + $2 + @template.nbsp + @template.required_field(required_field_options) + $3
  #    end
  #    html = unsafe_html.html_safe
  #  end
  #  html
  #end
  #
  #
  #alias_method_chain :label, :required_field

  def ensure_singleton_built(association, defaults = {})
    if object.send(association).nil?
      defaults = defaults.merge(:new_nested_record => true)
      object.send("build_#{association}", defaults)
    end
  end

  def fields_for_built_singleton(association, defaults = {}, &block)
    ensure_singleton_built(association, defaults)
    fields_for(association, &block)
  end

  def build_nested_records(association, minimum = nil, buffer = nil, attributes = {})
    minimum ||= 3
    buffer ||= 2
    attributes = attributes.merge(:new_nested_record => true)
    collection = object.send(association)
    [minimum - collection.size, buffer].max.times do |i|
      collection.build(attributes)
    end
  end

  def fields_for_with_blank_rows(association, options, &content)
    number_of_new_records_to_reveal = options.fetch(:reveal, 1)
    number_of_records_before_building = object.send(association).size
    build_nested_records(association, options[:minimum], options[:buffer])

    fields_for_with_index(association) do |record, iteration|
      klasses = []
      if iteration >= number_of_records_before_building
        klasses << 'new_nested_record'
      end
      if iteration >= number_of_records_before_building + number_of_new_records_to_reveal
        klasses << 'hidden'
      end
      css_klass = klasses.join(" ")
      if content.arity == 2
        @template.capture(record, css_klass, &content)
      else
        @template.content_tag(:div, :class => css_klass) do
          @template.capture(record, &content)
        end
      end
    end
  end

  def fields_for_with_index(*args, &block)
    index = 0
    fields_for(*args) do |form|
      instance_exec(form, index, &block).tap { index += 1 }
    end
  end

  def highlight_on_error(error, *field_args)
    html = send(*field_args)
    html = @template.content_tag(:span, html, :class => 'field_with_errors') if error
    html
  end

  def company_office_picker(field, options = {})
    offices = []
    if object.office
      selected_office_id = object.office.id
    end
    if object.company
      offices = object.company.offices
    end
    if Rails.env.test? && Capybara.current_driver != :selenium
      offices = Office.all
    end
    html = ''.html_safe
    html << spec_label(:company_id)
    company_picker = company_picker(:company_id)
    if object.errors[:office_id].present?
      company_select = @template.content_tag(:span, company_select, :class => "field_with_errors")
    end
    html << company_picker
    html << spec_label(:office_id)
    html << select(field, @template.options_from_collection_for_select(offices, :id, :role, selected_office_id), {:selected => selected_office_id}, :class => 'company_sub_picker')
    html << javascript_tag("$(function(){CompanySubPicker.init('.company_id', '.company_sub_picker', '/offices');});")
    html
  end

  def company_person_picker(field, options = {})
    people = []
    if object.person
      selected_person_id = object.person.id
    end
    if object.company
      people = object.company.people
      people = people | [object.person] if object.person # when person changed her company she's still displayed
    end
    if Rails.env.test? && Capybara.current_driver != :selenium
      people = Person.all
    end
    html = ''.html_safe
    html << spec_label(:company_id)
    company_picker = company_picker(:company_id, :scope => 'active')
    if object.errors[:person_id].present?
      company_select = @template.content_tag(:span, company_select, :class => "field_with_errors")
    end
    html << company_picker
    html << spec_label(:person_id)
    html << select(field, @template.options_from_collection_for_select(people, :id, :name, selected_person_id), {:include_blank => "<Ansprechpartner wählen>", :selected => selected_person_id}, :class => 'company_sub_picker')
    html << javascript_tag("$(function(){CompanySubPicker.init('.company_id', '.company_sub_picker', '/people');});")
    html
  end

  def company_picker(field, options = {})
    @template.content_tag :div, :class => 'company_picker'do
      html = ''.html_safe
      companies = Company
      scope = options[:scope]
      companies = companies.send(scope) if scope
      if Rails.env.test? && !Capybara.javascript_test?
        html << Capybara.current_driver.to_s
        html << collection_select(field, companies.all.sort, :id, :name, :include_blank => '<Firma wählen>')
      else
        html << text_field(field, options.merge(:class => 'company_id'))
      end
      name_field = @template.text_field_tag('company_name', object.company.andand.name, :autocomplete => 'off', :class => 'company_name', :placeholder => "Firma suchen...")
      name_field = ActionView::Base.field_error_proc.call(name_field) if object.errors[:company_id].present?
      html << name_field
      html << @template.spinner('spinner_black.gif')
      html << @template.content_tag(:div, nil, :class => 'suggestions hidden')
      html
    end
  end

  def user_picker(field, options = {})
    html_options = options[:html] || {}
    choices = object.send("assignable_#{field.to_s.gsub('_id', '').pluralize}")
    current_user_in_choices = choices.include?(@template.current_user)

    @template.content_tag :div, :class => 'user_picker' do
      html = ''.html_safe

      user_select = collection_select field, choices, :id, :name, options, html_options
      user_select = ActionView::Base.field_error_proc.call(user_select) if object.errors[:field].present?
      html << user_select
      if current_user_in_choices and not html_options[:disabled]
        current_user = @template.current_user
        html << ' '
        html << @template.link_to('Ich', '#', :class => 'select_me hyperlink',
                                  :'data-current_user_id' => current_user.id,
                                  :title => "#{current_user.to_s} auswählen")
      end
      html
    end
  end

  private

  def extract_element_id(html)
    extract_element_attribute(html, 'id')
  end

  def extract_element_attribute(html, attr)
    /#{attr}=[\"\'](.*?)[\"\']/.match(html)[1]
  end

  def extract_element_text(html)
    # /^<(\w+).*?>(.*?)<\/\1.*?>$/.match(html)[2]
    @template.strip_tags(html).strip
  end

  def append_class_option(*args)
    @template.append_class_option(*args)
  end

end

ActiveRecord::Base.class_eval do
  attr_writer :new_nested_record
  def new_nested_record?
    !!@new_nested_record
  end
end

ActionView::Helpers::FormTagHelper.class_eval do

  def highlight_on_error(error, *field_args)
    html = send(*field_args)
    html = content_tag(:span, html, :class => 'field_with_errors') if error
    html
  end

  def spec_label_tag(id, text = nil, options = {})
    @@spec_label_counts ||= Hash.new(0)
    count_key = "#{object_id}/#{text}"
    count = @@spec_label_counts[count_key]
    append_class_option(options, 'spec_label')
    unless Rails.env.test? && Capybara.current_driver == :selenium
      append_class_option(options, "hidden")
    end
    html = label_tag(id, count == 0 ? text : "#{text} (#{count + 1})", options)
    @@spec_label_counts[count_key] += 1
    html
  end

  def append_class_option(options, klass)
    if options[:class].present?
      options[:class] << ' '
    else
      options[:class] ||= ''
    end
    options[:class] << " #{klass}"
    options[:class]
  end

end

