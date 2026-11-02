# frozen_string_literal: true

Given (/^I wait for (\d+) seconds?$/) do |n|
  sleep(n.to_i)
end

And (/^Show me text for "(.*)"$/) do |filter|
  all = page.all(filter)
  for i in all
    puts i.text
  end
  if all.length == 0
    puts "No elements found for #{filter}"
  end
end

And (/^Show me full page text$/) do
  puts page.text
end

And (/^Show me full page html$/) do
  puts page.html
end

# views/pages/_form.html.erb has a TinyMCE script that
# will cause broswer to hang due to loading assets
And (/^I wait for TinyMCE to load$/) do
  sleep 1
end
