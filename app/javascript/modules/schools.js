import $ from "jquery"
import "bootstrap"
import "turbolinks"
import Selectize from "selectize"

window.Selectize = Selectize

const SCHOOL_REQUIRED_ATTRIBUTES = ['name', 'city', 'state', 'website', 'grade_level', 'type']
let selectizeCallback = null
let initialized = false

const toggleRequired = (fields, state) => {
  fields.forEach((attr) => {
    $(`#school_${attr}`).prop("required", state)
    $(`[for=school_${attr}]`).addClass('label-required')
  })
}

const createSchool = function(input, callback) {
  selectizeCallback = callback
  $("#school_form").show()
  toggleRequired(SCHOOL_REQUIRED_ATTRIBUTES, true)
  $(".btn-primary").show()
  const originalSchoolId = $('#teacher_school_id').val()
  const resetButton = $("#close_button")
  const nameInput = $("#school_name")
  $('#teacher_school_id').val(null)
  nameInput.val(input)
  resetButton.on("click", () => {
    if (selectizeCallback) {
      selectizeCallback()
      selectizeCallback = null
      $('#teacher_school_id').val(originalSchoolId)
    }
    toggleRequired(SCHOOL_REQUIRED_ATTRIBUTES, true)
    $("#school_form").hide()
  })
}

const bindFormSubmit = () => {
  $("#new_school").on("submit", function(e) {
    e.preventDefault()
    $.ajax({
      method: "POST",
      url: $(this).attr("action"),
      data: $(this).serialize(),
      success: function() {
        window.location = "/schools"
        selectizeCallback = null
      },
    })
  })
}

export function initSchoolSelectize() {
  if (initialized) { return }
  initialized = true

  bindFormSubmit()
  const $selector = $(".select")
  if ($selector.length === 0) { return }

  const selectizeInstance = $selector.selectize({
    create: createSchool,
    createOnBlur: true,
    highlight: true,
  })

  selectizeInstance.on('change', () => {
    let selectedSchool = JSON.parse($("#school_selectize").val())
    $('#teacher_school_id').val(selectedSchool.id)
    toggleRequired(SCHOOL_REQUIRED_ATTRIBUTES, false)
  })
}

initSchoolSelectize()

export default initSchoolSelectize
