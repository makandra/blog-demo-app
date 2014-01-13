Then /^I should see an error flash$/ do
  page.should have_css('.flash.error, .flash .error, .flash.failure, .flash .failure')
end

Then /^I should see a confirmation flash$/ do
  page.should have_css('.flash.notice, .flash .notice, .flash.success, .flash .success')
end

Then /^the page should be titled "(.*?)"$/ do |title|
  page.should have_css('.page_title', :text => title)
end

Then /^I should get an access denied error$/ do
  access_denied = page.has_content?("Zugriff verweigert") || page.has_content?('Member object not found') || page.status_code == 404
  access_denied.should be_true
end

After('@javascript') do
  step 'I wait for the page to load'
end

Then /^I should( not)? see a query remover for "(.*?)"$/ do |negate, query|
  expectation = negate ? :should_not : :should
  matcher = have_css('.query_remover', :text => query)
  page.send(expectation, matcher)
end

When /^I remove the query$/ do
  page.find('.query_remover').click
end

Then /^I should( not)? see a segment "([^\"]*)"$/ do |negate, title|
  expectation = negate ? :should_not : :should
  page.send expectation, have_css('.segment_title', :text => title)
end

When /^I click into the "([^\"]*)" field$/ do |label|
  field = find_field(label)
  field.click
end

When /^I select "([^\"]*)" from the "([^\"]*)" datepicker$/ do |value, label|
  Capybara.javascript_test? or raise "driver not supported"
  field = find_field(label)
  # field.click
  page.execute_script("$('[name=\"#{field[:name]}\"]').trigger('focus')")
  patiently(5) do
    find('.ui-datepicker a', :text => value).click
  end
end

Then /^I should( not)? see an? "([^\"]*)" action$/ do |negate, label|
  label = label.mb_chars.upcase if Capybara.javascript_test?
  expectation = negate ? :should_not : :should
  page.send(expectation, have_css('.main_actions, .item_actions, .segment_actions', :text => label))
end

Then /^I should get a file download$/ do
  step 'I should get a download with the filename "filename.ext"'
end

Then /^an Excel spreadsheet should download$/ do
  step 'I should get a response with content-type "application/excel"'
end

When /^I press the "([^\"]*)" key$/ do |key|
  Capybara.javascript_test? or raise "driver not supported"
  retries = 0
  begin
    page.driver.browser.keyboard.send_keys(key)
  rescue Selenium::WebDriver::Error::UnknownError => e
    retries += 1
    retry if retries < 5
    raise e
  end
end

When /^I (?:open|close) the "([^\"]*)" segment$/ do |segment_title|
  # for some reason this does not work
  #page.find('.segment_title .label', :text => segment_title).click
  page.execute_script("$('.segment_title .label:contains(#{segment_title})').click()")
end

Then /^the "([^\"]*)" field should( not)? equal "([^\"]*)"$/ do |field, negate, value|
  expectation = negate ? :should_not : :should
  patiently do
    field = find_field(field)
    field_value = (field.tag_name == 'textarea') ? field.text : field.value
    if value.blank? # Capybara returns nil for empty fields, so we can't test for equality
      field_value.send(expectation, be_blank)
    else
      field_value.send(expectation) == value
    end
  end
end

Then /^the "([^\"]*)" field should be empty$/ do |field|
  patiently do
    field = find_field(field)
    field_value = ((field.tag_name == 'textarea') && field.text.present?) ? field.text : field.value
    field_value.should be_blank
  end
end

# Checks that an email includes some text
Then /^I should( not)? see "([^\"]*)" in that e?mail$/ do |negate, text|
  expectation = negate ? :should_not : :should
  MailFinder.email_text_body(@mail).send(expectation, include(text))
end

When /^I follow the "([^\"]*)" icon link$/ do |icon_name|
  page.find(:xpath, "//a[span[@data-icon-name='#{icon_name}']]").click
end

When /^I go back in the browser history$/ do
  page.evaluate_script('window.history.back()')
end

Then /^I should( not)? see an alert$/ do |negate|
  expectation = negate ? :to : :not_to
  expect {
    page.driver.browser.switch_to.alert
  }.send(expectation, raise_exception)
end

When "I refresh the selenium browser" do
  page.driver.browser.navigate.refresh
end

After do
  if Capybara::current_driver == :selenium
    begin
      steps %{
      When I go to the homepage
        And I confirm the browser dialog
      }
    rescue
    end
  end
end
