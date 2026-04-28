# frozen_string_literal: true

Then("sortable table headers should have sort indicators") do
  headers = page.all("th.sorting, th.sorting_asc, th.sorting_desc")
  expect(headers.length).to be > 0, "Expected DataTables sorting classes on <th> elements"
  headers.each do |th|
    pseudo_content = page.evaluate_script(
      "window.getComputedStyle(document.querySelector('th.#{th[:class].split.first}'), '::after').getPropertyValue('content')"
    )
    expect(pseudo_content).not_to eq("none"),
      "Expected ::after pseudo-element on th.#{th[:class]} but got content: #{pseudo_content}"
  end
end

Then("sortable table headers should have a pointer cursor") do
  header = page.first("th.sorting, th.sorting_asc, th.sorting_desc")
  expect(header).not_to be_nil, "No sortable headers found"
  cursor = page.evaluate_script(
    "window.getComputedStyle(document.querySelector('th.sorting, th.sorting_asc, th.sorting_desc')).cursor"
  )
  expect(cursor).to eq("pointer"), "Expected cursor: pointer on sortable headers but got: #{cursor}"
end
